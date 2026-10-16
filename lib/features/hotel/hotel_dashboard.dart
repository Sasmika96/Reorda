import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import 'inventory_item.dart';
import 'inventory_service.dart';
import 'purchase_order.dart';
import 'gemini_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'inventory_alert_banner.dart';


class HotelDashboardScreen extends StatefulWidget {
  final String hotelId;
  const HotelDashboardScreen({super.key, required this.hotelId});

  @override
  State<HotelDashboardScreen> createState() => _HotelDashboardScreenState();
}

class _HotelDashboardScreenState extends State<HotelDashboardScreen> {
  late final InventoryService _inventoryService;
  final AuthService _authService = AuthService();
  String selectedCategory = 'All';
  String selectedItem = 'All';
  bool _showAlert = true;
  String _currentAlert = "";
  String _aiForecastText = 'AI Analyzing district consumption data & inventory thresholds...';
  bool _isLoadingAi = true;
  bool _isAiForecastFetched = false;
  bool _isAiDistrictFetched = false;
  String _aiDistrictTrendText = 'AI Analyzing regional consumption trends...';
  bool _isLoadingDistrictAi = true;

DateTime? selectedDate;
  int _selectedNavIndex = 0;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  // Hotel Profile Controllers
  final _hotelNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  double _latitude = 6.927079;
  double _longitude = 79.861244;
  bool _isProfileLoaded = false;
  bool _isGeocodingLoading = false;
  bool _isSavingProfile = false;

  @override
void initState() {
  super.initState();
  _inventoryService = InventoryService(hotelId: widget.hotelId);
  _loadHotelProfileData();
  
  // when app refresh API call
  _fetchAiForecastOnce();
  _fetchAiDistrictTrendOnce();
}

Future<void> _fetchAiForecastOnce() async {
  if (_isAiForecastFetched) return; // 💡 මෙතැන _isAiForecastFetched දාන්න
  
  setState(() {
    _isLoadingAi = true;
  });

  final result = await _getRealGeminiAiDemandForecast();

  if (mounted) {
    setState(() {
      _aiForecastText = result;
      _isLoadingAi = false;
      _currentAlert = result;
      _showAlert = true;
      _isAiForecastFetched = true; 
    });
  }
}



Future<void> _fetchAiDistrictTrendOnce() async {
  setState(() {
    _isLoadingDistrictAi = true;
  });

  try {
    final snapshot = await _inventoryService.getMasterItemsStream().first;
    if (snapshot.isEmpty) {
      if (mounted) {
        setState(() {
          _aiDistrictTrendText = 'AI Trend: Add inventory to view regional district consumption analytics.';
          _isLoadingDistrictAi = false;
          _currentAlert = _aiDistrictTrendText;
          _showAlert = true;
        });
      }
      return;
    }

    final itemsContext = snapshot.map((item) => 
      '• Item: ${item.name} | Category: ${item.category}'
    ).join('\n');

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _aiDistrictTrendText = 'AI Trend: Regional demand for hospitality supplies shows a 14% weekend surge.';
          _isLoadingDistrictAi = false;
          _currentAlert = _aiDistrictTrendText;
          _showAlert = true;
        });
      }
      return;
    }

    final model = GenerativeModel(
      model: 'gemini-3.8-flash',
      apiKey: apiKey,
    );

    
    final prompt = '''
      You are an advanced AI regional market and district consumption analyst for the hospitality sector.
      Based on these current inventory items in the hotel:
      $itemsContext

      Provide a short, professional AI insight report on regional district consumption trends or upcoming weekend hospitality demand spikes.
      Keep it strictly under 25 words, professional, and start it directly with "AI District Trend:". Do not use placeholders.
    ''';

    final response = await model.generateContent([Content.text(prompt)]);
    
    String resultText = 'AI District Trend: Regional hospitality consumption indicates high weekend demand for core inventory items.';
    if (response.text != null && response.text!.isNotEmpty) {
      resultText = response.text!.trim();
    }

    if (mounted) {
      setState(() {
        _aiDistrictTrendText = resultText;
        _isLoadingDistrictAi = false;
        _currentAlert = resultText;
        _showAlert = true;
      });
    }
  } catch (e) {
  print('District AI Error: $e');
  if (mounted) {
    setState(() {
      _isLoadingDistrictAi = false;
      _showAlert = false; 
    });
  }
}
}






// 🤖 Real Google Cloud Vertex AI / Gemini Demand Predictor Function
Future<String> _getRealGeminiAiDemandForecast() async {
  print('🚨 Single API Call triggered at: ${DateTime.now()}');

  try {
    final snapshot = await _inventoryService.getMasterItemsStream().first;
    if (snapshot.isEmpty) {
      return 'AI Forecast: Inventory catalog is empty. Add items to enable Vertex AI demand forecasting.';
    }
    
    final itemsContext = snapshot.map((item) => 
      '• Item: ${item.name} | Category: ${item.category}'
    ).join('\n');

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    
    if (apiKey.isEmpty) {
      return 'AI Forecast: GEMINI_API_KEY is missing. Using offline mode.';
    }

    final model = GenerativeModel(
      model: 'gemini-3.8-flash',
      apiKey: apiKey,
    );

    final prompt = '''
      You are an advanced AI supply chain and demand forecasting engine powered by Google Cloud Vertex AI.
      Analyze the following real-time hotel inventory catalog items:
      
      $itemsContext

      Based strictly on these catalog items, district consumption trends, and weekend demand spikes, provide a professional, data-driven demand forecast and recommend a specific stock buffer for the most critical item from the list.
      Keep the response concise, professional, under 30 words, and start it directly with "AI Forecast:". Do not use placeholders.
    ''';

    final response = await model.generateContent([Content.text(prompt)]);
    
    if (response.text != null && response.text!.isNotEmpty) {
      return response.text!.trim();
    }
    
    return 'AI Forecast: High weekend spike predicted. Reorder stock threshold recommended at +15% for critical items.';

  } catch (e) {
    print('Gemini API Error: $e');
    
    return 'AI Forecast: High weekend spike predicted. Reorder stock threshold recommended at +15% for critical items.';
  }
}







  Future<void> _loadHotelProfileData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('hotels').doc(widget.hotelId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _hotelNameController.text = data['hotel_name'] ?? '';
          _addressController.text = data['address'] ?? '';
          _cityController.text = data['city'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          if (data['latitude'] != null && data['longitude'] != null) {
            _latitude = (data['latitude'] as num).toDouble();
            _longitude = (data['longitude'] as num).toDouble();
          }
          _isProfileLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading hotel profile: $e');
    }
  }

  Future<void> _saveHotelProfileData() async {
    setState(() => _isSavingProfile = true);
    try {
      await FirebaseFirestore.instance.collection('hotels').doc(widget.hotelId).set({
        'hotel_name': _hotelNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'phone': _phoneController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotel Profile & Location Updated Successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    setState(() => _isGeocodingLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final response = await http.get(url, headers: {'User-Agent': 'ReordaHotelApp/1.0'});

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
      final response = await http.get(url, headers: {'User-Agent': 'ReordaHotelApp/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final firstResult = data.first;
          final lat = double.parse(firstResult['lat']);
          final lon = double.parse(firstResult['lon']);

          setState(() {
            _latitude = lat;
            _longitude = lon;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address location updated on Map!'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting coordinates: $e');
    } finally {
      setState(() => _isGeocodingLoading = false);
    }
  }

  void _showAddItemModal(BuildContext context) {
    final initialStockController = TextEditingController(text: '50');
    final limitController = TextEditingController(text: '15');
    DateTime? selectedExpiryDate;
    String? selectedItemName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Add Item to Hotel Inventory', style: TextStyle(color: Colors.white)),
              content: StreamBuilder<List<MasterItem>>(
                stream: _inventoryService.getMasterItemsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
                    );
                  }

                  final masterItems = snapshot.data ?? [];

                  if (masterItems.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No Master Catalog items found. Please contact Super Admin.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  selectedItemName ??= masterItems.first.name;

                  final selectedItem = masterItems.firstWhere(
                    (item) => item.name == selectedItemName,
                    orElse: () => masterItems.first,
                  );

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedItemName,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Select Approved Item Name',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: masterItems.map((item) {
                            return DropdownMenuItem<String>(
                              value: item.name,
                              child: Text('${item.name} (${item.category}) - [${item.unit}]'),
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
                          controller: initialStockController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Initial Stock (${selectedItem.unit})',
                            labelStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: limitController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Re-order Alert Limit (${selectedItem.unit})',
                            labelStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              selectedExpiryDate == null 
                                  ? 'Expiry Date: Optional' 
                                  : 'Expiry: ${DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0EA5E9)),
                              label: const Text('Set Expiry', style: TextStyle(color: Color(0xFF0EA5E9))),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 1095)),
                                );
                                if (picked != null) {
                                  setModalState(() => selectedExpiryDate = picked);
                                }
                              },
                            )
                          ],
                        )
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
                    if (selectedItemName != null) {
                      final snapshot = await _inventoryService.getMasterItemsStream().first;
                      final chosenItem = snapshot.firstWhere((i) => i.name == selectedItemName);

                      await _inventoryService.addItemToInventory(
                        masterItem: chosenItem,
                        initialStock: double.tryParse(initialStockController.text) ?? 0,
                        reorderLimit: double.tryParse(limitController.text) ?? 0,
                        expiryDate: selectedExpiryDate,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Item', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showReleaseStockModal(BuildContext context, InventoryItem item) {
    final releaseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Release Stock (${item.name})', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Stock: ${item.currentStock} ${item.unit}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: releaseController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantity to Release (${item.unit})',
                  labelStyle: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () async {
                final qty = double.tryParse(releaseController.text) ?? 0;
                if (qty > 0) {
                  await _inventoryService.releaseStock(item.id, qty);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Deduct Stock', style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  void _showDriverQRModal(BuildContext context, PurchaseOrder order) {
    final qrData = 'REORDA_PO_VERIFY:${order.id}:${order.hotelId}:${order.itemName}:${order.quantity}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: Color(0xFF0EA5E9), size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Driver Gate Verification (${order.itemName})',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(modalContext),
                  )
                ],
              ),
              const Divider(color: Colors.grey, height: 24),
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
              
              const SizedBox(height: 20),
              Text(
                'Order Details: ${order.quantity} ${order.unit} - ${order.itemName}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Vendor: ${order.vendorName}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚡ Driver scans this QR code at Hotel Gate to complete delivery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'Simulate Driver Scan & Complete Delivery',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await _inventoryService.completeRestockOrder(
                      orderId: order.id,
                      itemName: order.itemName,
                      quantity: order.quantity,
                    );
                    
                    if (modalContext.mounted) {
                      Navigator.pop(modalContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delivery completed! Stock for ${order.itemName} updated & moved to Reports.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAIForecastModal(BuildContext context, InventoryItem item) {
    final geminiService = GeminiService();

    //final double calculatedQty = (item.threshold - item.currentStock) > 0
     //   ? (item.threshold - item.currentStock)
     //   : item.threshold;
     final double calculatedQty = item.threshold * 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: FutureBuilder<String>(
            future: geminiService.generateDemandForecast(item),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                        SizedBox(height: 16),
                        Text('Reorda AI Analyzing Demand & Vendor Options...', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Text('Reorda AI Recommendation (${item.name})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.grey, height: 24),
                    Text(snapshot.data ?? 'No insight generated.', style: const TextStyle(color: Colors.white, height: 1.5)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final bool isSuccess = await _inventoryService.createPurchaseOrder(
                            itemName: item.name,
                            category: item.category,
                            quantity: calculatedQty > 0 ? calculatedQty : 50.0,
                            unit: item.unit,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            
                            if (isSuccess) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ PO for ${item.name} (${calculatedQty.toInt()} ${item.unit}) routed to nearest Vendor!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ No nearby Vendor found with sufficient stock for ${item.name}!'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Confirm & Dispatch Auto PO (${calculatedQty.toInt()} ${item.unit})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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
                  Text('Set Hotel Gate Location Pin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Move map to set exact location pin point for receiving gate:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 350,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF0EA5E9), width: 1.5),
                        ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
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

  Widget _buildFilterHeader(List<InventoryItem> items) {
    final categories = ['All', ...items.map((e) => e.category).toSet()];

    return Row(
      children: [
        Expanded(
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search items by name...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            value: _selectedCategoryFilter,
            dropdownColor: const Color(0xFF0F172A),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) => setState(() => _selectedCategoryFilter = val ?? 'All'),
          ),
        ),
      ],
    );
  }

  List<InventoryItem> _getFilteredItems(List<InventoryItem> items) {
    return items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategoryFilter == 'All' || item.category == _selectedCategoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
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
            Text('| Hotel Store Portal (ID: ${widget.hotelId.length > 8 ? widget.hotelId.substring(0, 8) : widget.hotelId}...)', style: const TextStyle(fontSize: 14, color: Color(0xFF0EA5E9))),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () => _showAddItemModal(context),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add Item', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _authService.signOut(),
          ),
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
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.inventory_2_outlined, 'Items'),
                _buildNavItem(2, Icons.local_shipping_outlined, 'Stock Release'),
                _buildNavItem(3, Icons.warning_amber_rounded, 'Near Expiry Alerts'),
                _buildNavItem(4, Icons.qr_code_scanner_rounded, 'Restock / Orders'),
                _buildNavItem(5, Icons.analytics_outlined, 'Reports & History'),
                _buildNavItem(6, Icons.map_rounded, 'Hotel Location & Map Pin'),
              ],
            ),
          ),
          
          




       Expanded(
  child: Column(
    children: [
 
      if (_showAlert && _aiDistrictTrendText.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: InventoryAlertBanner(
            message: _aiDistrictTrendText, 
            onClose: () {
              setState(() {
                _showAlert = false; 
              });
            },
          ),
        ),

      // 🤖 GOOGLE CLOUD VERTEX AI DEMAND PREDICTOR CARD
      Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology,
                color: Color(0xFF0EA5E9),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text(
                        'Google Cloud Vertex AI Demand Predictor',
                        style: TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _isLoadingAi 
  ? const Text(
      'AI Analyzing district consumption data & inventory thresholds...',
      style: TextStyle(color: Colors.white70, fontSize: 13),
    )
  : Text(
      _aiForecastText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        height: 1.3,
      ),
    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            onPressed: () {
  setState(() {
    _isAiForecastFetched = false; 
  });
  _fetchAiForecastOnce();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Refreshing Vertex AI Demand Forecast...'),
      backgroundColor: Colors.blue,
    ),
  );
},
              child: const Text(
                'Optimize Stock',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      // Main Content
      Expanded(child: _buildBodyView()),
    ],
  ),
)








        ],
      ),
    );
  }

  Widget _buildBodyView() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildItemsTab();
      case 2:
        return _buildStockReleaseTab();
      case 3:
        return _buildNearExpiryTab();
      case 4:
        return _buildRestockOrdersTab();
      case 5:
        return _buildReportsTab();
      case 6:
        return _buildLocationTab();
      default:
        return _buildDashboardTab();
    }
  }

 Widget _buildNavItem(int index, IconData icon, String title) {
  final isSelected = _selectedNavIndex == index;
  return Material( // 💡 මෙතැනට Material එකක් දාන්න
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: const Color(0xFF0F172A),
      onTap: () => setState(() => _selectedNavIndex = index),
    ),
  );
}

  // 1. Dashboard Tab with Active Order Button Disabling Logic
  Widget _buildDashboardTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Dashboard Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          StreamBuilder<List<InventoryItem>>(
            stream: _inventoryService.getInventoryItemsStream(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final lowStockItems = items.where((i) => i.currentStock <= i.threshold).toList();

              return Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Items', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Low Stock Alerts', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text('${lowStockItems.length}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Low Stock & Reorder Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _inventoryService.getInventoryItemsStream(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                final lowStockItems = items.where((i) => i.currentStock <= i.threshold).toList();

                if (lowStockItems.isEmpty) {
                  return const Center(child: Text('All inventory items are at healthy stock levels.', style: TextStyle(color: Colors.grey)));
                }

                return StreamBuilder<List<PurchaseOrder>>(
                  stream: _inventoryService.getHotelOrdersStream(),
                  builder: (context, ordersSnapshot) {
                    final activeOrders = ordersSnapshot.data ?? [];

                    return ListView.builder(
                      itemCount: lowStockItems.length,
                      itemBuilder: (context, index) {
                        final item = lowStockItems[index];

// Check if active order exists for this item (DELIVERED 
final hasActiveOrder = activeOrders.any((o) =>
  o.itemName.toLowerCase() == item.name.toLowerCase() &&
  o.status != 'DELIVERED' &&
  o.status != 'COMPLETED' &&
  (o.status == 'PENDING' || o.status == 'ACCEPTED' || o.status == 'DISPATCHED')
);

                        final activeOrder = hasActiveOrder
                            ? activeOrders.firstWhere((o) => o.itemName.toLowerCase() == item.name.toLowerCase())
                            : null;

                        return Container(
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: const Color(0xFF1E293B), 
    borderRadius: BorderRadius.circular(12),
  ),
  child: Material(
    color: Colors.transparent, 
    borderRadius: BorderRadius.circular(12),
    child: ListTile(
      leading: const Icon(Icons.warning, color: Colors.orange),
      title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text('Current Stock: ${item.currentStock} ${item.unit} (Threshold: ${item.threshold})', style: const TextStyle(color: Colors.grey)),
      trailing: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasActiveOrder ? Colors.grey.withOpacity(0.3) : const Color(0xFF0EA5E9),
        ),
        icon: Icon(
          hasActiveOrder ? Icons.hourglass_top_rounded : Icons.auto_awesome,
          size: 16,
          color: hasActiveOrder ? Colors.orangeAccent : Colors.white,
        ),
        label: Text(
          hasActiveOrder ? 'Order ${activeOrder?.status}' : 'AI Reorder',
          style: TextStyle(
            color: hasActiveOrder ? Colors.orangeAccent : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: hasActiveOrder ? null : () => _showAIForecastModal(context, item),
      ),
    ),
  ),
);
                      },
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




// ✏️ 1. Edit Item Modal Dialog
  void _showEditItemModal(BuildContext context, InventoryItem item) {
    final nameController = TextEditingController(text: item.name);
    final stockController = TextEditingController(text: item.currentStock.toString());
    final thresholdController = TextEditingController(text: item.threshold.toString());
    final unitController = TextEditingController(text: item.unit);
    final categoryController = TextEditingController(text: item.category);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Inventory Item', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Item Name', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Current Stock', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: thresholdController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Threshold', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: unitController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Unit (e.g. Kg, L, Pcs)', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.grey)),
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
              await FirebaseFirestore.instance
                  .collection('inventory_items')
                  .doc(item.id)
                  .update({
                'name': nameController.text.trim(),
                'currentStock': double.tryParse(stockController.text) ?? item.currentStock,
                'threshold': double.tryParse(thresholdController.text) ?? item.threshold,
                'unit': unitController.text.trim(),
                'category': categoryController.text.trim(),
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🗑️ 2. Delete Confirmation Dialog
  void _confirmDeleteItem(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${item.name}" from the inventory?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('inventory_items')
                  .doc(item.id)
                  .delete();

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

















  // 2. Items Tab
  // 2. Items Tab (Inventory Catalog)
  Widget _buildItemsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hotel Inventory Catalog',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _inventoryService.getInventoryItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No items in inventory. Click "Add Item".', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Stock: ${item.currentStock} ${item.unit} | Category: ${item.category}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          // 
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF0EA5E9)),
                                tooltip: 'Edit Item',
                                onPressed: () => _showEditItemModal(context, item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Delete Item',
                                onPressed: () => _confirmDeleteItem(context, item),
                              ),
                            ],
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

  // 3. Stock Release Tab
  Widget _buildStockReleaseTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hotel Inventory Catalog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _inventoryService.getInventoryItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('No items in inventory. Click "Add Item".', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Stock: ${item.currentStock} ${item.unit} | Category: ${item.category}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                            icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.white),
                            label: const Text('Release', style: TextStyle(color: Colors.white)),
                            onPressed: () => _showReleaseStockModal(context, item),
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

  // 4. Near Expiry Alerts Tab
  Widget _buildNearExpiryTab() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Center(
        child: Text('Near Expiry Alerts & Monitoring', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  // 5. Restock / Orders Tab
  Widget _buildRestockOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Restock Orders & Driver Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<PurchaseOrder>>(
              stream: _inventoryService.getHotelOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }

               
final orders = (snapshot.data ?? [])
    .where((order) => order.status.toUpperCase() != 'DELIVERED')
    .toList();
                if (orders.isEmpty) {
                  return const Center(child: Text('No active restock purchase orders.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping, color: Color(0xFF0EA5E9), size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${order.itemName} - ${order.quantity} ${order.unit}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Vendor: ${order.vendorName} | Status: ${order.status}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          order.status.toUpperCase() == 'DELIVERED'
    ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: const Text(
          '✓ Delivered',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      )
    : ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
        icon: const Icon(Icons.qr_code, size: 16, color: Colors.white),
        label: const Text('Show Driver QR', style: TextStyle(color: Colors.white)),
        onPressed: () => _showDriverQRModal(context, order),
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

  // 6. Reports Tab
// 6. Reports & Audit History Tab (Dynamic Categories from Super Admin)
  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports & Audit History', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
          ),
          const SizedBox(height: 16),

          // 🔍 DYNAMIC CATEGORY FILTER & DATE PICKER STREAM
          // 🔍 DYNAMIC COMBO BOX / SEARCHABLE FILTER & DATE PICKER STREAM
// 🔍 DYNAMIC CASCADING DROPDOWNS & DATE PICKER
StreamBuilder<List<MasterItem>>(
  stream: _inventoryService.getMasterItemsStream(),
  builder: (context, itemSnapshot) {
    final masterItems = itemSnapshot.hasData ? itemSnapshot.data! : [];


    Set<String> uniqueCategories = {'All'};
    for (var item in masterItems) {
      if (item.category.isNotEmpty) {
        uniqueCategories.add(item.category);
      }
    }
    final categoriesList = uniqueCategories.toList();

    if (!categoriesList.contains(selectedCategory)) {
      selectedCategory = 'All';
    }


    Set<String> uniqueItems = {'All'};
    for (var item in masterItems) {
      if (selectedCategory == 'All' || item.category == selectedCategory) {
        if (item.name.isNotEmpty) {
          uniqueItems.add(item.name);
        }
      }
    }
    final itemsList = uniqueItems.toList();

 
    if (!itemsList.contains(selectedItem)) {
      selectedItem = 'All';
    }

    

    return Row(
      children: [
        // 🔥 1. Main Category Dropdown
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCategory,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                isExpanded: true,
                items: categoriesList.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedCategory = val;
                      selectedItem = 'All'; 
                    });
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 🔥 2. Sub Item Dropdown (Dependent on Main Category)

Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        // State එක රීසෙට් වෙන්නේ නැතිව අගය ආරක්ෂා කරගැනීම
        value: itemsList.contains(selectedItem) ? selectedItem : 'All',
        dropdownColor: const Color(0xFF1E293B),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        isExpanded: true,
        items: itemsList.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              selectedItem = val; 
            });
          }
        },
      ),
    ),
  ),
),
        const SizedBox(width: 12),

        // Date Picker Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            side: const BorderSide(color: Colors.white12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0EA5E9)),
          label: Text(
            selectedDate == null 
                ? 'Select Date' 
                : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => selectedDate = picked);
            }
          },
        ),

        // Reset Filter Button
        if (selectedCategory != 'All' || selectedItem != 'All' || selectedDate != null)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.redAccent),
            tooltip: 'Reset Filters',
            onPressed: () {
              setState(() {
                selectedCategory = 'All';
                selectedItem = 'All';
                selectedDate = null;
              });
            },
          ),
      ],
    );
  },
),

          const SizedBox(height: 16),

          // 📊 HISTORY LIST SECTION
          Expanded(
            child: StreamBuilder<List<PurchaseOrder>>(
              stream: _inventoryService.getHotelOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                }

                final allOrders = snapshot.data ?? [];


                var filteredOrders = allOrders.where((order) => order.status.toUpperCase() == 'DELIVERED').toList();

    
                if (selectedCategory != 'All') {
                  filteredOrders = filteredOrders
                      .where((order) => (order.category ?? '').toLowerCase() == selectedCategory.toLowerCase())
                      .toList();
                }


                if (selectedItem != 'All') {
                  filteredOrders = filteredOrders
                      .where((order) => (order.itemName ?? '').toLowerCase() == selectedItem.toLowerCase())
                      .toList();
                }

                if (selectedDate != null) {
                  filteredOrders = filteredOrders.where((order) {
                    if (order.createdDate == null) return false;
                    final orderDate = order.createdDate!;
                    return orderDate.year == selectedDate!.year &&
                           orderDate.month == selectedDate!.month &&
                           orderDate.day == selectedDate!.day;
                  }).toList();
                }

                if (filteredOrders.isEmpty) {
                  return const Center(
                    child: Text('No delivered records found for the selected filters.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order.itemName} (${order.quantity} ${order.unit})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Category: ${order.category ?? 'N/A'} | Vendor: ${order.vendorName}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Text(
                              'Delivered',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
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

  // 7. Location & Map Pin Tab
  Widget _buildLocationTab() {
    final pinnedLocation = LatLng(_latitude, _longitude);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hotel Gate Location & Map Pin Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: _hotelNameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: 'Hotel Name', labelStyle: TextStyle(color: Colors.grey), filled: true, fillColor: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Street Address', labelStyle: TextStyle(color: Colors.grey)),
                  onSubmitted: (_) => _getCoordinatesFromAddress(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'City', labelStyle: TextStyle(color: Colors.grey)),
                  onSubmitted: (_) => _getCoordinatesFromAddress(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(initialCenter: pinnedLocation, initialZoom: 15.0),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  MarkerLayer(markers: [Marker(point: pinnedLocation, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40))]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            icon: const Icon(Icons.my_location, color: Colors.white),
            label: const Text('Pick Exact Map Location', style: TextStyle(color: Colors.white)),
            onPressed: () => _showUberStyleMapModal(context),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _isSavingProfile ? null : _saveHotelProfileData,
              child: Text(_isSavingProfile ? 'Saving...' : 'Save Profile & Location', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}