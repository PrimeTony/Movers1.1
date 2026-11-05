import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';

class DriverReviewsScreen extends StatefulWidget {
  const DriverReviewsScreen({super.key});

  @override
  State<DriverReviewsScreen> createState() => _DriverReviewsScreenState();
}

class _DriverReviewsScreenState extends State<DriverReviewsScreen> {
  bool _isLoading = true;
  double _rating = 4.9;
  int _completedTrips = 0;
  String _driverName = 'Sipho Zulu';
  String _vehicleInfo = 'Toyota Corolla (White)';
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final session = AuthService().currentSession;
    final driverId = (session?.role == 'DRIVER' && session?.id != null) ? session!.id : 'driver_sipho';

    final data = await SocketService().fetchDriverReviews(driverId);
    if (mounted) {
      if (data != null) {
        final profile = data['profile'] as Map<String, dynamic>?;
        final revs = (data['reviews'] as List<dynamic>? ?? []);
        setState(() {
          if (profile != null) {
            _driverName = profile['name'] ?? _driverName;
            _rating = (profile['rating'] as num?)?.toDouble() ?? 4.9;
            _completedTrips = (profile['completedTrips'] as num?)?.toInt() ?? 0;
            _vehicleInfo = '${profile['vehicleModel']} • ${profile['vehiclePlate']}';
          }
          _reviews = revs.map((r) => r as Map<String, dynamic>).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
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
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.pureBlack,
        elevation: 0,
        title: const Text(
          'Job Ratings & Reviews',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentLime))
          : RefreshIndicator(
              onRefresh: _loadReviews,
              color: AppTheme.accentLime,
              backgroundColor: AppTheme.surfaceDark,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver Score Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.surfaceElevated,
                            child: Text(
                              _driverName.isNotEmpty ? _driverName[0] : 'D',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.accentLime),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _driverName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _vehicleInfo,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: AppTheme.starGold, size: 26),
                                      const SizedBox(width: 6),
                                      Text(
                                        _rating.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Average Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(width: 48),
                              Column(
                                children: [
                                  Text(
                                    '$_completedTrips',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Completed Jobs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reviews List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rider Feedback',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${_reviews.length} reviews',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_reviews.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.reviews_outlined, color: AppTheme.textTertiary, size: 40),
                            const SizedBox(height: 10),
                            const Text(
                              'No reviews received yet.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ratings and comments left by riders after trips will be shown here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final rev = _reviews[index];
                          final stars = (rev['rating'] as num?)?.toInt() ?? 5;
                          final comment = rev['comment'] as String? ?? '';
                          final riderName = rev['rider_name'] as String? ?? 'Rider';
                          final dateStr = _formatDate(rev['created_at'] ?? DateTime.now().millisecondsSinceEpoch);

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
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.surfaceElevated,
                                      child: Text(
                                        riderName.isNotEmpty ? riderName[0] : 'R',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(riderName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                        Text(dateStr, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                                      ],
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          Icons.star,
                                          size: 16,
                                          color: i < stars ? AppTheme.starGold : AppTheme.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    '"$comment"',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

