import { DriverWallet, WalletTransaction } from '../types/ride.js';
import { DatabaseService } from './db.service.js';

export interface SettlementResult {
  fare: number;
  commissionPercentage: number;
  commissionDeducted: number;
  driverEarnings: number;
  remainingBalance: number;
  isSuspended: boolean;
}

export class WalletService {
  private readonly COMMISSION_PERCENTAGE = 8.5;
  private db = DatabaseService.getInstance().db;

  public getWallet(driverId: string): DriverWallet {
    let row = this.db.prepare('SELECT driver_id, balance, currency, is_suspended FROM wallets WHERE driver_id = ?').get(driverId) as any;

    if (!row) {
      // Ensure user exists in users table before inserting wallet
      const userExists = this.db.prepare('SELECT id FROM users WHERE id = ?').get(driverId);
      if (!userExists) {
        this.db.prepare(`
          INSERT OR IGNORE INTO users (id, name, phone, email, password_hash, salt, role, created_at)
          VALUES (?, ?, ?, ?, 'dev_pass', 'dev_salt', 'DRIVER', ?)
        `).run(driverId, driverId, `+2782${Math.floor(1000000 + Math.random() * 9000000)}`, `${driverId}@movers.local`, Date.now());
      }

      // Auto-create with R150 starting credit
      this.db.prepare('INSERT INTO wallets (driver_id, balance, currency, is_suspended) VALUES (?, 150.0, ?, 0)').run(driverId, 'ZAR');
      this.db.prepare('INSERT INTO wallet_transactions (id, driver_id, amount, type, description, timestamp) VALUES (?, ?, 150.0, ?, ?, ?)').run(
        `tx_${Date.now()}_init`, driverId, 'BONUS', 'Initial account welcome balance', Date.now()
      );
      row = { driver_id: driverId, balance: 150.0, currency: 'ZAR', is_suspended: 0 };
    }

    const txRows = this.db.prepare('SELECT id, driver_id, ride_id, amount, type, description, timestamp FROM wallet_transactions WHERE driver_id = ? ORDER BY timestamp DESC').all(driverId) as any[];

    const transactions: WalletTransaction[] = txRows.map((t) => ({
      id: t.id,
      driverId: t.driver_id,
      rideId: t.ride_id,
      amount: t.amount,
      type: t.type,
      description: t.description,
      timestamp: t.timestamp
    }));

    return {
      driverId: row.driver_id,
      balance: row.balance,
      currency: row.currency,
      isSuspended: row.is_suspended === 1,
      transactions
    };
  }

  public isDriverEligible(driverId: string): boolean {
    const wallet = this.getWallet(driverId);
    return !wallet.isSuspended && wallet.balance >= 0;
  }

  public settleRideCommission(driverId: string, rideId: string, finalFare: number): SettlementResult {
    const wallet = this.getWallet(driverId);

    const commissionDeducted = Number(((finalFare * this.COMMISSION_PERCENTAGE) / 100).toFixed(2));
    const driverEarnings = Number((finalFare - commissionDeducted).toFixed(2));
    const newBalance = Number((wallet.balance - commissionDeducted).toFixed(2));
    const isSuspended = newBalance < 0 ? 1 : 0;

    // Update wallet in DB
    this.db.prepare('UPDATE wallets SET balance = ?, is_suspended = ? WHERE driver_id = ?').run(newBalance, isSuspended, driverId);

    // Insert transaction
    const txId = `tx_${Date.now()}_com`;
    const desc = `Platform fee (${this.COMMISSION_PERCENTAGE}%) for ride #${rideId} (Fare: R${finalFare})`;
    this.db.prepare('INSERT INTO wallet_transactions (id, driver_id, ride_id, amount, type, description, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)').run(
      txId, driverId, rideId, -commissionDeducted, 'COMMISSION_DEDUCTION', desc, Date.now()
    );

    console.log(
      `[Wallet DB] Settle Ride #${rideId}: Fee -R${commissionDeducted} deducted from ${driverId}. Remaining Balance: R${newBalance}`
    );

    return {
      fare: finalFare,
      commissionPercentage: this.COMMISSION_PERCENTAGE,
      commissionDeducted,
      driverEarnings,
      remainingBalance: newBalance,
      isSuspended: isSuspended === 1
    };
  }

  public topUp(driverId: string, amount: number, paymentMethod = 'Instant EFT'): DriverWallet {
    if (amount <= 0) {
      throw new Error('Top-up amount must be greater than zero');
    }

    const wallet = this.getWallet(driverId);
    const newBalance = Number((wallet.balance + amount).toFixed(2));
    const isSuspended = newBalance < 0 ? 1 : 0;

    this.db.prepare('UPDATE wallets SET balance = ?, is_suspended = ? WHERE driver_id = ?').run(newBalance, isSuspended, driverId);

    const txId = `tx_${Date.now()}_topup`;
    this.db.prepare('INSERT INTO wallet_transactions (id, driver_id, amount, type, description, timestamp) VALUES (?, ?, ?, ?, ?, ?)').run(
      txId, driverId, amount, 'TOP_UP', `Top-up via ${paymentMethod}`, Date.now()
    );

    console.log(`[Wallet DB] Top-up: R${amount} added to ${driverId}. New Balance: R${newBalance}`);
    return this.getWallet(driverId);
  }
}
