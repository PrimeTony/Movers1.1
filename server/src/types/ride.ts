export type RideStatus =
  | 'REQUESTED'   // Rider proposed ride + fare, waiting for bids
  | 'BIDDING'     // Counter-offers arriving from drivers
  | 'ACCEPTED'    // Rider accepted a driver's bid (deal locked)
  | 'ARRIVING'    // Driver en route to pickup
  | 'IN_PROGRESS' // Rider picked up, heading to destination
  | 'COMPLETED'   // Trip finished, fare settlement complete
  | 'CANCELLED';  // Cancelled by rider or driver

export interface GeoPoint {
  latitude: number;
  longitude: number;
  address?: string;
}

export interface DriverProfile {
  id: string;
  name: string;
  vehicleModel: string;
  vehiclePlate: string;
  rating: number;
  completedTrips: number;
  currentLocation: GeoPoint;
}

export interface Bid {
  id: string;
  rideId: string;
  driverId: string;
  driverName: string;
  vehicleModel: string;
  rating: number;
  proposedPrice: number; // Driver's offered price (could match rider or counter-offer)
  etaMinutes: number;    // Estimated arrival time to pickup
  createdAt: number;
}

export interface RideRequest {
  id: string;
  riderId: string;
  riderName: string;
  riderPhone?: string;
  pickup: GeoPoint;
  destination: GeoPoint;
  distanceKm: number;
  durationMinutes: number;
  itemDescription?: string;
  pickupTime?: string;
  paymentMethod?: 'Cash' | 'Wallet';
  suggestedFare: number; // Rider's initial proposed price
  finalFare?: number;
  status: RideStatus;
  bids: Bid[];
  acceptedBid?: Bid;
  driverId?: string;
  driverName?: string;
  createdAt: number;
  updatedAt: number;
}

export interface RideReview {
  id: string;
  rideId: string;
  driverId: string;
  riderId: string;
  riderName: string;
  rating: number;
  comment?: string;
  createdAt: number;
}

export interface WalletTransaction {
  id: string;
  driverId: string;
  rideId?: string;
  amount: number; // positive for top-up, negative for deduction
  type: 'COMMISSION_DEDUCTION' | 'TOP_UP' | 'BONUS';
  description: string;
  timestamp: number;
}

export interface DriverWallet {
  driverId: string;
  balance: number;
  currency: string;
  isSuspended: boolean;
  transactions: WalletTransaction[];
}

// WebSocket Event Payloads
export type ClientEvent =
  | { type: 'REGISTER'; role: 'RIDER' | 'DRIVER'; userId: string; name: string }
  | { type: 'DRIVER_LOCATION_UPDATE'; latitude: number; longitude: number }
  | { 
      type: 'PROPOSE_RIDE'; 
      pickup: GeoPoint; 
      destination: GeoPoint; 
      suggestedFare: number;
      itemDescription?: string;
      pickupTime?: string;
      paymentMethod?: 'Cash' | 'Wallet';
      riderPhone?: string;
    }
  | { type: 'SUBMIT_BID'; rideId: string; proposedPrice: number; etaMinutes: number }
  | { type: 'ACCEPT_BID'; rideId: string; bidId: string }
  | { type: 'UPDATE_RIDE_STATUS'; rideId: string; status: RideStatus }
  | { type: 'SUBMIT_REVIEW'; rideId: string; rating: number; comment?: string }
  | { type: 'GET_WALLET' }
  | { type: 'TOPUP_WALLET'; amount: number };

export type ServerEvent =
  | { type: 'REGISTERED'; userId: string; role: 'RIDER' | 'DRIVER' }
  | { type: 'RIDE_BROADCAST'; ride: RideRequest }
  | { type: 'BID_RECEIVED'; rideId: string; bid: Bid }
  | { type: 'RIDE_LOCKED'; rideId: string; acceptedBid: Bid }
  | { type: 'RIDE_STATUS_UPDATED'; rideId: string; status: RideStatus; location?: GeoPoint }
  | { type: 'WALLET_UPDATED'; wallet: DriverWallet }
  | { type: 'COMMISSION_SETTLED'; rideId: string; fare: number; commissionDeducted: number; remainingBalance: number }
  | { type: 'ERROR'; message: string };

