import { WebSocket } from 'ws';
const SERVER_URL = 'ws://127.0.0.1:4000/ws';
function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
async function runSimulation() {
    console.log('==================================================');
    console.log('🚀 STARTING MOVERS REAL-TIME BIDDING SIMULATION');
    console.log('==================================================\n');
    // 1. Connect Drivers
    const driverSockets = [];
    const drivers = [
        { id: 'driver_sipho', name: 'Sipho Zulu', lat: -26.1075, lon: 28.0567 },
        { id: 'driver_thabo', name: 'Thabo Mokoena', lat: -26.1100, lon: 28.0520 },
        { id: 'driver_lerato', name: 'Lerato Khumalo', lat: -26.1050, lon: 28.0590 }
    ];
    for (const d of drivers) {
        const ws = new WebSocket(SERVER_URL);
        await new Promise((resolve) => ws.on('open', resolve));
        // Register
        ws.send(JSON.stringify({ type: 'REGISTER', role: 'DRIVER', userId: d.id, name: d.name }));
        // Send Location
        ws.send(JSON.stringify({ type: 'DRIVER_LOCATION_UPDATE', latitude: d.lat, longitude: d.lon }));
        driverSockets.push({ id: d.id, name: d.name, socket: ws });
        console.log(`🟢 [Driver Connected] ${d.name} (${d.id}) is online at (${d.lat}, ${d.lon})`);
    }
    await wait(1000);
    // 2. Connect Rider
    const riderWs = new WebSocket(SERVER_URL);
    await new Promise((resolve) => riderWs.on('open', resolve));
    riderWs.send(JSON.stringify({ type: 'REGISTER', role: 'RIDER', userId: 'rider_hulisani', name: 'Hulisani' }));
    console.log(`👤 [Rider Connected] Hulisani is online\n`);
    let activeRideId = '';
    const receivedBids = [];
    // Listen to Rider events
    riderWs.on('message', (data) => {
        const event = JSON.parse(data.toString());
        if (event.type === 'RIDE_BROADCAST') {
            activeRideId = event.ride.id;
            console.log(`📋 [Rider View] Ride created: ${event.ride.id}`);
            console.log(`   Trip: Sandton City -> Rosebank Mall`);
            console.log(`   Estimated Road Distance: ${event.ride.distanceKm} km | Time: ${event.ride.durationMinutes} min`);
            console.log(`   Offered Fare: R${event.ride.suggestedFare}\n`);
        }
        if (event.type === 'BID_RECEIVED') {
            receivedBids.push(event.bid);
            console.log(`🔔 [Rider View] New incoming bid!`);
            console.log(`   Driver: ${event.bid.driverName} (⭐ ${event.bid.rating} | ${event.bid.vehicleModel})`);
            console.log(`   Offer: R${event.bid.proposedPrice} | Arriving in: ${event.bid.etaMinutes} mins\n`);
        }
        if (event.type === 'RIDE_LOCKED') {
            console.log(`🎉 [Rider View] Deal Locked! Accepted ${event.acceptedBid.driverName} at R${event.acceptedBid.proposedPrice}`);
        }
    });
    // Listen to Driver events
    driverSockets.forEach(({ id, name, socket }) => {
        socket.on('message', async (data) => {
            const event = JSON.parse(data.toString());
            if (event.type === 'RIDE_BROADCAST') {
                console.log(`📲 [Driver Ping] ${name} received nearby ride request #${event.ride.id} for R${event.ride.suggestedFare}`);
                // Simulate driver bidding decision
                await wait(1000 + Math.random() * 1500);
                if (id === 'driver_sipho') {
                    // Sipho matches rider's proposed price
                    console.log(`💬 [Driver Action] ${name} decides to ACCEPT rider's offer of R75!`);
                    socket.send(JSON.stringify({
                        type: 'SUBMIT_BID',
                        rideId: event.ride.id,
                        proposedPrice: 75,
                        etaMinutes: 4
                    }));
                }
                else if (id === 'driver_thabo') {
                    // Thabo counter-offers slightly higher
                    console.log(`💬 [Driver Action] ${name} decides to COUNTER-BID at R85`);
                    socket.send(JSON.stringify({
                        type: 'SUBMIT_BID',
                        rideId: event.ride.id,
                        proposedPrice: 85,
                        etaMinutes: 3
                    }));
                }
                else if (id === 'driver_lerato') {
                    // Lerato counter-offers premium
                    console.log(`💬 [Driver Action] ${name} decides to COUNTER-BID at R90`);
                    socket.send(JSON.stringify({
                        type: 'SUBMIT_BID',
                        rideId: event.ride.id,
                        proposedPrice: 90,
                        etaMinutes: 6
                    }));
                }
            }
            if (event.type === 'RIDE_LOCKED') {
                console.log(`🏆 [Driver Win] ${name} got the ride! Heading to pickup.`);
            }
            if (event.type === 'COMMISSION_SETTLED') {
                console.log(`💳 [Driver Wallet] Commission Settled for ${name}:`);
                console.log(`   Trip Fare Collected: R${event.fare}`);
                console.log(`   Movers Fee (8.5%): -R${event.commissionDeducted}`);
                console.log(`   Remaining Driver Prepaid Balance: R${event.remainingBalance}\n`);
            }
        });
    });
    await wait(1000);
    // 3. Rider proposes ride
    console.log(`📍 Rider Hulisani is proposing a ride: Sandton City -> Rosebank Mall at R75...`);
    riderWs.send(JSON.stringify({
        type: 'PROPOSE_RIDE',
        pickup: { latitude: -26.107567, longitude: 28.056702, address: 'Sandton City Mall' },
        destination: { latitude: -26.1466, longitude: 28.0436, address: 'Rosebank Mall' },
        suggestedFare: 75
    }));
    // 4. Wait for bids to collect
    await wait(4500);
    let chosenDriverSocket = null;
    // 5. Rider chooses the best offer
    if (receivedBids.length > 0) {
        console.log(`\n🤔 Rider reviewing ${receivedBids.length} counter-offers...`);
        const chosenBid = receivedBids[0]; // e.g. Lerato Khumalo at R90
        console.log(`👉 Rider selected: ${chosenBid.driverName} at R${chosenBid.proposedPrice}\n`);
        const driverMatch = driverSockets.find((d) => d.id === chosenBid.driverId);
        if (driverMatch)
            chosenDriverSocket = driverMatch.socket;
        riderWs.send(JSON.stringify({
            type: 'ACCEPT_BID',
            rideId: activeRideId,
            bidId: chosenBid.id
        }));
    }
    await wait(2000);
    // 6. Simulate Driver Completing Trip & Triggering Commission Settlement
    if (chosenDriverSocket) {
        console.log(`🏁 [Trip Status] Driver arrived at destination (Rosebank Mall). Trip completed!`);
        chosenDriverSocket.send(JSON.stringify({
            type: 'UPDATE_RIDE_STATUS',
            rideId: activeRideId,
            status: 'COMPLETED'
        }));
    }
    await wait(2000);
    console.log('==================================================');
    console.log('✅ SIMULATION COMPLETE: Full Lifecycle + Commission Settled!');
    console.log('==================================================');
    // Clean up
    riderWs.close();
    driverSockets.forEach((d) => d.socket.close());
    process.exit(0);
}
runSimulation().catch(console.error);
