import { WebSocket } from 'ws';
import { ClientEvent, ServerEvent } from '../types/ride.js';
import { GeoSpatialService } from '../services/geo.service.js';
import { RideService } from '../services/ride.service.js';
import { WalletService } from '../services/wallet.service.js';

interface ConnectedClient {
  socket: WebSocket;
  userId: string;
  role: 'RIDER' | 'DRIVER';
  name: string;
}

export class WebSocketHandler {
  private clients = new Map<string, ConnectedClient>(); // userId -> Client

  constructor(
    private geoService: GeoSpatialService,
    private rideService: RideService,
    private walletService: WalletService
  ) { }

  public handleConnection(socket: WebSocket): void {
    let currentUserId: string | null = null;

    socket.on('message', async (raw: string) => {
      try {
        const event: ClientEvent = JSON.parse(raw.toString());
        await this.processEvent(socket, event, (id) => (currentUserId = id));
      } catch (err: any) {
        this.send(socket, { type: 'ERROR', message: err.message || 'Invalid message' });
      }
    });

    socket.on('close', () => {
      if (currentUserId) {
        const client = this.clients.get(currentUserId);
        if (client && client.role === 'DRIVER') {
          this.geoService.removeDriver(currentUserId);
        }
        this.clients.delete(currentUserId);
        console.log(`[WS] Client disconnected: ${currentUserId}`);
      }
    });
  }

  private async processEvent(
    socket: WebSocket,
    event: ClientEvent,
    setCurrentUserId: (id: string) => void
  ): Promise<void> {
    switch (event.type) {
      case 'REGISTER': {
        setCurrentUserId(event.userId);
        this.clients.set(event.userId, {
          socket,
          userId: event.userId,
          role: event.role,
          name: event.name
        });

        this.send(socket, { type: 'REGISTERED', userId: event.userId, role: event.role });
        console.log(`[WS] ${event.role} connected: ${event.name} (${event.userId})`);
        break;
      }

      case 'DRIVER_LOCATION_UPDATE': {
        const client = this.findClientBySocket(socket);
        if (client && client.role === 'DRIVER') {
          await this.geoService.updateDriverLocation(client.userId, event.latitude, event.longitude);
        }
        break;
      }

      case 'PROPOSE_RIDE': {
        const rider = this.findClientBySocket(socket);
        if (!rider) throw new Error('Unregistered client');

        console.log(
          `[Ride] Rider ${rider.name} proposed a ride from (${event.pickup.latitude}, ${event.pickup.longitude}) to (${event.destination.latitude}, ${event.destination.longitude}) for R${event.suggestedFare}`
        );

        // 1. Create ride in service with persistent items, time, and payment method
        const ride = await this.rideService.createRideRequest(
          rider.userId,
          rider.name,
          event.pickup,
          event.destination,
          event.suggestedFare,
          event.itemDescription,
          event.pickupTime,
          event.paymentMethod,
          event.riderPhone
        );

        // 2. Search for drivers within 10 km
        let nearbyDrivers = await this.geoService.findNearbyDrivers(event.pickup, 10);
        console.log(`[Geo] Found ${nearbyDrivers.length} nearby drivers for ride ${ride.id}`);

        // Fallback for local development if drivers haven't sent location coordinates yet
        if (nearbyDrivers.length === 0) {
          for (const client of this.clients.values()) {
            if (client.role === 'DRIVER') {
              nearbyDrivers.push({ driverId: client.userId, distanceKm: 2.0 });
            }
          }
        }

        // 3. Broadcast to nearby drivers (filtering for active wallet eligibility)
        for (const nearby of nearbyDrivers) {
          if (!this.walletService.isDriverEligible(nearby.driverId)) {
            console.log(`[Wallet] Driver ${nearby.driverId} has negative balance/suspended; skipping broadcast.`);
            continue;
          }

          const driverClient = this.clients.get(nearby.driverId);
          if (driverClient && driverClient.socket.readyState === WebSocket.OPEN) {
            this.send(driverClient.socket, {
              type: 'RIDE_BROADCAST',
              ride
            });
          }
        }

        // Also confirm broadcast to the rider
        this.send(socket, { type: 'RIDE_BROADCAST', ride });
        break;
      }

      case 'SUBMIT_BID': {
        const driver = this.findClientBySocket(socket);
        if (!driver || driver.role !== 'DRIVER') throw new Error('Only registered drivers can bid');

        const bid = this.rideService.placeBid(
          event.rideId,
          driver.userId,
          event.proposedPrice,
          event.etaMinutes
        );

        if (!bid) throw new Error('Could not place bid (ride expired or completed)');

        console.log(
          `[Bid] Driver ${driver.name} bid R${event.proposedPrice} on ride ${event.rideId} (ETA ${event.etaMinutes} min)`
        );

        // Forward this bid to the rider in real time!
        const ride = this.rideService.getRide(event.rideId);
        if (ride) {
          const riderClient = this.clients.get(ride.riderId);
          if (riderClient && riderClient.socket.readyState === WebSocket.OPEN) {
            this.send(riderClient.socket, {
              type: 'BID_RECEIVED',
              rideId: ride.id,
              bid
            });
          }
        }
        break;
      }

      case 'ACCEPT_BID': {
        const rider = this.findClientBySocket(socket);
        if (!rider) throw new Error('Unauthorized');

        const result = this.rideService.acceptBid(event.rideId, rider.userId, event.bidId);
        if (!result) throw new Error('Failed to accept bid');

        const { ride, winningBid } = result;
        console.log(
          `[Match] Deal sealed! Rider ${rider.name} accepted ${winningBid.driverName}'s offer of R${winningBid.proposedPrice}`
        );

        // Notify Rider
        this.send(socket, { type: 'RIDE_LOCKED', rideId: ride.id, acceptedBid: winningBid });

        // Notify Winning Driver
        const winningDriverClient = this.clients.get(winningBid.driverId);
        if (winningDriverClient && winningDriverClient.socket.readyState === WebSocket.OPEN) {
          this.send(winningDriverClient.socket, {
            type: 'RIDE_LOCKED',
            rideId: ride.id,
            acceptedBid: winningBid
          });
        }
        break;
      }

      case 'UPDATE_RIDE_STATUS': {
        const updated = this.rideService.updateStatus(event.rideId, event.status);
        if (!updated) throw new Error('Could not update status');

        // Check if ride completed -> trigger commission settlement!
        if (event.status === 'COMPLETED' && updated.acceptedBid && updated.finalFare) {
          const settlement = this.walletService.settleRideCommission(
            updated.acceptedBid.driverId,
            updated.id,
            updated.finalFare
          );

          const driverClient = this.clients.get(updated.acceptedBid.driverId);
          if (driverClient && driverClient.socket.readyState === WebSocket.OPEN) {
            this.send(driverClient.socket, {
              type: 'COMMISSION_SETTLED',
              rideId: updated.id,
              fare: settlement.fare,
              commissionDeducted: settlement.commissionDeducted,
              remainingBalance: settlement.remainingBalance
            });
          }
        }

        // Notify both parties
        const riderClient = this.clients.get(updated.riderId);
        if (riderClient) {
          this.send(riderClient.socket, {
            type: 'RIDE_STATUS_UPDATED',
            rideId: updated.id,
            status: event.status
          });
        }
        if (updated.acceptedBid) {
          const driverClient = this.clients.get(updated.acceptedBid.driverId);
          if (driverClient) {
            this.send(driverClient.socket, {
              type: 'RIDE_STATUS_UPDATED',
              rideId: updated.id,
              status: event.status
            });
          }
        }
        break;
      }

      case 'GET_WALLET': {
        const client = this.findClientBySocket(socket);
        if (!client) throw new Error('Unregistered client');
        const wallet = this.walletService.getWallet(client.userId);
        this.send(socket, { type: 'WALLET_UPDATED', wallet });
        break;
      }

      case 'TOPUP_WALLET': {
        const client = this.findClientBySocket(socket);
        if (!client) throw new Error('Unregistered client');
        const wallet = this.walletService.topUp(client.userId, event.amount);
        this.send(socket, { type: 'WALLET_UPDATED', wallet });
        break;
      }

      case 'SUBMIT_REVIEW': {
        const client = this.findClientBySocket(socket);
        if (!client) throw new Error('Unregistered client');
        const ride = this.rideService.getRide(event.rideId);
        if (ride && ride.driverId) {
          const review = this.rideService.submitReview(
            event.rideId,
            ride.driverId,
            client.userId,
            client.name,
            event.rating,
            event.comment
          );
          // Broadcast to driver if connected
          const driverClient = this.clients.get(ride.driverId);
          if (driverClient && driverClient.socket.readyState === WebSocket.OPEN) {
            this.send(driverClient.socket, {
              type: 'WALLET_UPDATED',
              wallet: this.walletService.getWallet(ride.driverId)
            });
          }
        }
        break;
      }
    }
  }

  private findClientBySocket(socket: WebSocket): ConnectedClient | undefined {
    for (const client of this.clients.values()) {
      if (client.socket === socket) return client;
    }
    return undefined;
  }

  private send(socket: WebSocket, event: ServerEvent): void {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(event));
    }
  }
}

