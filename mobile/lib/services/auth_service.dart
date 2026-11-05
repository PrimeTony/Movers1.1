import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'socket_service.dart';

class UserSession {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role; // 'RIDER' or 'DRIVER'
  final String token;
  final Map<String, dynamic>? profile;

  UserSession({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.token,
    this.profile,
  });

  factory UserSession.fromJson(Map<String, dynamic> json, String token) {
    return UserSession(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      token: token,
      profile: json['profile'] as Map<String, dynamic>?,
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String serverHost = '127.0.0.1:4000';
  static const String apiBase = 'http://$serverHost/api/auth';

  final ValueNotifier<UserSession?> sessionNotifier = ValueNotifier<UserSession?>(null);

  UserSession? get currentSession => sessionNotifier.value;
  bool get isAuthenticated => sessionNotifier.value != null;

  /// Sign In with phone & password
  Future<void> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$apiBase/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone.trim(),
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>?;

      final session = UserSession(
        id: userJson['id'] as String,
        name: userJson['name'] as String,
        phone: userJson['phone'] as String,
        email: userJson['email'] as String?,
        role: userJson['role'] as String,
        token: token,
        profile: profile,
      );

      sessionNotifier.value = session;

      // Connect socket automatically upon login
      SocketService().connect(
        userId: session.id,
        role: session.role,
        name: session.name,
      );
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Sign in failed';
      throw Exception(error);
    }
  }

  /// Register new user (Rider or Driver)
  Future<void> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? email,
    String? vehicleModel,
    String? vehiclePlate,
  }) async {
    final Map<String, dynamic> body = {
      'name': name.trim(),
      'phone': phone.trim(),
      'password': password,
      'role': role,
    };

    if (email != null && email.isNotEmpty) body['email'] = email.trim();
    if (role == 'DRIVER') {
      body['vehicleModel'] = vehicleModel?.trim() ?? 'Toyota Corolla';
      body['vehiclePlate'] = vehiclePlate?.trim() ?? 'GP 000-000';
    }

    final response = await http.post(
      Uri.parse('$apiBase/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;

      final session = UserSession(
        id: userJson['id'] as String,
        name: userJson['name'] as String,
        phone: userJson['phone'] as String,
        email: userJson['email'] as String?,
        role: userJson['role'] as String,
        token: token,
      );

      sessionNotifier.value = session;

      // Connect socket
      SocketService().connect(
        userId: session.id,
        role: session.role,
        name: session.name,
      );
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Registration failed';
      throw Exception(error);
    }
  }

  /// Quick Demo Sign-in for immediate development & testing
  Future<void> quickDemoLogin(String role) async {
    if (role == 'DRIVER') {
      // Use seeded demo driver
      final session = UserSession(
        id: 'driver_sipho',
        name: 'Sipho Zulu',
        phone: '+27821112222',
        role: 'DRIVER',
        token: 'demo_token_driver_sipho',
        profile: {
          'vehicle_model': 'Toyota Corolla (White)',
          'vehicle_plate': 'ND 842-192',
          'rating': 4.9,
          'completed_trips': 1420,
        },
      );
      sessionNotifier.value = session;
      SocketService().connect(userId: session.id, role: session.role, name: session.name);
    } else {
      // Rider
      final session = UserSession(
        id: 'rider_hulisani',
        name: 'Hulisani Mbedzi',
        phone: '+27829998888',
        role: 'RIDER',
        token: 'demo_token_rider_hulisani',
      );
      sessionNotifier.value = session;
      SocketService().connect(userId: session.id, role: session.role, name: session.name);
    }
  }

  /// Sign out current session
  void signOut() {
    SocketService().disconnect();
    sessionNotifier.value = null;
  }
}

