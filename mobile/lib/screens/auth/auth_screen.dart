import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  String _selectedRole = 'RIDER'; // 'RIDER' or 'DRIVER'
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = AuthService();
      if (_isSignUp) {
        if (_nameController.text.trim().isEmpty) {
          throw Exception('Please enter your full name');
        }
        if (_phoneController.text.trim().isEmpty) {
          throw Exception('Please enter your phone number');
        }
        if (_passwordController.text.length < 6) {
          throw Exception('Password must be at least 6 characters');
        }
        if (_selectedRole == 'DRIVER') {
          if (_vehicleModelController.text.trim().isEmpty || _vehiclePlateController.text.trim().isEmpty) {
            throw Exception('Driver requires vehicle model and number plate');
          }
        }

        await auth.register(
          name: _nameController.text,
          phone: _phoneController.text,
          password: _passwordController.text,
          role: _selectedRole,
          vehicleModel: _selectedRole == 'DRIVER' ? _vehicleModelController.text : null,
          vehiclePlate: _selectedRole == 'DRIVER' ? _vehiclePlateController.text : null,
        );
      } else {
        if (_phoneController.text.trim().isEmpty || _passwordController.text.isEmpty) {
          throw Exception('Please enter phone and password');
        }
        await auth.login(
          _phoneController.text,
          _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleQuickDemo(String role) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService().quickDemoLogin(role);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. App Header / Branding
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.accentLime.withOpacity(0.5), width: 1.5),
                    ),
                    child: const Icon(Icons.near_me_rounded, color: AppTheme.accentLime, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MOVERS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Peer-to-peer fare negotiation with zero hidden commissions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Sign In vs Register Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isSignUp ? AppTheme.accentLime : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: !_isSignUp ? AppTheme.pureBlack : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isSignUp ? AppTheme.accentLime : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Register',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _isSignUp ? AppTheme.pureBlack : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Role Selector (if Registering)
                if (_isSignUp) ...[
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'RIDER'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'RIDER' ? AppTheme.surfaceDark : AppTheme.pureBlack,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedRole == 'RIDER' ? AppTheme.accentLime : AppTheme.borderSubtle,
                                width: _selectedRole == 'RIDER' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_pin_circle_rounded,
                                  color: _selectedRole == 'RIDER' ? AppTheme.accentLime : AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'I am a Rider',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _selectedRole == 'RIDER' ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'DRIVER'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'DRIVER' ? AppTheme.surfaceDark : AppTheme.pureBlack,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedRole == 'DRIVER' ? AppTheme.accentLime : AppTheme.borderSubtle,
                                width: _selectedRole == 'DRIVER' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_car_filled_rounded,
                                  color: _selectedRole == 'DRIVER' ? AppTheme.accentLime : AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'I am a Driver',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _selectedRole == 'DRIVER' ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Error Message Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form Fields
                if (_isSignUp) ...[
                  _buildInputField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'e.g. Kabelo Sithole',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                ],

                _buildInputField(
                  controller: _phoneController,
                  label: 'Mobile Number',
                  hint: '+27 82 123 4567',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 14),

                if (_isSignUp && _selectedRole == 'DRIVER') ...[
                  _buildInputField(
                    controller: _vehicleModelController,
                    label: 'Vehicle Make & Model',
                    hint: 'e.g. Toyota Corolla (Silver)',
                    icon: Icons.directions_car_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    controller: _vehiclePlateController,
                    label: 'License Plate',
                    hint: 'e.g. GP 882-101',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 10),

                // Submit Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentLime,
                      foregroundColor: AppTheme.pureBlack,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.pureBlack),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Quick Demo Switcher (Instant 1-Tap Login)
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppTheme.borderSubtle)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR QUICK DEV TEST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppTheme.borderSubtle)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _handleQuickDemo('RIDER'),
                        icon: const Icon(Icons.person_rounded, size: 18, color: AppTheme.accentLime),
                        label: const Text('Rider Demo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.borderSubtle),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _handleQuickDemo('DRIVER'),
                        icon: const Icon(Icons.directions_car_rounded, size: 18, color: AppTheme.accentLime),
                        label: const Text('Driver Demo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.borderSubtle),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 14),
              prefixIcon: Icon(icon, color: AppTheme.textTertiary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

