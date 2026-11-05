import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';

class RecentRidesScreen extends StatefulWidget {
  const RecentRidesScreen({super.key});

  @override
  State<RecentRidesScreen> createState() => _RecentRidesScreenState();
}

class _RecentRidesScreenState extends State<RecentRidesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rides = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final session = AuthService().currentSession;
    final role = session?.role ?? 'RIDER';
    final userId = session?.id ?? 'rider_hulisani';

    final history = await SocketService().fetchRideHistory(role, userId);
    if (mounted) {
      setState(() {
        _rides = history;
        _isLoading = false;
      });
    }
  }

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hours = dt.hour.toString().padLeft(2, '0');
    final mins = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month • $hours:$mins';
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService().currentSession;
    final isDriver = session?.role == 'DRIVER';

    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.pureBlack,
        elevation: 0,
        title: Text(
          isDriver ? 'Driver Job History' : 'Recent Rides',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentLime),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: AppTheme.accentLime,
              backgroundColor: AppTheme.surfaceDark,
              child: _rides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 56, color: AppTheme.textTertiary),
                          const SizedBox(height: 14),
                          const Text(
                            'No previous rides recorded yet.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Completed trips will appear here with reviews & fares.',
                            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final r = _rides[index];
                        final fare = (r['final_fare'] ?? r['suggested_fare'] as num?)?.toDouble() ?? 0.0;
                        final status = r['status'] as String? ?? 'COMPLETED';
                        final timeStr = _formatDate(r['created_at'] ?? DateTime.now().millisecondsSinceEpoch);
                        final items = r['item_description'] as String? ?? 'Standard Ride';
                        final payment = r['payment_method'] as String? ?? 'Cash';
                        final reviewRating = r['review_rating'] as num?;
                        final reviewComment = r['review_comment'] as String?;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar: Date + Status Badge + Price
                              Row(
                                children: [
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: status == 'COMPLETED'
                                          ? AppTheme.statusGreen.withOpacity(0.15)
                                          : AppTheme.accentLime.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: status == 'COMPLETED' ? AppTheme.statusGreen : AppTheme.accentLime,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'R${fare.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Route Display
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(width: 8, height: 8, color: AppTheme.textPrimary),
                                      Container(width: 2, height: 20, color: AppTheme.borderSubtle),
                                      Container(width: 8, height: 8, color: AppTheme.accentLime),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r['pickup_address'] ?? 'Pickup Point',
                                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          r['destination_address'] ?? 'Destination Point',
                                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Tags: Distance + Courier Items + Payment
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildTag(Icons.route_outlined, '${(r['distance_km'] as num?)?.toStringAsFixed(1) ?? '5.0'} km'),
                                  _buildTag(Icons.inventory_2_outlined, items),
                                  _buildTag(Icons.payments_outlined, payment),
                                  if (r['driver_name'] != null)
                                    _buildTag(Icons.directions_car_outlined, r['driver_name'] as String),
                                ],
                              ),

                              // Review if exists
                              if (reviewRating != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            Icons.star,
                                            size: 14,
                                            color: i < reviewRating ? AppTheme.starGold : AppTheme.textTertiary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          reviewComment?.isNotEmpty == true ? '"$reviewComment"' : 'Rated ${reviewRating}★',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

