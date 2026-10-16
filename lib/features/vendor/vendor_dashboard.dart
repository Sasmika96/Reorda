import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../hotel/purchase_order.dart';
import 'vendor_invoice.dart';
import 'vendor_service.dart';

class VendorDashboardScreen extends StatefulWidget {
  final String vendorId;
  const VendorDashboardScreen({super.key, required this.vendorId});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  late final VendorService _vendorService;
  final AuthService _authService = AuthService();
  int _selectedNavIndex = 0;
String _invoiceSearchQuery = '';
  DateTime? _selectedInvoiceDate;
  // Form Controllers
  final _vendorNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();

  double _latitude = 6.927079;
  double _longitude = 79.861244;
  bool _isGeocodingLoading = false;
  bool _isSavingLocation = false;

  @override
  void initState() {
    super.initState();
    _vendorService = VendorService(vendorId: widget.vendorId);
    _loadVendorProfileData();
  }

  Future<void> _loadVendorProfileData() async {
    try {
      String targetId = widget.vendorId.startsWith('vendor_') 
          ? widget.vendorId 
          : 'vendor_${widget.vendorId}';

      final doc = await FirebaseFirestore.instance.collection('vendors').doc(targetId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _vendorNameController.text = data['vendor_name'] ?? data['company_name'] ?? '';
          _addressController.text = data['address'] ?? data['warehouse_address'] ?? '';
          _cityController.text = data['city'] ?? '';
          _phoneController.text = data['phone'] ?? data['contact_phone'] ?? '';
          if (data['latitude'] != null && data['longitude'] != null) {
            _latitude = (data['latitude'] as num).toDouble();
            _longitude = (data['longitude'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor profile: $e');
    }
  }

  Future<void> _saveVendorLocationSettings() async {
    setState(() => _isSavingLocation = true);
    try {
      await _vendorService.updateVendorProfile(
        companyName: _vendorNameController.text,
        warehouseAddress: _addressController.text.trim(),
        city: _cityController.text.trim(),
        contactPhone: _phoneController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('vendors').doc(_vendorService.formattedVendorId).set({
        'latitude': _latitude,
        'longitude': _longitude,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor Warehouse Location & Details Saved Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSavingLocation = false);
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    setState(() => _isGeocodingLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final response = await http.get(url, headers: {'User-Agent': 'ReordaVendorApp/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          String road = address['road'] ?? address['pedestrian'] ?? address['suburb'] ?? '';
          String city = address['city'] ?? address['town'] ?? address['village'] ?? address['state_district'] ?? '';
          
          setState(() {
            if (road.isNotEmpty) _addressController.text = road;
            if (city.isNotEmpty) _cityController.text = city;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    } finally {
      setState(() => _isGeocodingLoading = false);
    }
  }

  Future<void> _getCoordinatesFromAddress() async {
    final query = '${_addressController.text.trim()}, ${_cityController.text.trim()}';
    if (query.trim() == ',') return;

    setState(() => _isGeocodingLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'ReordaVendorApp/1.0'});

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
                  Text('Set Vendor Warehouse Location Pin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Move map to set exact warehouse dispatch pin:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 350,
                        width: double.infinity,
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF0EA5E9), width: 1.5)),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, color: Colors.redAccent, size: 48),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  'Lat: ${tempCenter.latitude.toStringAsFixed(6)} | Lng: ${tempCenter.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text('Confirm Location Pin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    setState(() {
                      _latitude = tempCenter.latitude;
                      _longitude = tempCenter.longitude;
                    });
                    Navigator.pop(dialogContext);
                    await _getAddressFromCoordinates(_latitude, _longitude);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddVendorItemModal(BuildContext context) {
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '100');
    String? selectedItemName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Add Product from Master Catalog', style: TextStyle(color: Colors.white)),
              content: StreamBuilder<List<Map<String, String>>>(
                stream: _vendorService.getMasterCatalogStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
                    );
                  }

                  final masterCatalog = snapshot.data ?? [];

                  if (masterCatalog.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No Master Catalog items found. Please contact Super Admin.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  selectedItemName ??= masterCatalog.first['name'];

                  final selectedMasterItem = masterCatalog.firstWhere(
                    (item) => item['name'] == selectedItemName,
                    orElse: () => masterCatalog.first,
                  );

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedItemName,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Select Approved Item Name',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: masterCatalog.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['name'],
                              child: Text('${item['name']} (${item['category']})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedItemName = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Unit Price (LKR)',
                            labelStyle: const TextStyle(color: Colors.grey),
                            suffixText: '/ ${selectedMasterItem['unit'] ?? ''}',
                            suffixStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Available Vendor Stock (${selectedMasterItem['unit'] ?? ''})',
                            labelStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  onPressed: () async {
                    if (selectedItemName != null && priceController.text.isNotEmpty) {
                      final snapshot = await _vendorService.getMasterCatalogStream().first;
                      final chosen = snapshot.firstWhere((i) => i['name'] == selectedItemName);

                      await _vendorService.addVendorItem(
                        name: chosen['name']!,
                        category: chosen['category']!,
                        unitPrice: double.tryParse(priceController.text) ?? 0,
                        unit: chosen['unit']!,
                        stockQty: double.tryParse(qtyController.text) ?? 0,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 🚚 ADDED: Add Driver Modal ---
  void _showAddDriverModal(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final vehicleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Add New Driver', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Driver Name', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Vehicle Number (e.g., WP-CAB-1234)', labelStyle: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
              onPressed: () async {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  await _vendorService.addDriver(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    vehicleNumber: vehicleController.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- 🚚 ADDED: Dispatch Modal with Driver Dropdown ---
  void _showDispatchModal(BuildContext context, PurchaseOrder order) {
    String? selectedDriverId;
    String? selectedDriverName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Assign Driver & Dispatch Order', style: TextStyle(color: Colors.white)),
              content: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _vendorService.getDriversStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
                    );
                  }

                  final drivers = snapshot.data ?? [];

                  if (drivers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No drivers available! Please add drivers in "Drivers & Tracking" tab first.',
                        style: TextStyle(color: Colors.orangeAccent),
                      ),
                    );
                  }

                  selectedDriverId ??= drivers.first['id'];
                  selectedDriverName ??= drivers.first['name'];

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item: ${order.itemName} (${order.quantity} ${order.unit})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text('Select Delivery Driver:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedDriverId,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: drivers.map((driver) {
                          return DropdownMenuItem<String>(
                            value: driver['id'],
                            child: Text('${driver['name']} (${driver['vehicle_number']})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final chosen = drivers.firstWhere((d) => d['id'] == val);
                            setModalState(() {
                              selectedDriverId = val;
                              selectedDriverName = chosen['name'];
                            });
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),






                ElevatedButton.icon(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orangeAccent,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  icon: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
  label: const Text(
    'Confirm & Dispatch',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  onPressed: () async {
    if (selectedDriverId != null && selectedDriverName != null) {
      
      // 👈 මෙතැනදී dispatchOrder කියන නිවැරදි නම පාවිච්චි කිරීම
      final String generatedPin = await _vendorService.dispatchOrder(
        orderId: order.id,
        driverId: selectedDriverId!,
        driverName: selectedDriverName!,
      );

      if (context.mounted) {
        Navigator.pop(context); // මොඩල් එක වැසීම

        // PIN එක පෙන්වන Pop-up ඩයලග් එක
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key, color: Colors.orangeAccent, size: 26),
                    SizedBox(width: 10),
                    Text('Dispatch Successful!', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Order successfully dispatched! Here is the Secure Delivery PIN:',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent, width: 1.5),
                  ),
                  child: Text(
                    generatedPin,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Driver needs this PIN to complete the delivery verification.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select a driver first!'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  },
),





              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Text('Reorda ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('| Vendor Partner Portal (ID: ${widget.vendorId.length > 6 ? widget.vendorId.substring(0, 6) : widget.vendorId}...)', style: const TextStyle(fontSize: 14, color: Color(0xFF0EA5E9))),
          ],
        ),
        actions: [
          if (_selectedNavIndex == 1)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddVendorItemModal(context),
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
            width: 240,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildNavItem(0, Icons.location_on_rounded, 'Warehouse Location'),
                _buildNavItem(1, Icons.inventory_2_outlined, 'My Products / Catalog'),
                _buildNavItem(2, Icons.shopping_bag_outlined, 'Incoming Orders'),
                _buildNavItem(3, Icons.receipt_long_outlined, 'Auto Invoices'),
                _buildNavItem(4, Icons.group_outlined, 'Drivers & Tracking'),
              ],
            ),
          ),
          Expanded(child: _buildBodyView()),
        ],
      ),
    );
  }

  Widget _buildBodyView() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildWarehouseLocationTab();
      case 1:
        return _buildCatalogTab();
      case 2:
        return _buildOrdersTab();
      case 3:
        return _buildInvoicesTab(widget.vendorId);
      case 4:
        return _buildDriversTab();
      default:
        return _buildWarehouseLocationTab();
    }
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isSelected = _selectedNavIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: const Color(0xFF0F172A),
      onTap: () => setState(() => _selectedNavIndex = index),
    );
  }

  Widget _buildWarehouseLocationTab() {
    final pinnedLocation = LatLng(_latitude, _longitude);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vendor Warehouse Location & Map Pin Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Pinpoint your warehouse dispatch location on Map or type street address to sync automatically.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),

          TextField(
            controller: _vendorNameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Registered Vendor Name',
              labelStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.store, color: Color(0xFF0EA5E9)),
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
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
                  onSubmitted: (_) => _getCoordinatesFromAddress(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'City / District',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.map, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF0EA5E9)),
                      onPressed: _getCoordinatesFromAddress,
                    ),
                  ),
                  onSubmitted: (_) => _getCoordinatesFromAddress(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Dispatch Manager / Warehouse Phone Number',
              labelStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.phone, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Warehouse Pin Location:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop, color: Colors.redAccent, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dispatch Warehouse Pin Point Set', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Lat: ${_latitude.toStringAsFixed(6)} | Lng: ${_longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                        icon: const Icon(Icons.my_location, color: Colors.white, size: 18),
                        label: const Text('Pick Exact Map Location / Pin Gate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () => _showUberStyleMapModal(context),
                      )
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: FlutterMap(
                      key: ValueKey('$_latitude-$_longitude'),
                      options: MapOptions(
                        initialCenter: pinnedLocation,
                        initialZoom: 15.0,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.reorda.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pinnedLocation,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isSavingLocation
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSavingLocation ? 'Saving Details...' : 'Save Location & Map Pin Settings',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: _isSavingLocation ? null : _saveVendorLocationSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTab() {
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
                  Text('My Product Catalog & Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Set unit prices and stock levels for items approved by Super Admin.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddVendorItemModal(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<VendorItem>>(
              stream: _vendorService.getVendorCatalog(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return const Center(child: Text('No products in catalog. Click "Add Product" to select from master catalog.', style: TextStyle(color: Colors.grey)));
                }

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product Name', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Category', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Unit Price', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Vendor Stock', style: TextStyle(color: Colors.white))),
                        DataColumn(label: Text('Action', style: TextStyle(color: Colors.white))),
                      ],
                      rows: items.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(item.category, style: const TextStyle(color: Colors.grey))),
                          DataCell(Text('Rs. ${item.unitPrice.toStringAsFixed(2)} / ${item.unit}', style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold))),
                          DataCell(Text('${item.stockQty} ${item.unit}', style: const TextStyle(color: Colors.white))),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _vendorService.deleteVendorItem(item.id),
                            ),
                          ),
                        ]);
                      }).toList(),
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

  // --- 🚚 FIXED: Incoming Orders Tab with Dispatch Button & Driver Modal ---
  // --- Incoming Orders Tab ---
  // --- Incoming Orders Tab ---
  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hotel Purchase Orders (Live Stream)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Real-time order feed dispatched from registered hotels.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<PurchaseOrder>>(
              stream: _vendorService.getIncomingOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0EA5E9),
                    ),
                  );
                }

                final rawOrders = snapshot.data ?? [];

                // 🔥 DELIVERED වුණු ඕඩර්ස් පමණක් ලිස්ට් එකෙන් ඉවත් කිරීම (ප්‍රශ්න මඟහරවා ගැනීමට)
                final activeOrders = rawOrders
                    .where((order) => order.status != 'DELIVERED')
                    .toList();

                if (activeOrders.isEmpty) {
                  return const Center(
                    child: Text(
                      'No incoming purchase orders yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: activeOrders.length,
                  itemBuilder: (context, index) {
                    final order = activeOrders[index];
                    final String status = order.status;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order.itemName} (${order.quantity} ${order.unit})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: $status',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (status == 'PENDING')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(order.id)
                                    .update({
                                  'status': 'ACCEPTED',
                                  'accepted_at':
                                      DateTime.now().toIso8601String(),
                                });
                              },
                              child: const Text(
                                'Accept Order',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          if (status == 'ACCEPTED')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                              ),
                              icon: const Icon(
                                Icons.local_shipping,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Dispatch',
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () =>
                                  _showDispatchModal(context, order),
                            ),
                          if (status == 'DISPATCHED')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'DISPATCHED',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Placeholder for Invoices Tab ---
  Widget _buildInvoicesTab(String vendorId) {
    final cleanVendorId = vendorId.contains('vendor_') 
        ? vendorId.replaceAll('vendor_', '') 
        : vendorId;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Auto Generated Invoices',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Invoices automatically generated upon successful order deliveries.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          
          // Search & Date Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by item name or order ID...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => setState(() => _invoiceSearchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Colors.white10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                label: Text(
                  _selectedInvoiceDate == null 
                      ? 'Filter by Date' 
                      : '${_selectedInvoiceDate!.year}-${_selectedInvoiceDate!.month.toString().padLeft(2, '0')}-${_selectedInvoiceDate!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedInvoiceDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedInvoiceDate = picked);
                },
              ),
              if (_selectedInvoiceDate != null || _invoiceSearchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    _selectedInvoiceDate = null;
                    _invoiceSearchQuery = '';
                  }),
                ),
              ]
            ],
          ),
          const SizedBox(height: 20),

          // Invoices List Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vendor_invoices')
                  .where('vendor_id', whereIn: [cleanVendorId, 'vendor_$cleanVendorId'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading invoices: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No invoices generated yet.', style: TextStyle(color: Colors.grey, fontSize: 15)));
                }

                var invoices = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                if (_invoiceSearchQuery.isNotEmpty) {
                  invoices = invoices.where((inv) {
                    final item = (inv['item_name'] ?? '').toString().toLowerCase();
                    final order = (inv['order_id'] ?? '').toString().toLowerCase();
                    return item.contains(_invoiceSearchQuery) || order.contains(_invoiceSearchQuery);
                  }).toList();
                }

                if (_selectedInvoiceDate != null) {
                  final dateStr = '${_selectedInvoiceDate!.year}-${_selectedInvoiceDate!.month.toString().padLeft(2, '0')}-${_selectedInvoiceDate!.day.toString().padLeft(2, '0')}';
                  invoices = invoices.where((inv) {
                    final issued = (inv['issued_date'] ?? '').toString();
                    return issued.startsWith(dateStr);
                  }).toList();
                }

                if (invoices.isEmpty) {
                  return const Center(child: Text('No invoices match the selected filters.', style: TextStyle(color: Colors.grey, fontSize: 15)));
                }

                return ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    final itemName = invoice['item_name'] ?? 'Unknown Item';
                    final qty = invoice['quantity'] ?? 0;
                    final unit = invoice['unit'] ?? '';
                    final orderId = invoice['order_id'] ?? 'N/A';
                    final issuedDate = invoice['issued_date'] ?? '';

                    return InkWell(
                      onTap: () => _showInvoiceDetailsDialog(context, invoice),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$itemName ($qty $unit)',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Order ID: $orderId | Date: ${issuedDate.toString().split('T').first}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.15),
                                foregroundColor: Colors.green,
                                side: BorderSide(color: Colors.green.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _showInvoiceDetailsDialog(context, invoice),
                              child: const Text('DELIVERED & INVOICED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
void _showInvoiceDetailsDialog(BuildContext context, Map<String, dynamic> invoice) {
    final itemName = invoice['item_name'] ?? 'Unknown Item';
    final qty = invoice['quantity'] ?? 0;
    final unit = invoice['unit'] ?? '';
    final unitPrice = invoice['unit_price'] ?? 0;
    final totalAmount = invoice['total_amount'] ?? (qty * unitPrice);
    final orderId = invoice['order_id'] ?? 'N/A';
    final hotelId = invoice['hotel_id'] ?? 'N/A';
    final vendorName = invoice['vendor_name'] ?? 'Authorized Vendor';
    final issuedDate = invoice['issued_date'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Invoice Summary Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.of(dialogContext).pop()),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('STATUS: DELIVERED & INVOICED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Vendor Name:', vendorName),
                  _buildDetailRow('Order ID:', orderId),
                  _buildDetailRow('Hotel ID:', hotelId),
                  _buildDetailRow('Issued Date:', issuedDate.toString().split('T').first),
                  const Divider(color: Colors.white24, height: 24),
                  _buildDetailRow('Item Name:', itemName),
                  _buildDetailRow('Quantity Delivered:', '$qty $unit'),
                  _buildDetailRow('Unit Price:', 'LKR $unitPrice'),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('LKR $totalAmount', style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close', style: TextStyle(color: Colors.grey))),
          ],
        );
      },
    );
  }

  

Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  // --- 🚚 ADDED: Drivers & Tracking Tab View ---
  Widget _buildDriversTab() {
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
                  Text('My Delivery Drivers & Live Tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Manage your drivers and track their live dispatch locations.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                label: const Text('Add Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddDriverModal(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _vendorService.getDriversStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }

                final drivers = snapshot.data ?? [];

                if (drivers.isEmpty) {
                  return const Center(child: Text('No drivers added yet. Click "Add Driver" to register.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_rounded, color: Color(0xFF0EA5E9), size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Phone: ${driver['phone']} | Vehicle: ${driver['vehicle_number']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: driver['status'] == 'AVAILABLE' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              driver['status'] ?? 'AVAILABLE',
                              style: TextStyle(
                                color: driver['status'] == 'AVAILABLE' ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}