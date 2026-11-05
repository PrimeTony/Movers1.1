import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/socket_service.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  double _balance = 150.0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _transactions = [];
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _listenToWalletUpdates();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  String _getEffectiveDriverId() {
    final currentId = SocketService().currentUserId;
    final currentRole = SocketService().currentRole;
    return (currentRole == 'DRIVER' && currentId != null)
        ? currentId
        : 'driver_sipho';
  }

  Future<void> _loadWallet() async {
    final driverId = _getEffectiveDriverId();
    final wallet = await SocketService().fetchWallet(driverId);
    if (wallet != null && mounted) {
      setState(() {
        _balance = (wallet['balance'] as num).toDouble();
        final rawTx = wallet['transactions'] as List<dynamic>? ?? [];
        _transactions = rawTx.map((t) => t as Map<String, dynamic>).toList();
      });
    }
  }

  void _listenToWalletUpdates() {
    _socketSub = SocketService().eventStream.listen((event) {
      final type = event['type'] as String?;
      if (!mounted) return;

      if (type == 'WALLET_UPDATED') {
        final wallet = event['wallet'] as Map<String, dynamic>?;
        if (wallet != null) {
          setState(() {
            _balance = (wallet['balance'] as num).toDouble();
            final rawTx = wallet['transactions'] as List<dynamic>? ?? [];
            _transactions = rawTx
                .map((t) => t as Map<String, dynamic>)
                .toList();
          });
        }
      } else if (type == 'COMMISSION_SETTLED') {
        _loadWallet();
      }
    });
  }

  Future<void> _handleTopUp() async {
    setState(() => _isLoading = true);
    final driverId = _getEffectiveDriverId();
    final success = await SocketService().topUpWallet(driverId, 50.0);
    setState(() => _isLoading = false);

    if (success) {
      await _loadWallet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('R50.00 added to your wallet!'),
            backgroundColor: AppTheme.statusGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.pureBlack,
        elevation: 0,
        title: const Text(
          'Prepaid Wallet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _balance >= 50
                              ? AppTheme.statusGreen.withOpacity(0.15)
                              : Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _balance >= 50 ? 'ACTIVE' : 'LOW BALANCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _balance >= 50
                                ? AppTheme.statusGreen
                                : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Eligible for rides • 8% platform fee • R50 min cutoff',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Top Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleTopUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentLime,
                        foregroundColor: AppTheme.pureBlack,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.pureBlack,
                              ),
                            )
                          : const Text(
                              '+ Top Up R50.00',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Transactions Header
            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Transactions List
            if (_transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Text(
                  'No transactions recorded yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: AppTheme.borderSubtle, height: 28),
                itemBuilder: (context, index) {
                  final tx = _transactions[index];
                  final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  final isNegative = amount < 0;
                  final desc = tx['description'] ?? 'Transaction';
                  final type = tx['type'] ?? '';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isNegative ? '-' : '+'}R${amount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isNegative
                              ? AppTheme.textPrimary
                              : AppTheme.statusGreen,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
