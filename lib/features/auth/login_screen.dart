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
  final _emailController = TextEditingController(text: 'hotel@reorda.net');
  final _passwordController = TextEditingController(text: '123456');
  final _pinController = TextEditingController(); // 👈 Driver 4-digit PIN එක සඳහා Controller එකක්
  String _selectedRole = 'hotel'; // hotel, vendor, driver, super_admin
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;

      // 🚚 1. DRIVER ROLE LOGIN LOGIC (Phone Number & 4-digit PIN Verification)
      if (_selectedRole == 'driver') {
        final inputPhone = _emailController.text.trim();
        final inputPin = _pinController.text.trim();

        if (inputPin.isEmpty || inputPin.length != 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please enter the 4-digit Delivery PIN provided during dispatch!'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Phone number එකෙන් Driver ව සෙවීම
        final driverQuery = await FirebaseFirestore.instance
            .collection('drivers')
            .where('phone', isEqualTo: inputPhone)
            .get();

        if (driverQuery.docs.isNotEmpty) {
          final doc = driverQuery.docs.first;
          final driverData = doc.data();
          final driverId = doc.id;
          driverData['id'] = driverId;

          // 🔥 2. Driver ට Assign වෙලා තියෙන (DISPATCHED ස්ටේටස් එකේ) ඕඩර් එකක් අතරින් මේ PIN එක තියෙනවද බැලීම
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
                  content: Text('✅ Successfully logged in as DRIVER with valid PIN!'),
                  backgroundColor: Colors.green,
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
                  content: Text('❌ Invalid 4-digit PIN or no active dispatch found for this PIN!'),
                  backgroundColor: Colors.redAccent,
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
                content: Text('❌ Driver not found with this Phone Number! Add driver in Vendor Portal first.'),
                backgroundColor: Colors.orangeAccent,
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
          SnackBar(content: Text('Login Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
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
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF0EA5E9), size: 32),
                  SizedBox(width: 12),
                  Text('REORDA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Smart Supply Chain Portal Access', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const Divider(color: Colors.grey, height: 32),

              // Role Selector Tabs
              const Text('Select Access Role:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRoleChip('hotel', 'Hotel Store', Icons.hotel),
                  _buildRoleChip('vendor', 'Vendor Partner', Icons.store),
                  _buildRoleChip('driver', 'Driver App', Icons.local_shipping),
                  _buildRoleChip('super_admin', 'Super Admin', Icons.admin_panel_settings),
                ],
              ),
              const SizedBox(height: 20),

              // 📱 Phone Number or Email Field
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: _selectedRole == 'driver' ? 'Registered Phone Number' : 'Email Address',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: Icon(_selectedRole == 'driver' ? Icons.phone : Icons.email_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // 🔐 Password Field (for Admin/Hotel/Vendor) OR 4-digit PIN Field (for Driver)
              if (_selectedRole == 'driver') ...[
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: false,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: 'Enter 4-Digit Delivery PIN',
                    hintText: '----',
                    hintStyle: const TextStyle(color: Colors.grey),
                    labelStyle: const TextStyle(color: Colors.orangeAccent),
                    prefixIcon: const Icon(Icons.vpn_key, color: Colors.orangeAccent),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole == 'driver' ? Colors.orangeAccent : const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedRole == 'driver' ? 'Login to Driver Portal with PIN' : 'Login to ${_selectedRole.toUpperCase()} Portal',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: const Color(0xFF0F172A),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRole = role;
            if (role == 'vendor') {
              _emailController.text = 'vendor@lankaagro.com';
            } else if (role == 'hotel') {
              _emailController.text = 'hotel@reorda.net';
            } else if (role == 'driver') {
              _emailController.text = '0771234567'; // Driver phone default
              _pinController.text = ''; // Reset pin box
            } else {
              _emailController.text = 'admin@reorda.net';
            }
          });
        }
      },
    );
  }
}