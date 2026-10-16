import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Imports for Dashboard Screens
import '../vendor/vendor_dashboard.dart';
import '../driver/driver_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  
  String _selectedRole = 'hotel'; // hotel, vendor, driver, super_admin
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;

      // 🚚 1. DRIVER ROLE LOGIN LOGIC
      if (_selectedRole == 'driver') {
        final inputPhone = _emailController.text.trim();
        final inputPin = _pinController.text.trim();

        if (inputPhone.isEmpty || inputPin.isEmpty || inputPin.length != 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please enter a valid phone number and 4-digit PIN!'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final driverQuery = await FirebaseFirestore.instance
            .collection('drivers')
            .where('phone', isEqualTo: inputPhone)
            .get();

        if (driverQuery.docs.isNotEmpty) {
          final doc = driverQuery.docs.first;
          final driverData = doc.data();
          final driverId = doc.id;
          driverData['id'] = driverId;

          final orderQuery = await FirebaseFirestore.instance
              .collection('orders')
              .where('driver_id', isEqualTo: driverId)
              .where('status', isEqualTo: 'DISPATCHED')
              .where('delivery_pin', isEqualTo: inputPin)
              .get();

          if (orderQuery.docs.isNotEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Successfully logged in as DRIVER!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverDashboardScreen(driverData: driverData),
                ),
              );
            }
            return;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Invalid 4-digit PIN or no active dispatch found!'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Driver not found with this Phone Number!'),
                backgroundColor: Colors.orangeAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // 🔑 2. HOTEL / VENDOR / SUPER ADMIN AUTH LOGIC
      UserCredential userCredential;
      try {
        userCredential = await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } catch (e) {
        userCredential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      String uid = userCredential.user!.uid;
      String email = _emailController.text.trim();

      String? actualHotelId;
      String? actualVendorId;

      if (_selectedRole == 'hotel') {
        final hotelQuery = await FirebaseFirestore.instance
            .collection('hotels')
            .where('email', isEqualTo: email)
            .get();

        if (hotelQuery.docs.isNotEmpty) {
          actualHotelId = hotelQuery.docs.first.id;
        } else {
          actualHotelId = 'hotel_$uid';
        }
      } else if (_selectedRole == 'vendor') {
        final vendorQuery = await FirebaseFirestore.instance
            .collection('vendors')
            .where('email', isEqualTo: email)
            .get();

        if (vendorQuery.docs.isNotEmpty) {
          actualVendorId = vendorQuery.docs.first.id;
        } else {
          actualVendorId = 'vendor_$uid';
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'role': _selectedRole,
        'hotel_id': actualHotelId,
        'vendor_id': actualVendorId,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully logged in as ${_selectedRole.toUpperCase()}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (_selectedRole == 'vendor' && actualVendorId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VendorDashboardScreen(vendorId: actualVendorId!),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Error: ${e.toString()}'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 440,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hub_rounded, color: Color(0xFF0EA5E9), size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'REORDA',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Smart B2B Supply Chain Portal',
                        style: TextStyle(fontSize: 13, color: Colors.grey), // 👈 දෝෂය ඉවත් කරන ලදී
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 24),

                // Role Selector Tabs
                const Text('Select Portal Access:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildRoleChip('hotel', 'Hotel Store', Icons.hotel),
                      _buildRoleChip('vendor', 'Vendor Partner', Icons.store),
                      _buildRoleChip('driver', 'Driver App', Icons.local_shipping),
                      _buildRoleChip('super_admin', 'Super Admin', Icons.admin_panel_settings),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 📱 Phone Number or Email Field
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _selectedRole == 'driver' ? 'Registered Phone Number' : 'Email Address',
                    hintText: _selectedRole == 'driver' ? 'e.g. 0771234567' : 'e.g. user@reorda.net',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: Icon(_selectedRole == 'driver' ? Icons.phone_outlined : Icons.email_outlined, color: const Color(0xFF0EA5E9)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 🔐 Password Field OR 4-digit PIN Field
                if (_selectedRole == 'driver') ...[
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: false,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, letterSpacing: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: '4-Digit Delivery PIN',
                      hintText: '----',
                      counterText: '',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      labelStyle: const TextStyle(color: Colors.orangeAccent),
                      prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.orangeAccent),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                      ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your secure password',
                      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0EA5E9)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedRole == 'driver' ? Colors.orangeAccent : const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _selectedRole == 'driver' ? 'Verify PIN & Enter Driver Portal' : 'Login to ${_selectedRole.toUpperCase().replaceAll('_', ' ')} Portal',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
      selected: isSelected,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: const Color(0xFF0F172A),
      elevation: isSelected ? 2 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF334155),
          width: 1,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRole = role;
            _emailController.clear();
            _passwordController.clear();
            _pinController.clear();
          });
        }
      },
    );
  }
}