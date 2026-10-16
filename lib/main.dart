import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 💡 .env සඳහා එකතු කරන ලදී
import 'features/auth/login_screen.dart';
import 'features/hotel/hotel_dashboard.dart';
import 'features/vendor/vendor_dashboard.dart';
import 'features/super_admin/super_admin_dashboard.dart';
import 'features/driver/driver_dashboard.dart'; // 👈 1. Driver Dashboard එක Import කරගන්න
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 💡 .env ෆයිල් එක ලෝඩ් කිරීම
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ReordaApp());
}

class ReordaApp extends StatelessWidget {
  const ReordaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reorda Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0EA5E9),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final role = userData['role'] ?? 'hotel';

                if (role == 'vendor') {
                  return VendorDashboardScreen(vendorId: user.uid);
                } else if (role == 'driver') {
                  // 👈 2. Driver Role එක සඳහා real DriverDashboardScreen එකක් return කිරීම
                  return DriverDashboardScreen(driverData: userData);
                } else if (role == 'super_admin') {
                  return const SuperAdminDashboardScreen();
                } else {
                  final hotelId = userData['hotel_id'] ?? 'hotel_${user.uid}';
                  return HotelDashboardScreen(hotelId: hotelId);
                }
              }

              return HotelDashboardScreen(hotelId: 'hotel_${user.uid}');
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}