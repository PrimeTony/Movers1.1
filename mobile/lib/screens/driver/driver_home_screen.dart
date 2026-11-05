import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dark_map_view.dart';
import '../../widgets/slide_to_confirm.dart';
import '../../services/socket_service.dart';
import 'driver_wallet_screen.dart';
import 'driver_reviews_screen.dart';
import '../common/recent_rides_screen.dart';

enum DriverScreenState {
  onlineRadar, // Live Radar & Available Orders feed
  incomingRequest, // Active single order focus
  tripNavigation, // Arrived / Start / Complete + Slide to confirm
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  DriverScreenState _currentState = DriverScreenState.onlineRadar;
  bool _isOnline = true;
  double _walletBalance = 150.0;
  int _activeTab = 0; // 0 = Available Orders Feed, 1 = Online Radar

  // Stepper state for Page 9: 0 = Arrived, 1 = Start, 2 = Complete
  int _tripStep = 0;

  String? _currentRideId;
  String _riderName = 'Hulisani Mbedzi';
  String _riderPhone = '+27829998888';
  int _proposedFare = 75;
  int _agreedFare = 85;
  String _pickupAddress = 'Sandton City, Rivonia Rd';
  String _destinationAddress = 'Rosebank Mall, Cradock Ave';
  String _itemDescription = 'General luggage / parcels';
  String _pickupTime = 'Now';
  String _paymentMethod = 'Cash';
  double _distanceKm = 5.7;

  // Real-time Available Orders Feed from SQLite & WebSockets
  List<Map<String, dynamic>> _availableOrders = [];
  bool _loadingOrders = false;

  StreamSubscription<Map<String, dynamic>>? _socketSub;

  LatLng _driverLocation = const LatLng(-26.1150, 28.0540);
  LatLng _pickupLocation = const LatLng(-26.107567, 28.056702);
  LatLng _destinationLocation = const LatLng(-26.1466, 28.0436);

  List<LatLng> get _routePoints => [
    _driverLocation,
    _pickupLocation,
    LatLng(
      (_pickupLocation.latitude + _destinationLocation.latitude) / 2,
      (_pickupLocation.longitude + _destinationLocation.longitude) / 2,
    ),
    _destinationLocation,
  ];

  String _getEffectiveDriverId() {
    final currentId = SocketService().currentUserId;
    final currentRole = SocketService().currentRole;
    return (currentRole == 'DRIVER' && currentId != null)
        ? currentId
        : 'driver_sipho';
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialWallet();
    _loadAvailableOrders();
    _listenToSocketEvents();
    _broadcastLocation();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialWallet() async {
    final driverId = _getEffectiveDriverId();
    final wallet = await SocketService().fetchWallet(driverId);
    if (wallet != null && mounted) {
      setState(() {
        _walletBalance = (wallet['balance'] as num).toDouble();
      });
    }
  }

  Future<void> _loadAvailableOrders() async {
    setState(() => _loadingOrders = true);
    final orders = await SocketService().fetchActiveOrders();
    if (mounted) {
      setState(() {
        _availableOrders = orders;
        _loadingOrders = false;
      });
    }
  }

  void _broadcastLocation() {
    if (_isOnline) {
      SocketService().updateDriverLocation(
        latitude: _driverLocation.latitude,
        longitude: _driverLocation.longitude,
      );
    }
  }

  void _listenToSocketEvents() {
    _socketSub = SocketService().eventStream.listen((event) {
      final type = event['type'] as String?;
      if (!mounted) return;

      if (type == 'RIDE_BROADCAST') {
        final ride = event['ride'] as Map<String, dynamic>?;
        if (ride != null) {
          setState(() {
            _availableOrders.removeWhere((o) => o['id'] == ride['id']);
            _availableOrders.insert(0, ride);
          });
        }
      } else if (type == 'RIDE_LOCKED') {
        final accepted = event['acceptedBid'] as Map<String, dynamic>?;
        final myDriverId = _getEffectiveDriverId();
        if (accepted != null && accepted['driverId'] == myDriverId) {
          setState(() {
            _agreedFare =
                (accepted['proposedPrice'] as num?)?.toInt() ?? _proposedFare;
            _currentState = DriverScreenState.tripNavigation;
            _tripStep = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deal sealed! R$_agreedFare agreed with $_riderName',
              ),
              backgroundColor: AppTheme.statusGreen,
            ),
          );
        }
      } else if (type == 'WALLET_UPDATED') {
        final wallet = event['wallet'] as Map<String, dynamic>?;
        if (wallet != null) {
          setState(() {
            _walletBalance = (wallet['balance'] as num).toDouble();
          });
        }
      } else if (type == 'COMMISSION_SETTLED') {
        final remaining = event['remainingBalance'] as num?;
        if (remaining != null) {
          setState(() {
            _walletBalance = remaining.toDouble();
          });
        }
      }
    });
  }

  void _selectOrder(Map<String, dynamic> order) {
    setState(() {
      _currentRideId = order['id'];
      _riderName = order['rider_name'] ?? order['riderName'] ?? 'Rider';
      _riderPhone =
          order['rider_phone'] ?? order['riderPhone'] ?? '+27829998888';
      _proposedFare =
          (order['suggested_fare'] ?? order['suggestedFare'] as num?)
              ?.toInt() ??
          75;
      _pickupAddress =
          order['pickup_address'] ??
          order['pickup']?['address'] ??
          'Pickup Point';
      _destinationAddress =
          order['destination_address'] ??
          order['destination']?['address'] ??
          'Destination Point';
      _itemDescription =
          order['item_description'] ??
          order['itemDescription'] ??
          'Standard items';
      _pickupTime = order['pickup_time'] ?? order['pickupTime'] ?? 'Now';
      _paymentMethod =
          order['payment_method'] ?? order['paymentMethod'] ?? 'Cash';
      _distanceKm =
          (order['distance_km'] ?? order['distanceKm'] as num?)?.toDouble() ??
          5.0;

      final pLat = (order['pickup_lat'] ?? order['pickup']?['latitude'] as num?)
          ?.toDouble();
      final pLon =
          (order['pickup_lon'] ?? order['pickup']?['longitude'] as num?)
              ?.toDouble();
      final dLat =
          (order['dest_lat'] ?? order['destination']?['latitude'] as num?)
              ?.toDouble();
      final dLon =
          (order['dest_lon'] ?? order['destination']?['longitude'] as num?)
              ?.toDouble();

      if (pLat != null && pLon != null) _pickupLocation = LatLng(pLat, pLon);
      if (dLat != null && dLon != null)
        _destinationLocation = LatLng(dLat, dLon);

      _currentState = DriverScreenState.incomingRequest;
    });
  }

  void _sendBid(int price) {
    if (_currentRideId != null) {
      SocketService().submitBid(
        rideId: _currentRideId!,
        proposedPrice: price,
        etaMinutes: 4,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Offer of R$price sent to $_riderName. Waiting for acceptance...',
          ),
          backgroundColor: AppTheme.surfaceElevated,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: Stack(
        children: [
          // 1. Dark Map Layer
          DarkMapView(
            initialCenter: _driverLocation,
            initialZoom: 13.5,
            routePoints: _currentState != DriverScreenState.onlineRadar
                ? _routePoints
                : null,
            pickupPoint: _currentState != DriverScreenState.onlineRadar
                ? _pickupLocation
                : null,
            destinationPoint: _currentState != DriverScreenState.onlineRadar
                ? _destinationLocation
                : null,
            driverPoint: _driverLocation,
          ),

          // 2. Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Online Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.pureBlack,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _isOnline,
                            onChanged: (val) {
                              setState(() {
                                _isOnline = val;
                                if (_isOnline) _broadcastLocation();
                              });
                            },
                            activeThumbColor: AppTheme.pureBlack,
                            activeTrackColor: AppTheme.textPrimary,
                            inactiveThumbColor: AppTheme.textSecondary,
                            inactiveTrackColor: AppTheme.surfaceElevated,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppTheme.statusGreen
                                : AppTheme.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Ratings Shortcut Button
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverReviewsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.star_outline_rounded,
                      color: AppTheme.starGold,
                      size: 22,
                    ),
                    tooltip: 'Ratings & Reviews',
                  ),

                  // History Shortcut Button
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecentRidesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.history_rounded,
                      color: AppTheme.textPrimary,
                      size: 22,
                    ),
                    tooltip: 'Job History',
                  ),

                  // Wallet Badge Pill
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverWalletScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: AppTheme.accentLime,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'R${_walletBalance.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Dynamic Bottom Sheets
          Positioned(left: 0, right: 0, bottom: 0, child: _buildCurrentSheet()),
        ],
      ),
    );
  }

  Widget _buildCurrentSheet() {
    switch (_currentState) {
      case DriverScreenState.onlineRadar:
        return _buildAvailableOrdersSheet();
      case DriverScreenState.incomingRequest:
        return _buildSingleOrderSheet();
      case DriverScreenState.tripNavigation:
        return _buildTripNavigationSheet();
    }
  }

  // ==========================================
  // AVAILABLE ORDERS FEED SHEET (No Hardcoded Data!)
  // ==========================================
  Widget _buildAvailableOrdersSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.accentLime,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Available Orders Feed (${_availableOrders.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadAvailableOrders,
                icon: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_loadingOrders)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppTheme.accentLime),
              ),
            )
          else if (_availableOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.radar,
                    color: AppTheme.textTertiary,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No active rider orders right now.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'When riders in your area post fare offers, they will appear in this live feed automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _availableOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = _availableOrders[index];
                  final fare =
                      (order['suggested_fare'] ??
                              order['suggestedFare'] as num?)
                          ?.toInt() ??
                      75;
                  final rName =
                      order['rider_name'] ?? order['riderName'] ?? 'Rider';
                  final pAddress =
                      order['pickup_address'] ??
                      order['pickup']?['address'] ??
                      'Pickup Point';
                  final dAddress =
                      order['destination_address'] ??
                      order['destination']?['address'] ??
                      'Destination Point';
                  final items =
                      order['item_description'] ??
                      order['itemDescription'] ??
                      'Standard Courier / Luggage';
                  final pTime =
                      order['pickup_time'] ?? order['pickupTime'] ?? 'Now';
                  final dist =
                      (order['distance_km'] ?? order['distanceKm'] as num?)
                          ?.toStringAsFixed(1) ??
                      '5.0';

                  return GestureDetector(
                    onTap: () => _selectOrder(order),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏱ $pTime',
                                  style: const TextStyle(
                                    color: AppTheme.accentLime,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'R$fare',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Route Row
                          Row(
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    color: AppTheme.textPrimary,
                                  ),
                                  Container(
                                    width: 1.5,
                                    height: 16,
                                    color: AppTheme.borderSubtle,
                                  ),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    color: AppTheme.accentLime,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pAddress,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dAddress,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Details badge: Items + Distance
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  items,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$dist km',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _selectOrder(order),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textPrimary,
                                    side: const BorderSide(
                                      color: AppTheme.borderSubtle,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('View & Counter'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _selectOrder(order);
                                    _sendBid(fare);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentLime,
                                    foregroundColor: AppTheme.pureBlack,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Accept R$fare',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SINGLE ORDER INSPECTION & COUNTER SHEET
  // ==========================================
  Widget _buildSingleOrderSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ride Request from $_riderName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _currentState = DriverScreenState.onlineRadar,
                ),
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Route Details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickupAddress,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppTheme.accentLime,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _destinationAddress,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.borderSubtle, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📦 Items: $_itemDescription',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '⏱ Time: $_pickupTime',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '💵 Method: $_paymentMethod',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '📍 ${_distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fare Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rider proposes',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'R$_proposedFare',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Accept CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _sendBid(_proposedFare),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentLime,
                foregroundColor: AppTheme.pureBlack,
              ),
              child: Text(
                'Accept for R$_proposedFare',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Counter-Offer Chips: [+R10], [+R20], [+R30]
          Row(
            children: [
              Expanded(
                child: _buildCounterChip(
                  '+R10 (R${_proposedFare + 10})',
                  () => _sendBid(_proposedFare + 10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCounterChip(
                  '+R20 (R${_proposedFare + 20})',
                  () => _sendBid(_proposedFare + 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCounterChip(
                  '+R30 (R${_proposedFare + 30})',
                  () => _sendBid(_proposedFare + 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterChip(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ==========================================
  // PAGE 9: Active Trip Navigation Sheet
  // ==========================================
  Widget _buildTripNavigationSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStepItem('Arrived', 0),
              _buildStepItem('Start', 1),
              _buildStepItem('Complete', 2),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF333333),
                child: Text(
                  _riderName.isNotEmpty ? _riderName[0] : 'R',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _riderName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _tripStep == 0
                          ? 'Heading to pickup'
                          : _tripStep == 1
                          ? 'Trip in progress • $_itemDescription'
                          : 'Arrived at destination',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                'R$_agreedFare',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(width: 10, height: 10, color: AppTheme.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tripStep == 0 ? _pickupAddress : _destinationAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SlideToConfirm(
            text: _tripStep == 0
                ? 'Slide to confirm arrival'
                : _tripStep == 1
                ? 'Slide to start trip'
                : 'Slide to complete trip',
            onConfirmed: () {
              if (_tripStep == 0) {
                if (_currentRideId != null)
                  SocketService().updateRideStatus(
                    rideId: _currentRideId!,
                    status: 'ARRIVING',
                  );
                setState(() => _tripStep = 1);
              } else if (_tripStep == 1) {
                if (_currentRideId != null)
                  SocketService().updateRideStatus(
                    rideId: _currentRideId!,
                    status: 'IN_PROGRESS',
                  );
                setState(() => _tripStep = 2);
              } else {
                if (_currentRideId != null)
                  SocketService().updateRideStatus(
                    rideId: _currentRideId!,
                    status: 'COMPLETED',
                  );
                final fee = (_agreedFare * 0.085).toStringAsFixed(2);
                setState(() {
                  _currentState = DriverScreenState.onlineRadar;
                  _tripStep = 0;
                  _availableOrders.removeWhere(
                    (o) => o['id'] == _currentRideId,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Trip completed! R$fee (8.5%) commission settled.',
                    ),
                    backgroundColor: AppTheme.statusGreen,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, int stepIndex) {
    final isActive = _tripStep == stepIndex;
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.5,
            color: isActive ? AppTheme.textPrimary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
