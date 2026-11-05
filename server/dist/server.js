import Fastify from 'fastify';
import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import { GeoSpatialService } from './services/geo.service.js';
import { RideService } from './services/ride.service.js';
import { OsrmRoutingService } from './services/osrm.service.js';
import { WalletService } from './services/wallet.service.js';
import { AuthService } from './services/auth.service.js';
import { WebSocketHandler } from './websocket/socket.handler.js';
const server = Fastify({ logger: true });
// Services
const geoService = new GeoSpatialService(process.env.REDIS_URL);
const rideService = new RideService();
const walletService = new WalletService();
const authService = new AuthService();
const wsHandler = new WebSocketHandler(geoService, rideService, walletService);
async function start() {
    await server.register(cors, { origin: '*' });
    await server.register(websocket);
    // Health check
    server.get('/health', async () => ({
        status: 'ok',
        app: 'Movers E-Hailing Backend',
        timestamp: Date.now()
    }));
    // ==========================================
    // AUTHENTICATION & REGISTRATION ENDPOINTS
    // ==========================================
    // Register a new Rider or Driver
    server.post('/api/auth/register', async (request, reply) => {
        try {
            const result = authService.register(request.body);
            return result;
        }
        catch (err) {
            return reply.status(400).send({ error: err.message || 'Registration failed' });
        }
    });
    // Login with phone & password
    server.post('/api/auth/login', async (request, reply) => {
        try {
            const { phone, password } = request.body || {};
            if (!phone || !password) {
                return reply.status(400).send({ error: 'Phone and password are required' });
            }
            const result = authService.login(phone, password);
            return result;
        }
        catch (err) {
            return reply.status(401).send({ error: err.message || 'Login failed' });
        }
    });
    // Verify token & fetch current profile
    server.get('/api/auth/me', async (request, reply) => {
        const authHeader = request.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return reply.status(401).send({ error: 'Missing or invalid token' });
        }
        const token = authHeader.substring(7);
        const decoded = authService.verifyToken(token);
        if (!decoded) {
            return reply.status(401).send({ error: 'Invalid or expired token' });
        }
        const user = authService.getUserById(decoded.userId);
        if (!user) {
            return reply.status(404).send({ error: 'User not found' });
        }
        return { user };
    });
    // Route & Fare Estimation using OpenStreetMap OSRM
    server.post('/api/routes/estimate', async (request, reply) => {
        const { pickup, destination } = request.body;
        if (!pickup || !destination) {
            return reply.status(400).send({ error: 'Pickup and destination are required' });
        }
        const estimate = await OsrmRoutingService.calculateRoute(pickup, destination);
        return estimate;
    });
    // Find nearby available drivers
    server.get('/api/drivers/nearby', async (request) => {
        const lat = parseFloat(request.query.lat);
        const lon = parseFloat(request.query.lon);
        const radius = request.query.radius ? parseFloat(request.query.radius) : 5;
        const drivers = await geoService.findNearbyDrivers({ latitude: lat, longitude: lon }, radius);
        return { drivers };
    });
    // Check driver wallet & transaction history
    server.get('/api/wallet/:driverId', async (request) => {
        const wallet = walletService.getWallet(request.params.driverId);
        return { wallet };
    });
    // Top up driver prepaid balance
    server.post('/api/wallet/:driverId/topup', async (request, reply) => {
        const { amount, paymentMethod } = request.body || {};
        if (!amount || amount <= 0) {
            return reply.status(400).send({ error: 'Valid positive amount is required' });
        }
        const updated = walletService.topUp(request.params.driverId, amount, paymentMethod);
        return { wallet: updated };
    });
    // ==========================================
    // REAL AVAILABLE ORDERS FEED & RECENT RIDES
    // ==========================================
    // Live active available orders for drivers to browse & choose
    server.get('/api/rides/active', async () => {
        const orders = rideService.getActiveOrders();
        return { orders };
    });
    // Rider Past Trips & Reviews
    server.get('/api/rides/history/rider/:riderId', async (request) => {
        const rides = rideService.getRiderHistory(request.params.riderId);
        return { rides };
    });
    // Driver Past Trips & Earnings
    server.get('/api/rides/history/driver/:driverId', async (request) => {
        const rides = rideService.getDriverHistory(request.params.driverId);
        return { rides };
    });
    // Submit Ride Rating & Comment
    server.post('/api/rides/:rideId/review', async (request, reply) => {
        const { driverId, riderId, riderName, rating, comment } = request.body || {};
        if (!driverId || !riderId || !rating) {
            return reply.status(400).send({ error: 'driverId, riderId, and rating are required' });
        }
        const review = rideService.submitReview(request.params.rideId, driverId, riderId, riderName || 'Rider', rating, comment);
        return { review };
    });
    // Driver Reviews & Job Ratings Screen
    server.get('/api/drivers/:driverId/reviews', async (request) => {
        const reviews = rideService.getDriverReviews(request.params.driverId);
        const profile = rideService.getDriverProfile(request.params.driverId);
        return { reviews, profile };
    });
    // Dynamic OpenStreetMap Address Search (No hardcoded points!)
    server.get('/api/geo/search', async (request) => {
        const q = request.query.q?.trim();
        if (!q || q.length < 2)
            return { results: [] };
        try {
            const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&countrycodes=za&limit=6&addressdetails=1`;
            const res = await fetch(url, {
                headers: { 'User-Agent': 'MoversEHailingApp/1.0' }
            });
            const data = await res.json();
            const results = data.map((item) => ({
                displayName: item.display_name,
                name: item.name || item.display_name.split(',')[0],
                latitude: parseFloat(item.lat),
                longitude: parseFloat(item.lon),
            }));
            return { results };
        }
        catch (e) {
            return { results: [] };
        }
    });
    // Real-time Bidding & Location Stream WebSocket
    server.register(async function (fastify) {
        fastify.get('/ws', { websocket: true }, (socket, req) => {
            wsHandler.handleConnection(socket);
        });
    });
    const PORT = Number(process.env.PORT) || 4000;
    try {
        await server.listen({ port: PORT, host: '0.0.0.0' });
        console.log(`[Movers] Server running on http://localhost:${PORT}`);
        console.log(`[Movers] WebSocket endpoint active at ws://localhost:${PORT}/ws`);
    }
    catch (err) {
        server.log.error(err);
        process.exit(1);
    }
}
start();
