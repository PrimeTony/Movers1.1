import crypto from 'node:crypto';
import { DatabaseService } from './db.service.js';
export class AuthService {
    db = DatabaseService.getInstance().db;
    SECRET = process.env.AUTH_SECRET || 'movers_dev_secret_key_2026';
    hashPassword(password, salt) {
        return crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
    }
    generateToken(userId, role) {
        const payload = JSON.stringify({ userId, role, ts: Date.now() });
        const b64Payload = Buffer.from(payload).toString('base64url');
        const signature = crypto.createHmac('sha256', this.SECRET).update(b64Payload).digest('base64url');
        return `${b64Payload}.${signature}`;
    }
    verifyToken(token) {
        try {
            const parts = token.split('.');
            if (parts.length !== 2)
                return null;
            const [b64Payload, signature] = parts;
            const expectedSig = crypto.createHmac('sha256', this.SECRET).update(b64Payload).digest('base64url');
            if (signature !== expectedSig)
                return null;
            const payload = JSON.parse(Buffer.from(b64Payload, 'base64url').toString('utf8'));
            return { userId: payload.userId, role: payload.role };
        }
        catch {
            return null;
        }
    }
    register(dto) {
        // 1. Check if phone or email already registered
        const existingPhone = this.db.prepare('SELECT id FROM users WHERE phone = ?').get(dto.phone);
        if (existingPhone) {
            throw new Error('A user with this phone number already exists.');
        }
        if (dto.email) {
            const existingEmail = this.db.prepare('SELECT id FROM users WHERE email = ?').get(dto.email);
            if (existingEmail) {
                throw new Error('A user with this email address already exists.');
            }
        }
        const userId = `${dto.role.toLowerCase()}_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
        const salt = crypto.randomBytes(16).toString('hex');
        const passwordHash = this.hashPassword(dto.password, salt);
        const now = Date.now();
        // 2. Insert into users table
        this.db.prepare(`
      INSERT INTO users (id, name, phone, email, password_hash, salt, role, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(userId, dto.name, dto.phone, dto.email || null, passwordHash, salt, dto.role, now);
        // 3. If Driver, create driver profile and starting prepaid wallet
        if (dto.role === 'DRIVER') {
            if (!dto.vehicleModel || !dto.vehiclePlate) {
                throw new Error('Vehicle model and license plate are required for driver registration.');
            }
            this.db.prepare(`
        INSERT INTO driver_profiles (driver_id, vehicle_model, vehicle_plate, rating, completed_trips, is_approved)
        VALUES (?, ?, ?, 5.0, 0, 1)
      `).run(userId, dto.vehicleModel, dto.vehiclePlate);
            // Create driver wallet with R150 starting development balance
            this.db.prepare(`
        INSERT INTO wallets (driver_id, balance, currency, is_suspended)
        VALUES (?, 150.0, 'ZAR', 0)
      `).run(userId);
            // Add initial welcome transaction
            this.db.prepare(`
        INSERT INTO wallet_transactions (id, driver_id, amount, type, description, timestamp)
        VALUES (?, ?, 150.0, 'BONUS', 'Welcome development credit bonus', ?)
      `).run(`tx_${Date.now()}_welcome`, userId, now);
        }
        const user = {
            id: userId,
            name: dto.name,
            phone: dto.phone,
            email: dto.email,
            role: dto.role,
            createdAt: now
        };
        const token = this.generateToken(userId, dto.role);
        return { user, token };
    }
    login(phone, password) {
        const row = this.db.prepare(`
      SELECT id, name, phone, email, password_hash, salt, role, created_at
      FROM users WHERE phone = ?
    `).get(phone);
        if (!row) {
            throw new Error('Invalid phone number or password.');
        }
        const testHash = this.hashPassword(password, row.salt);
        if (testHash !== row.password_hash) {
            throw new Error('Invalid phone number or password.');
        }
        const user = {
            id: row.id,
            name: row.name,
            phone: row.phone,
            email: row.email,
            role: row.role,
            createdAt: row.created_at
        };
        let profile = null;
        let wallet = null;
        if (row.role === 'DRIVER') {
            profile = this.db.prepare('SELECT * FROM driver_profiles WHERE driver_id = ?').get(row.id);
            wallet = this.db.prepare('SELECT * FROM wallets WHERE driver_id = ?').get(row.id);
        }
        const token = this.generateToken(row.id, row.role);
        return { user, token, profile, wallet };
    }
    getUserById(userId) {
        const row = this.db.prepare(`
      SELECT id, name, phone, email, role, created_at
      FROM users WHERE id = ?
    `).get(userId);
        if (!row)
            return null;
        return {
            id: row.id,
            name: row.name,
            phone: row.phone,
            email: row.email,
            role: row.role,
            createdAt: row.created_at
        };
    }
}
