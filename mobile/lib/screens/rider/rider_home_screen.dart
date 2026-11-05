import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dark_map_view.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import '../common/recent_rides_screen.dart';

enum RiderScreenState {
  locationPicker, // Page 1: Where to?
  fareProposal,   // Page 2: Route & R75 stepper
  biddingRadar,   // Page 3: Live bids from drivers
  driverEnRoute,  // Page 4: Arriving
  tripCompleted,  // Page 7: You've arrived & 5-star rating + review
}

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  RiderScreenState _currentState = RiderScreenState.locationPicker;

  int _offeredFare = 75;
  int _agreedFare = 85;
  int _ratingStars = 5;
  double _distanceKm = 5.7;
  int _durationMins = 9;

  String? _currentRideId;
  String? _assignedDriverId;
  String _driverName = 'Sipho Zulu';
  String _driverVehicle = 'Toyota Corolla • ND 842-192';
  double _driverRating = 4.9;

  // Dynamic user-entered locations
  LatLng _pickupPoint = const LatLng(-26.107567, 28.056702);
  LatLng _destinationPoint = const LatLng(-26.1466, 28.0436);
  String _pickupAddress = 'Sandton City, Rivonia Rd';
  String _destinationAddress = 'Rosebank Mall, Cradock Ave';

  // Dynamic ride details requested by user
  String _itemDescription = 'General ride & luggage';
  String _pickupTime = 'Now';
  String _paymentMethod = 'Cash';

  final TextEditingController _itemDescController = TextEditingController(text: 'General ride & luggage');
  final TextEditingController _reviewCommentController = TextEditingController();

  final List<Map<String, dynamic>> _liveBids = [];
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  List<LatLng> get _routePoints => [
        _pickupPoint,
        LatLng((_pickupPoint.latitude + _destinationPoint.latitude) / 2, (_pickupPoint.longitude + _destinationPoint.longitude) / 2),
        _destinationPoint,
      ];

  LatLng? get _driverLocation {
    if (_currentState == RiderScreenState.driverEnRoute) {
      return LatLng(
        _pickupPoint.latitude + 0.003,
        _pickupPoint.longitude - 0.002,
      );
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _listenToSocketEvents();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _itemDescController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  void _listenToSocketEvents() {
    _socketSub = SocketService().eventStream.listen((event) {
      final type = event['type'] as String?;
      if (!mounted) return;

      if (type == 'RIDE_BROADCAST') {
        final ride = event['ride'] as Map<String, dynamic>?;
        if (ride != null) {
          setState(() {
            _currentRideId = ride['id'] as String?;
          });
        }
      } else if (type == 'BID_RECEIVED') {
        final bid = event['bid'] as Map<String, dynamic>?;
        if (bid != null) {
          setState(() {
            _liveBids.removeWhere((b) => b['id'] == bid['id']);
            _liveBids.insert(0, bid);
          });
        }
      } else if (type == 'RIDE_LOCKED') {
        final accepted = event['acceptedBid'] as Map<String, dynamic>?;
        if (accepted != null) {
          setState(() {
            _agreedFare = (accepted['proposedPrice'] as num?)?.toInt() ?? _agreedFare;
            _assignedDriverId = accepted['driverId'];
            _driverName = accepted['driverName'] ?? _driverName;
            _driverVehicle = accepted['vehicleModel'] ?? _driverVehicle;
            _driverRating = (accepted['rating'] as num?)?.toDouble() ?? 4.9;
            _currentState = RiderScreenState.driverEnRoute;
          });
        }
      } else if (type == 'RIDE_STATUS_UPDATED') {
        final status = event['status'] as String?;
        if (status == 'ARRIVING' || status == 'IN_PROGRESS') {
          setState(() {
            _currentState = RiderScreenState.driverEnRoute;
          });
        } else if (status == 'COMPLETED') {
          setState(() {
            _currentState = RiderScreenState.tripCompleted;
          });
        }
      }
    });
  }

  Future<void> _updateRouteEstimate() async {
    final estimate = await SocketService().estimateRoute(
      {'latitude': _pickupPoint.latitude, 'longitude': _pickupPoint.longitude},
      {'latitude': _destinationPoint.latitude, 'longitude': _destinationPoint.longitude},
    );

    if (estimate != null && mounted) {
      setState(() {
        _distanceKm = (estimate['distanceKm'] as num).toDouble();
        _durationMins = (estimate['durationMinutes'] as num).toInt();
        _offeredFare = (estimate['suggestedFare'] as num).toInt();
      });
    }
  }

  final List<AddressSearchResult> _popularPlaces = [
    AddressSearchResult(displayName: 'Sandton City, 83 Rivonia Rd, Sandhurst, Sandton, 2196', name: 'Sandton City', latitude: -26.107567, longitude: 28.056702),
    AddressSearchResult(displayName: 'Rosebank Mall, 50 Bath Ave, Rosebank, Johannesburg, 2196', name: 'Rosebank Mall', latitude: -26.1466, longitude: 28.0436),
    AddressSearchResult(displayName: 'Mall of Africa, Magwa Cres, Waterfall City, Midrand, 1686', name: 'Mall of Africa', latitude: -26.0152, longitude: 28.1065),
    AddressSearchResult(displayName: 'O.R. Tambo International Airport, Kempton Park, 1627', name: 'OR Tambo Airport', latitude: -26.1367, longitude: 28.2411),
    AddressSearchResult(displayName: 'Fourways Mall, Cnr William Nicol & Witkoppen, Fourways, 2055', name: 'Fourways Mall', latitude: -26.0189, longitude: 28.0064),
    AddressSearchResult(displayName: 'Menlyn Park Shopping Centre, Atterbury Rd, Menlyn, Pretoria, 0063', name: 'Menlyn Park (Pretoria)', latitude: -25.7824, longitude: 28.2753),
    AddressSearchResult(displayName: 'Vilakazi Street, Orlando West, Soweto, 1804', name: 'Vilakazi St (Soweto)', latitude: -26.2378, longitude: 27.9056),
    AddressSearchResult(displayName: 'Johannesburg Park Station, Rissik St, Braamfontein, 2001', name: 'JHB Park Station', latitude: -26.1963, longitude: 28.0422),
  ];

  void _openAddressSearchModal(bool isPickup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String searchQuery = '';
        List<AddressSearchResult> searchResults = [];
        bool searching = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final displayList = searchQuery.isEmpty ? _popularPlaces : searchResults;

            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderSubtle, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPickup ? 'Set Pick-Up Location' : 'Set Destination',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Box
                  Container(
                    decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderSubtle)),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isPickup ? 'Search pickup place (e.g. Sandton, Rosebank, OR Tambo)' : 'Search destination address...',
                        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.accentLime),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onChanged: (val) async {
                        searchQuery = val.trim();
                        if (val.length >= 2) {
                          setModalState(() => searching = true);
                          // 1. Search local popular places
                          final localMatches = _popularPlaces.where((p) =>
                            p.name.toLowerCase().contains(val.toLowerCase()) ||
                            p.displayName.toLowerCase().contains(val.toLowerCase())
                          ).toList();

                          // 2. Search OpenStreetMap Nominatim live
                          final liveRes = await SocketService().searchAddresses(val);
                          
                          setModalState(() {
                            searchResults = [...localMatches, ...liveRes];
                            searching = false;
                          });
                        } else {
                          setModalState(() {
                            searchResults = [];
                            searching = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    searchQuery.isEmpty ? 'POPULAR PLACES NEARBY' : 'SEARCH RESULTS',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 8),

                  if (searching)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.accentLime)))
                  else
                    Expanded(
                      child: displayList.isEmpty
                          ? Center(
                              child: Text(
                                'No matching locations found for "$searchQuery"',
                                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: displayList.length,
                              separatorBuilder: (_, __) => const Divider(color: AppTheme.borderSubtle, height: 1),
                              itemBuilder: (context, idx) {
                                final item = displayList[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(isPickup ? Icons.my_location : Icons.location_on, color: isPickup ? AppTheme.statusGreen : AppTheme.accentLime, size: 18),
                                  ),
                                  title: Text(item.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                  subtitle: Text(item.displayName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      if (isPickup) {
                                        _pickupPoint = LatLng(item.latitude, item.longitude);
                                        _pickupAddress = item.name;
                                      } else {
                                        _destinationPoint = LatLng(item.latitude, item.longitude);
                                        _destinationAddress = item.name;
                                      }
                                    });
                                    await _updateRouteEstimate();
                                  },
                                );
                              },
                            ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _proposeRide() {
    _liveBids.clear();
    final session = AuthService().currentSession;
    SocketService().proposeRide(
      pickup: {
        'latitude': _pickupPoint.latitude,
        'longitude': _pickupPoint.longitude,
        'address': _pickupAddress,
      },
      destination: {
        'latitude': _destinationPoint.latitude,
        'longitude': _destinationPoint.longitude,
        'address': _destinationAddress,
      },
      suggestedFare: _offeredFare,
      itemDescription: _itemDescController.text.trim().isNotEmpty ? _itemDescController.text.trim() : _itemDescription,
      pickupTime: _pickupTime,
      paymentMethod: _paymentMethod,
      riderPhone: session?.phone ?? '+27829998888',
    );
    setState(() {
      _currentState = RiderScreenState.biddingRadar;
    });
  }

  void _acceptBid(Map<String, dynamic> bid) {
    if (_currentRideId != null) {
      SocketService().acceptBid(
        rideId: _currentRideId!,
        bidId: bid['id'] as String,
      );
    }
    setState(() {
      _agreedFare = (bid['proposedPrice'] as num).toInt();
      _assignedDriverId = bid['driverId'];
      _driverName = bid['driverName'] ?? 'Driver';
      _driverVehicle = bid['vehicleModel'] ?? 'Vehicle';
      _driverRating = (bid['rating'] as num?)?.toDouble() ?? 4.9;
      _currentState = RiderScreenState.driverEnRoute;
    });
  }

  Future<void> _submitReview() async {
    if (_currentRideId != null && _assignedDriverId != null) {
      final session = AuthService().currentSession;
      await SocketService().submitRideReview(
        rideId: _currentRideId!,
        driverId: _assignedDriverId!,
        riderId: session?.id ?? 'rider_hulisani',
        riderName: session?.name ?? 'Rider',
        rating: _ratingStars,
        comment: _reviewCommentController.text.trim(),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review & rating submitted! Thank you.'),
        backgroundColor: AppTheme.statusGreen,
      ),
    );

    setState(() {
      _currentState = RiderScreenState.locationPicker;
      _reviewCommentController.clear();
      _currentRideId = null;
      _assignedDriverId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: Stack(
        children: [
          // 1. Dark OpenStreetMap Layer
          DarkMapView(
            initialCenter: _pickupPoint,
            initialZoom: 13.5,
            routePoints: _currentState != RiderScreenState.locationPicker ? _routePoints : null,
            pickupPoint: _pickupPoint,
            destinationPoint: _currentState != RiderScreenState.locationPicker ? _destinationPoint : null,
            driverPoint: _driverLocation,
            showRadar: _currentState == RiderScreenState.biddingRadar,
          ),

          // Top Action: Recent Rides Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecentRidesScreen()),
                      );
                    },
                    icon: const Icon(Icons.history_rounded, size: 16, color: AppTheme.accentLime),
                    label: const Text('Recent Rides', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      backgroundColor: AppTheme.pureBlack.withOpacity(0.85),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. State-Driven Bottom Sheets
          Positioned(left: 0, right: 0, bottom: 0, child: _buildCurrentSheet()),
        ],
      ),
    );
  }

  Widget _buildCurrentSheet() {
    switch (_currentState) {
      case RiderScreenState.locationPicker:
        return _buildLocationPickerSheet();
      case RiderScreenState.fareProposal:
        return _buildFareProposalSheet();
      case RiderScreenState.biddingRadar:
        return _buildBiddingRadarSheet();
      case RiderScreenState.driverEnRoute:
        return _buildDriverEnRouteSheet();
      case RiderScreenState.tripCompleted:
        return _buildTripCompletedSheet();
    }
  }

  // ==========================================
  // PAGE 1: "Where to?" Sheet (Dynamic Inputs)
  // ==========================================
  Widget _buildLocationPickerSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where to?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Pickup Box (Interactive)
          GestureDetector(
            onTap: () => _openAddressSearchModal(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(width: 10, height: 10, color: AppTheme.textPrimary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _pickupAddress,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit_location_alt_outlined, size: 18, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Destination Box (Interactive)
          GestureDetector(
            onTap: () => _openAddressSearchModal(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentLime.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(width: 10, height: 10, color: AppTheme.accentLime),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _destinationAddress,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.search, size: 18, color: AppTheme.accentLime),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items description input (e.g. Courier or luggage)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: TextField(
              controller: _itemDescController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Items to move / courier (e.g. 2 boxes, luggage)',
                hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                icon: Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.textSecondary),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // CTA: Choose Ride & Fare
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _updateRouteEstimate();
                setState(() {
                  _currentState = RiderScreenState.fareProposal;
                });
              },
              child: const Text('Choose Ride & Fare'),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 2: Route, Details & Fare Stepper
  // ==========================================
  Widget _buildFareProposalSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Distance & Duration Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_distanceKm.toStringAsFixed(1)} km • $_durationMins mins',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _pickupAddress.split(',')[0],
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Large Fare Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: () {
                  if (_offeredFare > 30) setState(() => _offeredFare -= 5);
                },
                icon: const Icon(Icons.remove, color: AppTheme.textPrimary),
                style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceElevated, minimumSize: const Size(48, 48)),
              ),
              const SizedBox(width: 24),
              Text(
                'R $_offeredFare',
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -1.0),
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                onPressed: () {
                  setState(() => _offeredFare += 5);
                },
                icon: const Icon(Icons.add, color: AppTheme.textPrimary),
                style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceElevated, minimumSize: const Size(48, 48)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Your offered fare (drivers can counter-bid)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 18),

          // Options Row: Pickup Time & Payment Mode
          Row(
            children: [
              // Pickup Time Selector
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderSubtle)),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppTheme.accentLime),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _pickupTime,
                        underline: const SizedBox(),
                        dropdownColor: AppTheme.surfaceElevated,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                        items: ['Now', 'In 15 min', 'In 30 min'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _pickupTime = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Payment Method Selector
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderSubtle)),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: AppTheme.accentLime),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _paymentMethod,
                        underline: const SizedBox(),
                        dropdownColor: AppTheme.surfaceElevated,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                        items: ['Cash', 'Wallet'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentMethod = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Find Drivers Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proposeRide,
              child: const Text('Post Offer & Find Drivers'),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 3: Live Bidding Radar Sheet
  // ==========================================
  Widget _buildBiddingRadarSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.accentLime, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(
                _liveBids.isEmpty ? 'Waiting for driver bids...' : 'Incoming Driver Offers (${_liveBids.length})',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('Offer: R$_offeredFare', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),

          if (_liveBids.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
              child: Column(
                children: [
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accentLime)),
                  const SizedBox(height: 14),
                  const Text('Your offer is now live in the Driver Orders Feed.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Pickup: $_pickupAddress', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Items: ${_itemDescController.text}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _liveBids.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final bid = _liveBids[index];
                  final price = (bid['proposedPrice'] as num).toInt();
                  final diff = price - _offeredFare;
                  final badge = diff == 0 ? 'Matches offer' : (diff > 0 ? '+R$diff' : '-R${diff.abs()}');
                  final dName = bid['driverName'] as String? ?? 'Driver';
                  final initials = dName.isNotEmpty ? dName.split(' ').map((n) => n[0]).take(2).join() : 'DR';

                  return _buildBidCard(
                    avatar: initials,
                    name: dName,
                    rating: (bid['rating'] ?? 4.9).toString(),
                    vehicle: bid['vehicleModel'] ?? 'Vehicle',
                    price: price,
                    priceBadge: badge,
                    onAccept: () => _acceptBid(bid),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _currentState = RiderScreenState.fareProposal),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.borderSubtle),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancel Offer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidCard({
    required String avatar,
    required String name,
    required String rating,
    required String vehicle,
    required int price,
    String? priceBadge,
    required VoidCallback onAccept,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle, width: 1)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF333333),
                child: Text(avatar, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: AppTheme.starGold, size: 16),
                        const SizedBox(width: 2),
                        Text(rating, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(vehicle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('R$price', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  if (priceBadge != null)
                    Text(priceBadge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary,
                    foregroundColor: AppTheme.pureBlack,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 4: Driver En Route Sheet
  // ==========================================
  Widget _buildDriverEnRouteSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Driver Assigned & En Route', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Heading to $_pickupAddress', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),

          // Driver Profile Row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF333333),
                child: Text(
                  _driverName.isNotEmpty ? _driverName.split(' ').map((n) => n[0]).take(2).join() : 'DR',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_driverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: AppTheme.starGold, size: 16),
                        const SizedBox(width: 2),
                        Text(_driverRating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                    Text(_driverVehicle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Agreed Fare + Payment Info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agreed Fare ($_paymentMethod)', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Text('R$_agreedFare', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  setState(() => _currentState = RiderScreenState.tripCompleted);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Arrived / Finish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 7: Trip Completed, Rating & Review Sheet
  // ==========================================
  Widget _buildTripCompletedSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(color: AppTheme.statusGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppTheme.pureBlack, size: 30),
            ),
            const SizedBox(height: 12),
            const Text("You've arrived!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(_destinationAddress, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),

            // Payment Receipt Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total to pay driver', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Method: $_paymentMethod', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentLime)),
                    ],
                  ),
                  const Spacer(),
                  Text('R$_agreedFare', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rating Stars
            Text('Rate your trip with $_driverName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _ratingStars = index + 1),
                  icon: Icon(Icons.star, size: 36, color: index < _ratingStars ? AppTheme.starGold : AppTheme.textTertiary),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Comment Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderSubtle)),
              child: TextField(
                controller: _reviewCommentController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Leave a comment for this job (e.g. Great driver, on time!)',
                  hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Review Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentLime,
                  foregroundColor: AppTheme.pureBlack,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Submit Review & Finish', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
