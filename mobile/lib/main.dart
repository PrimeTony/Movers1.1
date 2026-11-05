import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/rider/rider_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/driver_wallet_screen.dart';
import 'screens/driver/driver_reviews_screen.dart';
import 'screens/common/recent_rides_screen.dart';

void main() {
  runApp(const MoversApp());
}

class MoversApp extends StatelessWidget {
  const MoversApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ValueListenableBuilder<UserSession?>(
        valueListenable: AuthService().sessionNotifier,
        builder: (context, session, _) {
          if (session == null) {
            return const AuthScreen();
          }
          return MainNavigationShell(session: session);
        },
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final UserSession session;
  const MainNavigationShell({super.key, required this.session});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _selectedTabIndex;

  final List<Widget> _screens = const [
    RiderHomeScreen(),
    DriverHomeScreen(),
    DriverWalletScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Default to Driver tab if driver, otherwise Rider tab
    _selectedTabIndex = widget.session.role == 'DRIVER' ? 1 : 0;
  }

  void _showAccountDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.accentLime.withOpacity(0.15),
                      child: Text(
                        widget.session.name.isNotEmpty
                            ? widget.session.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppTheme.accentLime,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.session.phone,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLime.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentLime.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        widget.session.role,
                        style: const TextStyle(
                          color: AppTheme.accentLime,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.session.role == 'DRIVER' &&
                    widget.session.profile != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.pureBlack,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.session.profile?['vehicle_model'] ??
                              'Vehicle Registered',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.session.profile?['vehicle_plate'] ?? '',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Recent Rides Option
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.pureBlack, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.history_rounded, color: AppTheme.accentLime, size: 20),
                  ),
                  title: const Text('Recent Rides & History', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecentRidesScreen()));
                  },
                ),

                // Driver Ratings Option
                if (widget.session.role == 'DRIVER') ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.pureBlack, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.star_outline_rounded, color: AppTheme.starGold, size: 20),
                    ),
                    title: const Text('Job Ratings & Reviews', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverReviewsScreen()));
                    },
                  ),
                ],

                const SizedBox(height: 16),
                // Sign Out Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      AuthService().signOut();
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.pureBlack,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentLime.withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.near_me_rounded,
                color: AppTheme.accentLime,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'MOVERS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showAccountDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.accentLime,
                    child: Text(
                      widget.session.name.isNotEmpty
                          ? widget.session.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppTheme.pureBlack,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.session.name.split(' ').first,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedTabIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.pureBlack,
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 0.8),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: (index) => setState(() => _selectedTabIndex = index),
          backgroundColor: AppTheme.pureBlack,
          selectedItemColor: AppTheme.textPrimary,
          unselectedItemColor: AppTheme.textTertiary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.person_pin_circle_outlined),
              activeIcon: Icon(Icons.person_pin_circle),
              label: 'Rider View',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car),
              label: 'Driver View',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
          ],
        ),
      ),
    );
  }
}
