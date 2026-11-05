import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class AddressSearchResult {
  final String displayName;
  final String name;
  final double latitude;
  final double longitude;

  AddressSearchResult({
    required this.displayName,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory AddressSearchResult.fromJson(Map<String, dynamic> json) {
    return AddressSearchResult(
      displayName: json['displayName'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? currentUserId;
  String? currentRole;
  String? currentName;

  static const String serverHost = '127.0.0.1:4000';
  static const String wsUrl = 'ws://$serverHost/ws';
  static const String httpUrl = 'http://$serverHost';

  void connect({required String userId, required String role, required String name}) {
    currentUserId = userId;
    currentRole = role;
    currentName = name;

    if (_isConnected) {
      send({
        'type': 'REGISTER',
        'role': role,
        'userId': userId,
        'name': name,
      });
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      send({
        'type': 'REGISTER',
        'role': role,
        'userId': userId,
        'name': name,
      });

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            _eventController.add(parsed);
          } catch (e) {
            debugPrint('[WS] Error parsing: $e');
          }
        },
        onError: (err) {
          debugPrint('[WS] Stream error: $err');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('[WS] Disconnected');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('[WS] Connection exception: $e');
      _isConnected = false;
    }
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  // ==========================================
  // REAL-TIME WEBSOCKET EVENTS
  // ==========================================

  void proposeRide({
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> destination,
    required int suggestedFare,
    String? itemDescription,
    String? pickupTime,
    String? paymentMethod,
    String? riderPhone,
  }) {
    send({
      'type': 'PROPOSE_RIDE',
      'pickup': pickup,
      'destination': destination,
      'suggestedFare': suggestedFare,
      'itemDescription': itemDescription ?? 'Standard ride / parcel',
      'pickupTime': pickupTime ?? 'Now',
      'paymentMethod': paymentMethod ?? 'Cash',
      'riderPhone': riderPhone,
    });
  }

  void submitBid({
    required String rideId,
    required int proposedPrice,
    int etaMinutes = 4,
  }) {
    send({
      'type': 'SUBMIT_BID',
      'rideId': rideId,
      'proposedPrice': proposedPrice,
      'etaMinutes': etaMinutes,
    });
  }

  void acceptBid({
    required String rideId,
    required String bidId,
  }) {
    send({
      'type': 'ACCEPT_BID',
      'rideId': rideId,
      'bidId': bidId,
    });
  }

  void updateRideStatus({
    required String rideId,
    required String status,
  }) {
    send({
      'type': 'UPDATE_RIDE_STATUS',
      'rideId': rideId,
      'status': status,
    });
  }

  void updateDriverLocation({
    required double latitude,
    required double longitude,
  }) {
    send({
      'type': 'DRIVER_LOCATION_UPDATE',
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // ==========================================
  // REST API: GEOCODING, ORDERS & REVIEWS
  // ==========================================

  /// Live Address Autocomplete Search (OSM Nominatim Proxy)
  Future<List<AddressSearchResult>> searchAddresses(String query) async {
    try {
      final res = await http.get(Uri.parse('$httpUrl/api/geo/search?q=${Uri.encodeComponent(query)}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['results'] as List<dynamic>? ?? []);
        return list.map((item) => AddressSearchResult.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[API] searchAddresses error: $e');
    }
    return [];
  }

  /// True road routing via OSRM
  Future<Map<String, dynamic>?> estimateRoute(
    Map<String, dynamic> pickup,
    Map<String, dynamic> destination,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$httpUrl/api/routes/estimate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pickup': pickup, 'destination': destination}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[API] estimateRoute error: $e');
    }
    return null;
  }

  /// Live available orders feed for drivers
  Future<List<Map<String, dynamic>>> fetchActiveOrders() async {
    try {
      final res = await http.get(Uri.parse('$httpUrl/api/rides/active'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['orders'] as List<dynamic>? ?? []);
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('[API] fetchActiveOrders error: $e');
    }
    return [];
  }

  /// Fetch Recent Trips History
  Future<List<Map<String, dynamic>>> fetchRideHistory(String role, String userId) async {
    try {
      final endpoint = role == 'DRIVER'
          ? '$httpUrl/api/rides/history/driver/$userId'
          : '$httpUrl/api/rides/history/rider/$userId';

      final res = await http.get(Uri.parse(endpoint));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['rides'] as List<dynamic>? ?? []);
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('[API] fetchRideHistory error: $e');
    }
    return [];
  }

  /// Submit Rider Rating & Comments
  Future<bool> submitRideReview({
    required String rideId,
    required String driverId,
    required String riderId,
    required String riderName,
    required int rating,
    String? comment,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$httpUrl/api/rides/$rideId/review'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': driverId,
          'riderId': riderId,
          'riderName': riderName,
          'rating': rating,
          'comment': comment ?? '',
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] submitRideReview error: $e');
      return false;
    }
  }

  /// Fetch driver reviews and rating screen
  Future<Map<String, dynamic>?> fetchDriverReviews(String driverId) async {
    try {
      final res = await http.get(Uri.parse('$httpUrl/api/drivers/$driverId/reviews'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[API] fetchDriverReviews error: $e');
    }
    return null;
  }

  /// Wallet APIs
  Future<Map<String, dynamic>?> fetchWallet(String driverId) async {
    try {
      final res = await http.get(Uri.parse('$httpUrl/api/wallet/$driverId'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['wallet'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[API] fetchWallet error: $e');
    }
    return null;
  }

  Future<bool> topUpWallet(String driverId, double amount) async {
    try {
      final res = await http.post(
        Uri.parse('$httpUrl/api/wallet/$driverId/topup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount, 'paymentMethod': 'Instant EFT'}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] topUp error: $e');
      return false;
    }
  }
}
