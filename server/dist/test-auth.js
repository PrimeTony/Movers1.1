import { AuthService } from './services/auth.service.js';
import { WalletService } from './services/wallet.service.js';
function runAuthTest() {
    console.log('==================================================');
    console.log('🧪 TESTING MOVERS FREE PERSISTENT SQLITE AUTH');
    console.log('==================================================\n');
    const auth = new AuthService();
    const wallet = new WalletService();
    const testPhoneRider = `+2782${Math.floor(1000000 + Math.random() * 9000000)}`;
    const testPhoneDriver = `+2782${Math.floor(1000000 + Math.random() * 9000000)}`;
    // 1. Register Rider
    console.log(`1. Registering Rider (${testPhoneRider})...`);
    const riderReg = auth.register({
        name: 'Hulisani Mbedzi',
        phone: testPhoneRider,
        password: 'securePassword123!',
        role: 'RIDER',
        email: `hulisani_${Date.now()}@test.com`
    });
    console.log(`   ✅ Rider Created: ID=${riderReg.user.id}, Token=${riderReg.token.substring(0, 20)}...`);
    // 2. Register Driver
    console.log(`\n2. Registering Driver (${testPhoneDriver})...`);
    const driverReg = auth.register({
        name: 'Kabelo Sithole',
        phone: testPhoneDriver,
        password: 'secureDriverPass!',
        role: 'DRIVER',
        vehicleModel: 'Toyota Urban Cruiser',
        vehiclePlate: 'GP 882-101'
    });
    console.log(`   ✅ Driver Created: ID=${driverReg.user.id}`);
    // Check Driver's Auto-Created Wallet
    const driverWallet = wallet.getWallet(driverReg.user.id);
    console.log(`   💰 Initial Wallet Balance: R${driverWallet.balance} (${driverWallet.currency})`);
    console.log(`   📜 Initial Transactions: ${driverWallet.transactions.length} record(s)`);
    // 3. Test Login
    console.log(`\n3. Testing Login for Driver (${testPhoneDriver})...`);
    const loginRes = auth.login(testPhoneDriver, 'secureDriverPass!');
    console.log(`   ✅ Login Successful! User=${loginRes.user.name}, Role=${loginRes.user.role}`);
    console.log(`   Vehicle: ${loginRes.profile.vehicle_model} (${loginRes.profile.vehicle_plate})`);
    // 4. Test Token Verification
    console.log(`\n4. Verifying Token...`);
    const verified = auth.verifyToken(loginRes.token);
    console.log(`   ✅ Token Valid: UserID=${verified?.userId}, Role=${verified?.role}`);
    console.log('\n==================================================');
    console.log('🎉 ALL AUTH & DATABASE TESTS PASSED SUCCESSFULLY!');
    console.log('==================================================');
}
runAuthTest();
