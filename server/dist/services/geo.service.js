import { Redis } from 'ioredis';
export class GeoSpatialService {
    redis = null;
    isRedisConnected = false;
    // In-memory fallback if Redis server is not currently running
    localDriverLocations = new Map();
    constructor(redisUrl) {
        try {
            this.redis = new Redis(redisUrl || 'redis://127.0.0.1:6379', {
                maxRetriesPerRequest: 1,
                lazyConnect: true,
                connectTimeout: 1000,
                retryStrategy: () => null // Do not retry if connection fails
            });
            this.redis.on('error', () => {
                // Suppress unhandled error log when Redis is not installed/running locally
                this.isRedisConnected = false;
            });
            this.redis.connect().then(() => {
                this.isRedisConnected = true;
                console.log('[Redis] Connected to Redis geospatial store');
            }).catch(() => {
                this.isRedisConnected = false;
                console.log('[Redis] Standalone Redis not detected; using in-memory geospatial engine');
            });
        }
        catch {
            this.isRedisConnected = false;
        }
    }
    /**
     * Update active driver coordinates
     * Uses Redis GEOADD if connected, otherwise in-memory map
     */
    async updateDriverLocation(driverId, lat, lon) {
        this.localDriverLocations.set(driverId, { lat, lon, updatedAt: Date.now() });
        if (this.isRedisConnected && this.redis) {
            try {
                // GEOADD key longitude latitude member
                await this.redis.geoadd('drivers:active', lon, lat, driverId);
            }
            catch (err) {
                console.error('[Redis] geoadd failed', err);
            }
        }
    }
    /**
     * Remove driver when offline
     */
    async removeDriver(driverId) {
        this.localDriverLocations.delete(driverId);
        if (this.isRedisConnected && this.redis) {
            try {
                await this.redis.zrem('drivers:active', driverId);
            }
            catch (err) {
                console.error('[Redis] zrem failed', err);
            }
        }
    }
    /**
     * Find nearby drivers within radiusKm
     */
    async findNearbyDrivers(center, radiusKm = 5) {
        if (this.isRedisConnected && this.redis) {
            try {
                // Redis 6.2+ GEOSEARCH
                const results = await this.redis.geosearch('drivers:active', 'FROMLONLAT', center.longitude, center.latitude, 'BYRADIUS', radiusKm, 'KM', 'WITHDIST', 'ASC');
                return results.map(([driverId, dist]) => ({
                    driverId,
                    distanceKm: parseFloat(dist)
                }));
            }
            catch (err) {
                console.warn('[Redis] geosearch failed; falling back to memory query', err);
            }
        }
        // In-memory Haversine distance search
        const nearby = [];
        const now = Date.now();
        for (const [driverId, loc] of this.localDriverLocations.entries()) {
            // Discard stale locations older than 10 minutes
            if (now - loc.updatedAt > 10 * 60 * 1000)
                continue;
            const dist = this.haversine(center.latitude, center.longitude, loc.lat, loc.lon);
            if (dist <= radiusKm) {
                nearby.push({ driverId, distanceKm: Number(dist.toFixed(2)) });
            }
        }
        return nearby.sort((a, b) => a.distanceKm - b.distanceKm);
    }
    haversine(lat1, lon1, lat2, lon2) {
        const R = 6371;
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLon = ((lon2 - lon1) * Math.PI) / 180;
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos((lat1 * Math.PI) / 180) *
                Math.cos((lat2 * Math.PI) / 180) *
                Math.sin(dLon / 2) *
                Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
