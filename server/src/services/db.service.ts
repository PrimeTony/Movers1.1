import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DATA_DIR = path.resolve(__dirname, '../../data');
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const DB_PATH = path.join(DATA_DIR, 'movers.db');

export class DatabaseService {
  private static instance: DatabaseService;
  public db: DatabaseSync;

  private constructor() {
    this.db = new DatabaseSync(DB_PATH);
    this.initTables();
    this.seedInitialDrivers();
  }

  public static getInstance(): DatabaseService {
    if (!DatabaseService.instance) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  private initTables(): void {
    // 1. Users Table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        role TEXT NOT NULL, -- 'RIDER' or 'DRIVER'
        created_at INTEGER NOT NULL
      );
    `);

    // 2. Driver Profiles Table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS driver_profiles (
        driver_id TEXT PRIMARY KEY,
        vehicle_model TEXT NOT NULL,
        vehicle_plate TEXT NOT NULL,
        rating REAL DEFAULT 5.0,
        completed_trips INTEGER DEFAULT 0,
        is_approved INTEGER DEFAULT 1,
        FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
      );
    `);

    // 3. Driver Wallets Table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS wallets (
        driver_id TEXT PRIMARY KEY,
        balance REAL DEFAULT 150.0,
        currency TEXT DEFAULT 'ZAR',
        is_suspended INTEGER DEFAULT 0,
        FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
      );
    `);

    // 4. Wallet Transactions Table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id TEXT PRIMARY KEY,
        driver_id TEXT NOT NULL,
        ride_id TEXT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
      );
    `);

    // 5. Persistent Rides Table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS rides (
        id TEXT PRIMARY KEY,
        rider_id TEXT NOT NULL,
        rider_name TEXT NOT NULL,
        rider_phone TEXT,
        pickup_address TEXT NOT NULL,
        destination_address TEXT NOT NULL,
        pickup_lat REAL NOT NULL,
        pickup_lon REAL NOT NULL,
        dest_lat REAL NOT NULL,
        dest_lon REAL NOT NULL,
        distance_km REAL NOT NULL,
        duration_minutes REAL NOT NULL,
        item_description TEXT DEFAULT 'Standard ride / parcels',
        pickup_time TEXT DEFAULT 'Now',
        payment_method TEXT DEFAULT 'Cash',
        suggested_fare REAL NOT NULL,
        final_fare REAL,
        driver_id TEXT,
        driver_name TEXT,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);

    // 6. Ride Reviews & Driver Ratings Table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS ride_reviews (
        id TEXT PRIMARY KEY,
        ride_id TEXT NOT NULL,
        driver_id TEXT NOT NULL,
        rider_id TEXT NOT NULL,
        rider_name TEXT NOT NULL,
        rating INTEGER NOT NULL,
        comment TEXT,
        created_at INTEGER NOT NULL
      );
    `);
  }

  private seedInitialDrivers(): void {
    const existing = this.db.prepare('SELECT id FROM users WHERE id = ?').get('driver_sipho');
    if (existing) return;

    // Seed mock drivers so tests and simulations run smoothly
    const now = Date.now();

    const insertUser = this.db.prepare(`
      INSERT INTO users (id, name, phone, email, password_hash, salt, role, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const insertProfile = this.db.prepare(`
      INSERT INTO driver_profiles (driver_id, vehicle_model, vehicle_plate, rating, completed_trips, is_approved)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    const insertWallet = this.db.prepare(`
      INSERT INTO wallets (driver_id, balance, currency, is_suspended)
      VALUES (?, ?, ?, ?)
    `);

    // Sipho Zulu
    insertUser.run('driver_sipho', 'Sipho Zulu', '+27821112222', 'sipho@movers.app', 'hash_sipho', 'salt', 'DRIVER', now);
    insertProfile.run('driver_sipho', 'Toyota Corolla (White)', 'ND 842-192', 4.9, 1420, 1);
    insertWallet.run('driver_sipho', 150.0, 'ZAR', 0);

    // Thabo Mokoena
    insertUser.run('driver_thabo', 'Thabo Mokoena', '+27823334444', 'thabo@movers.app', 'hash_thabo', 'salt', 'DRIVER', now);
    insertProfile.run('driver_thabo', 'Volkswagen Polo (Silver)', 'GP 301-449', 4.8, 875, 1);
    insertWallet.run('driver_thabo', 200.0, 'ZAR', 0);

    // Lerato Khumalo
    insertUser.run('driver_lerato', 'Lerato Khumalo', '+27825556666', 'lerato@movers.app', 'hash_lerato', 'salt', 'DRIVER', now);
    insertProfile.run('driver_lerato', 'Hyundai Grand i10 (Grey)', 'CA 551-902', 5.0, 430, 1);
    insertWallet.run('driver_lerato', 80.0, 'ZAR', 0);

    // Hulisani Mbedzi (Demo Rider)
    insertUser.run('rider_hulisani', 'Hulisani Mbedzi', '+27829998888', 'hulisani@movers.app', 'hash_hulisani', 'salt', 'RIDER', now);
  }
}

