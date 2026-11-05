import { OsrmRoutingService } from './osrm.service.js';
import { DatabaseService } from './db.service.js';
export class RideService {
    activeRides = new Map();
    driverProfiles = new Map();
    db = DatabaseService.getInstance().db;
    constructor() {
        this.seedMockProfiles();
        this.restoreActiveRidesFromDb();
    }
    seedMockProfiles() {
        this.registerMockDriver({
            id: 'driver_sipho',
            name: 'Sipho Zulu',
            vehicleModel: 'Toyota Corolla (White)',
            vehiclePlate: 'ND 842-192',
            rating: 4.9,
            completedTrips: 1420,
            currentLocation: { latitude: -26.1075, longitude: 28.0567 }
        });
        this.registerMockDriver({
            id: 'driver_thabo',
            name: 'Thabo Mokoena',
            vehicleModel: 'Volkswagen Polo (Silver)',
            vehiclePlate: 'GP 301-449',
            rating: 4.8,
            completedTrips: 875,
            currentLocation: { latitude: -26.1100, longitude: 28.0520 }
        });
        this.registerMockDriver({
            id: 'driver_lerato',
            name: 'Lerato Khumalo',
            vehicleModel: 'Hyundai Grand i10 (Grey)',
            vehiclePlate: 'CA 551-902',
            rating: 5.0,
            completedTrips: 430,
            currentLocation: { latitude: -26.1050, longitude: 28.0590 }
        });
    }
    restoreActiveRidesFromDb() {
        try {
            const rows = this.db.prepare(`
        SELECT * FROM rides 
        WHERE status IN ('REQUESTED', 'BIDDING', 'ACCEPTED', 'ARRIVING', 'IN_PROGRESS')
        ORDER BY created_at DESC LIMIT 50
      `).all();
            for (const r of rows) {
                this.activeRides.set(r.id, this.rowToRideRequest(r));
            }
        }
        catch (e) {
            console.error('[DB] Error restoring active rides:', e);
        }
    }
    rowToRideRequest(r) {
        return {
            id: r.id,
            riderId: r.rider_id,
            riderName: r.rider_name,
            riderPhone: r.rider_phone,
            pickup: {
                latitude: r.pickup_lat,
                longitude: r.pickup_lon,
                address: r.pickup_address,
            },
            destination: {
                latitude: r.dest_lat,
                longitude: r.dest_lon,
                address: r.destination_address,
            },
            distanceKm: r.distance_km,
            durationMinutes: r.duration_minutes,
            itemDescription: r.item_description,
            pickupTime: r.pickup_time,
            paymentMethod: r.payment_method,
            suggestedFare: r.suggested_fare,
            finalFare: r.final_fare,
            status: r.status,
            driverId: r.driver_id,
            driverName: r.driver_name,
            bids: [],
            createdAt: r.created_at,
            updatedAt: r.updated_at,
        };
    }
    registerMockDriver(driver) {
        this.driverProfiles.set(driver.id, driver);
    }
    getDriverProfile(driverId) {
        const memory = this.driverProfiles.get(driverId);
        if (memory)
            return memory;
        try {
            const row = this.db.prepare(`
        SELECT u.id, u.name, d.vehicle_model, d.vehicle_plate, d.rating, d.completed_trips
        FROM users u
        JOIN driver_profiles d ON u.id = d.driver_id
        WHERE u.id = ?
      `).get(driverId);
            if (row) {
                return {
                    id: row.id,
                    name: row.name,
                    vehicleModel: row.vehicle_model,
                    vehiclePlate: row.vehicle_plate,
                    rating: row.rating,
                    completedTrips: row.completed_trips,
                    currentLocation: { latitude: -26.1150, longitude: 28.0540 },
                };
            }
        }
        catch { }
        return undefined;
    }
    /**
     * Create a new persistent ride request with route calculations from OSRM
     */
    async createRideRequest(riderId, riderName, pickup, destination, suggestedFare, itemDescription, pickupTime, paymentMethod, riderPhone) {
        const route = await OsrmRoutingService.calculateRoute(pickup, destination);
        const rideId = `ride_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const now = Date.now();
        const fare = suggestedFare > 0 ? suggestedFare : route.suggestedFare;
        const items = itemDescription?.trim() || 'Standard ride / parcels';
        const pTime = pickupTime?.trim() || 'Now';
        const payMode = paymentMethod || 'Cash';
        // 1. Persist to SQLite
        this.db.prepare(`
      INSERT INTO rides (
        id, rider_id, rider_name, rider_phone,
        pickup_address, destination_address,
        pickup_lat, pickup_lon, dest_lat, dest_lon,
        distance_km, duration_minutes,
        item_description, pickup_time, payment_method,
        suggested_fare, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'BIDDING', ?, ?)
    `).run(rideId, riderId, riderName, riderPhone || null, pickup.address || 'Pickup Point', destination.address || 'Destination Point', pickup.latitude, pickup.longitude, destination.latitude, destination.longitude, route.distanceKm, route.durationMinutes, items, pTime, payMode, fare, now, now);
        const ride = {
            id: rideId,
            riderId,
            riderName,
            riderPhone,
            pickup,
            destination,
            distanceKm: route.distanceKm,
            durationMinutes: route.durationMinutes,
            itemDescription: items,
            pickupTime: pTime,
            paymentMethod: payMode,
            suggestedFare: fare,
            status: 'BIDDING',
            bids: [],
            createdAt: now,
            updatedAt: now,
        };
        this.activeRides.set(rideId, ride);
        return ride;
    }
    getRide(rideId) {
        let ride = this.activeRides.get(rideId);
        if (!ride) {
            const row = this.db.prepare('SELECT * FROM rides WHERE id = ?').get(rideId);
            if (row) {
                ride = this.rowToRideRequest(row);
                this.activeRides.set(rideId, ride);
            }
        }
        return ride;
    }
    /**
     * Submit a driver's counter-offer or price match
     */
    placeBid(rideId, driverId, proposedPrice, etaMinutes) {
        const ride = this.getRide(rideId);
        if (!ride || (ride.status !== 'REQUESTED' && ride.status !== 'BIDDING')) {
            return null;
        }
        const driver = this.getDriverProfile(driverId);
        const bid = {
            id: `bid_${Date.now()}_${driverId}`,
            rideId,
            driverId,
            driverName: driver ? driver.name : `Driver ${driverId.slice(-4)}`,
            vehicleModel: driver ? driver.vehicleModel : 'Vehicle',
            rating: driver ? driver.rating : 5.0,
            proposedPrice,
            etaMinutes,
            createdAt: Date.now(),
        };
        ride.bids.push(bid);
        ride.status = 'BIDDING';
        ride.updatedAt = Date.now();
        return bid;
    }
    /**
     * Rider accepts a specific driver's bid (deal locked)
     */
    acceptBid(rideId, riderId, bidId) {
        const ride = this.getRide(rideId);
        if (!ride || ride.riderId !== riderId || ride.status !== 'BIDDING') {
            return null;
        }
        const winningBid = ride.bids.find((b) => b.id === bidId);
        if (!winningBid) {
            return null;
        }
        const now = Date.now();
        ride.acceptedBid = winningBid;
        ride.finalFare = winningBid.proposedPrice;
        ride.driverId = winningBid.driverId;
        ride.driverName = winningBid.driverName;
        ride.status = 'ACCEPTED';
        ride.updatedAt = now;
        // Update SQLite
        this.db.prepare(`
      UPDATE rides 
      SET status = 'ACCEPTED', final_fare = ?, driver_id = ?, driver_name = ?, updated_at = ?
      WHERE id = ?
    `).run(winningBid.proposedPrice, winningBid.driverId, winningBid.driverName, now, rideId);
        return { ride, winningBid };
    }
    /**
     * Update ride status (ARRIVING -> IN_PROGRESS -> COMPLETED)
     */
    updateStatus(rideId, status) {
        const ride = this.getRide(rideId);
        if (!ride)
            return null;
        const now = Date.now();
        ride.status = status;
        ride.updatedAt = now;
        this.db.prepare('UPDATE rides SET status = ?, updated_at = ? WHERE id = ?').run(status, now, rideId);
        return ride;
    }
    /**
     * Fetch all active open orders waiting for drivers to pick from
     */
    getActiveOrders() {
        const rows = this.db.prepare(`
      SELECT * FROM rides 
      WHERE status IN ('REQUESTED', 'BIDDING')
      ORDER BY created_at DESC
      LIMIT 30
    `).all();
        return rows.map((r) => {
            const cached = this.activeRides.get(r.id);
            return cached || this.rowToRideRequest(r);
        });
    }
    /**
     * Get Recent Trips for a Rider
     */
    getRiderHistory(riderId) {
        return this.db.prepare(`
      SELECT r.*, rev.rating as review_rating, rev.comment as review_comment
      FROM rides r
      LEFT JOIN ride_reviews rev ON r.id = rev.ride_id
      WHERE r.rider_id = ?
      ORDER BY r.created_at DESC
      LIMIT 40
    `).all(riderId);
    }
    /**
     * Get Recent Trips for a Driver
     */
    getDriverHistory(driverId) {
        return this.db.prepare(`
      SELECT r.*, rev.rating as review_rating, rev.comment as review_comment
      FROM rides r
      LEFT JOIN ride_reviews rev ON r.id = rev.ride_id
      WHERE r.driver_id = ?
      ORDER BY r.created_at DESC
      LIMIT 40
    `).all(driverId);
    }
    /**
     * Submit Rider Review for a completed ride
     */
    submitReview(rideId, driverId, riderId, riderName, rating, comment) {
        const reviewId = `rev_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
        const now = Date.now();
        this.db.prepare(`
      INSERT INTO ride_reviews (id, ride_id, driver_id, rider_id, rider_name, rating, comment, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(reviewId, rideId, driverId, riderId, riderName, rating, comment || null, now);
        // Recalculate Driver's average rating in driver_profiles
        try {
            const stats = this.db.prepare(`
        SELECT AVG(rating) as avg_rating, COUNT(*) as total_reviews
        FROM ride_reviews WHERE driver_id = ?
      `).get(driverId);
            if (stats && stats.avg_rating) {
                const rounded = Math.round(stats.avg_rating * 10) / 10;
                this.db.prepare(`
          UPDATE driver_profiles 
          SET rating = ?, completed_trips = completed_trips + 1
          WHERE driver_id = ?
        `).run(rounded, driverId);
            }
        }
        catch (e) {
            console.error('[DB] Error recalculating driver rating:', e);
        }
        return {
            id: reviewId,
            rideId,
            driverId,
            riderId,
            riderName,
            rating,
            comment,
            createdAt: now,
        };
    }
    /**
     * Fetch all ratings and comments left for a driver
     */
    getDriverReviews(driverId) {
        return this.db.prepare(`
      SELECT * FROM ride_reviews 
      WHERE driver_id = ?
      ORDER BY created_at DESC
    `).all(driverId);
    }
}
