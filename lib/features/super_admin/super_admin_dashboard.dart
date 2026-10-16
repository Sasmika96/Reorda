import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../auth/auth_service.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0; // 0: Onboard Partner, 1: Master Catalog, 2: Registered Partners

  // Onboarding Form Controllers
  final _partnerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  
  String _selectedRole = 'hotel'; // 'hotel' or 'vendor'
  double _latitude = 6.927079;
  double _longitude = 79.861244;
  bool _isGeocodingLoading = false;
  bool _isCreatingPartner = false;

  // Master Catalog Item Dialog
  void _showAddMasterItemModal(BuildContext context) {
    final itemNameController = TextEditingController();
    final itemCategoryController = TextEditingController();
    final itemUnitController = TextEditingController(text: 'Kg');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Add Approved Master Catalog Item', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: itemNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Item Name (e.g. Basmati Rice)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: itemCategoryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g. Grains, Dairy)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: itemUnitController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Measurement Unit (e.g. Kg, Liter, Pack)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
              onPressed: () async {
                if (itemNameController.text.isNotEmpty && itemCategoryController.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('master_catalog').add({
                    'name': itemNameController.text.trim(),
                    'category': itemCategoryController.text.trim(),
                    'unit': itemUnitController.text.trim(),
                    'created_at': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Forward Geocoding
  Future<void> _getCoordinatesFromAddress() async {
    final query = '${_addressController.text.trim()}, ${_cityController.text.trim()}';
    if (query.trim() == ',') return;

    setState(() => _isGeocodingLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'ReordaAdminApp/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final firstResult = data.first;
          setState(() {
            _latitude = double.parse(firstResult['lat']);
            _longitude = double.parse(firstResult['lon']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting coordinates: $e');
    } finally {
      setState(() => _isGeocodingLoading = false);
    }
  }

  // Reverse Geocoding
  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    setState(() => _isGeocodingLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final response = await http.get(url, headers: {'User-Agent': 'ReordaAdminApp/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          String road = address['road'] ?? address['suburb'] ?? '';
          String city = address['city'] ?? address['town'] ?? address['state_district'] ?? '';
          setState(() {
            if (road.isNotEmpty) _addressController.text = road;
            if (city.isNotEmpty) _cityController.text = city;
          });
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    } finally {
      setState(() => _isGeocodingLoading = false);
    }
  }

  // Uber Style Map Modal for Pinning Location
  void _showUberStyleMapModal(BuildContext context) {
    LatLng tempCenter = LatLng(_latitude, _longitude);
    final MapController mapController = MapController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.pin_drop, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Pin Partner Warehouse / Gate Location', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Move map to set exact dispatch/receiving pin:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 320,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                initialCenter: tempCenter,
                                initialZoom: 15.0,
                                onPositionChanged: (position, hasGesture) {
                                  if (position.center != null) {
                                    setModalState(() {
                                      tempCenter = position.center!;
                                    });
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.reorda.app',
                                ),
                              ],
                            ),
                            const IgnorePointer(
                              child: Icon(Icons.location_on, color: Colors.redAccent, size: 48),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  onPressed: () async {
                    setState(() {
                      _latitude = tempCenter.latitude;
                      _longitude = tempCenter.longitude;
                    });
                    Navigator.pop(dialogContext);
                    await _getAddressFromCoordinates(_latitude, _longitude);
                  },
                  child: const Text('Confirm Pin', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Create Partner Account with Permanent Fix for hotel_id binding
  Future<void> _createPartnerAccount() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _partnerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isCreatingPartner = true);
    try {
      // 1. Unique secondary app name එකක් දීම මඟින් network/duplicate instance errors වළක්වා ගැනීම
      String secondaryAppName = 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}';
      
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options,
      );
      FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      UserCredential userCred = await tempAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCred.user!.uid;
      String partnerId = _selectedRole == 'hotel' ? 'hotel_$uid' : 'vendor_$uid';

      // 2. Save in Users collection
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'hotel_id': _selectedRole == 'hotel' ? partnerId : null,
        'vendor_id': _selectedRole == 'vendor' ? partnerId : null,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 3. Save detailed profile in hotels or vendors collection
      if (_selectedRole == 'hotel') {
        await FirebaseFirestore.instance.collection('hotels').doc(partnerId).set({
          'hotel_id': partnerId,
          'uid': uid,
          'hotel_name': _partnerNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'latitude': _latitude,
          'longitude': _longitude,
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('vendors').doc(partnerId).set({
          'vendor_id': partnerId,
          'uid': uid,
          'vendor_name': _partnerNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'latitude': _latitude,
          'longitude': _longitude,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await tempApp.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedRole.toUpperCase()} Account Created Successfully!'), backgroundColor: Colors.green),
        );
        _partnerNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _phoneController.clear();
        _addressController.clear();
        _cityController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isCreatingPartner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Text('Reorda ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('| Super Admin Control Center', style: TextStyle(fontSize: 14, color: Color(0xFF0EA5E9))),
          ],
        ),
        actions: [
          if (_selectedIndex == 1)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Add Approved Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddMasterItemModal(context),
            ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _authService.signOut(),
          )
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 260,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildNavItem(0, Icons.person_add_rounded, 'Onboard Hotel / Vendor'),
                _buildNavItem(1, Icons.playlist_add_check_rounded, 'Master Catalog Items'),
                _buildNavItem(2, Icons.store_mall_directory_rounded, 'Registered Partners'),
              ],
            ),
          ),
          Expanded(child: _buildBodyView()),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: const Color(0xFF0F172A),
      onTap: () => setState(() => _selectedIndex = index),
    );
  }

  Widget _buildBodyView() {
    switch (_selectedIndex) {
      case 0:
        return _buildOnboardTab();
      case 1:
        return _buildMasterCatalogTab();
      case 2:
        return _buildPartnersListTab();
      default:
        return _buildOnboardTab();
    }
  }

  Widget _buildOnboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Onboard New Partner (Hotel or Vendor)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Create login credentials, assign geolocation pin, and register partner into platform.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text('Select Partner Type: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('Hotel Partner'),
                selected: _selectedRole == 'hotel',
                selectedColor: const Color(0xFF0EA5E9),
                onSelected: (val) => setState(() => _selectedRole = 'hotel'),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Vendor Partner'),
                selected: _selectedRole == 'vendor',
                selectedColor: const Color(0xFF0EA5E9),
                onSelected: (val) => setState(() => _selectedRole = 'vendor'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _partnerNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '${_selectedRole == 'hotel' ? 'Hotel' : 'Vendor'} Business Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.store, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone Number',
                    labelStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.phone, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Login Email Address',
                    labelStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.email, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Temporary Password',
                    labelStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.lock, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Street Address',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF0EA5E9)),
                      onPressed: _getCoordinatesFromAddress,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'City / District',
                    labelStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.map, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_drop, color: Colors.redAccent, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location Pin Assigned', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Lat: ${_latitude.toStringAsFixed(5)} | Lng: ${_longitude.toStringAsFixed(5)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  icon: const Icon(Icons.map, color: Colors.white, size: 18),
                  label: const Text('Pick Exact Map Location', style: TextStyle(color: Colors.white)),
                  onPressed: () => _showUberStyleMapModal(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
              onPressed: _isCreatingPartner ? null : _createPartnerAccount,
              child: _isCreatingPartner
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Create & Register ${_selectedRole.toUpperCase()} Account', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterCatalogTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Catalog Approved Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Approved items list available for vendors to list in their catalog.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Approved Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddMasterItemModal(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('master_catalog').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No master catalog items added yet. Click "Add Approved Item" above.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF0EA5E9), child: Icon(Icons.inventory, color: Colors.white)),
                        title: Text(data['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('Category: ${data['category'] ?? ''} | Unit: ${data['unit'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => FirebaseFirestore.instance.collection('master_catalog').doc(docs[index].id).delete(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersListTab() {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registered Platform Partners', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            const TabBar(
              indicatorColor: Color(0xFF0EA5E9),
              labelColor: Color(0xFF0EA5E9),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Hotels'),
                Tab(text: 'Vendors'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('hotels').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text('No hotels registered yet.', style: TextStyle(color: Colors.grey)));
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return Card(
                            color: const Color(0xFF1E293B),
                            child: ListTile(
                              leading: const Icon(Icons.hotel, color: Color(0xFF0EA5E9)),
                              title: Text(data['hotel_name'] ?? 'Hotel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('City: ${data['city']} | Phone: ${data['phone']}', style: const TextStyle(color: Colors.grey)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('vendors').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text('No vendors registered yet.', style: TextStyle(color: Colors.grey)));
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return Card(
                            color: const Color(0xFF1E293B),
                            child: ListTile(
                              leading: const Icon(Icons.store, color: Color(0xFF0EA5E9)),
                              title: Text(data['vendor_name'] ?? 'Vendor', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('City: ${data['city']} | Phone: ${data['phone']}', style: const TextStyle(color: Colors.grey)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}