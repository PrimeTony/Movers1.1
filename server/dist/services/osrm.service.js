export class OsrmRoutingService {
    static OSRM_PUBLIC_URL = 'https://router.project-osrm.org/route/v1/driving';
    // Base fare + rate per km (customizable per city/currency, e.g. ZAR in SA or USD)
    static BASE_FARE = 20.0; // Base pickup fee
    static PER_KM_RATE = 10.5; // Fee per km
    static PER_MINUTE_RATE = 1.5; // Fee per minute
    /**
     * Calculate routing via OpenStreetMap OSRM
     */
    static async calculateRoute(pickup, destination) {
        try {
            const url = `${this.OSRM_PUBLIC_URL}/${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson`;
            const response = await fetch(url, { headers: { 'User-Agent': 'MoversApp/1.0' } });
            if (!response.ok) {
                throw new Error(`OSRM HTTP ${response.status}`);
            }
            const data = await response.json();
            if (!data.routes || data.routes.length === 0) {
                throw new Error('No route found from OSRM');
            }
            const route = data.routes[0];
            const distanceKm = Number((route.distance / 1000).toFixed(2));
            const durationMinutes = Math.max(1, Math.round(route.duration / 60));
            const suggestedFare = this.calculateBaselineFare(distanceKm, durationMinutes);
            return {
                distanceKm,
                durationMinutes,
                geometry: JSON.stringify(route.geometry),
                suggestedFare
            };
        }
        catch (err) {
            // Fallback calculation using straight-line Haversine if external OSRM request fails/offline
            console.warn('[OSRM] Falling back to Haversine straight-line distance due to network/offline mode');
            const straightDistance = this.calculateHaversineKm(pickup.latitude, pickup.longitude, destination.latitude, destination.longitude);
            const estRoadDistance = Number((straightDistance * 1.3).toFixed(2)); // Factor 1.3 for city road winding
            const estDuration = Math.round((estRoadDistance / 35) * 60); // 35 km/h city average
            return {
                distanceKm: estRoadDistance,
                durationMinutes: estDuration,
                suggestedFare: this.calculateBaselineFare(estRoadDistance, estDuration)
            };
        }
    }
    static calculateBaselineFare(distanceKm, durationMinutes) {
        const raw = this.BASE_FARE + distanceKm * this.PER_KM_RATE + durationMinutes * this.PER_MINUTE_RATE;
        return Math.round(raw); // Round to neat integer (e.g. R65 or $15)
    }
    static calculateHaversineKm(lat1, lon1, lat2, lon2) {
        const R = 6371; // Earth radius in km
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLon = ((lon2 - lon1) * Math.PI) / 180;
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos((lat1 * Math.PI) / 180) *
                Math.cos((lat2 * Math.PI) / 180) *
                Math.sin(dLon / 2) *
                Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}
