# Movers: Open-Source Peer-to-Peer E-Hailing Platform

Movers is an open-source, peer-to-peer e-hailing platform inspired by inDrive's negotiated fare bidding model. 

---

## 🏗️ Architecture

```
movers/
├── server/                     # Fastify + TypeScript + Redis + WebSockets
│   ├── src/
│   │   ├── types/ride.ts       # Shared ride state & event interfaces
│   │   ├── services/
│   │   │   ├── geo.service.ts  # Redis geospatial driver proximity engine
│   │   │   ├── ride.service.ts # Bidding auction & ride state machine
│   │   │   └── osrm.service.ts # OpenStreetMap (OSRM) distance & routing
│   │   ├── websocket/
│   │   │   └── socket.handler.ts # Real-time bidirectional event dispatcher
│   │   ├── server.ts           # Fastify application entrypoint
│   │   └── simulation.ts       # Live multi-agent negotiation test
│   ├── package.json
│   └── tsconfig.json
└── mobile/                     # Flutter Client (Rider & Driver UI - Next Phase)
```

---

## ⚡ How the Bidding Engine Works

1. **Rider Proposes**: Rider specifies pickup, destination, and a suggested price (e.g., R75).
2. **OSRM Route Calculation**: The backend queries OpenStreetMap's OSRM router for true road distance, duration, and baseline fair pricing.
3. **Redis Geospatial Discovery**: Finds active drivers within 10 km (`GEOSEARCH`).
4. **Broadcast to Drivers**: Only nearby drivers receive the ride alert.
5. **Driver Counter-Offers**: Drivers can accept the rider's offer or submit a counter-bid.
6. **Deal Sealed**: The rider selects their preferred driver based on price, rating, and ETA.

---

## 🚀 Running the Server & Simulation

```bash
cd server
npm install
npm run dev
```

To run the live bidding simulation (1 rider + 3 drivers):
```bash
npm run simulate
```

