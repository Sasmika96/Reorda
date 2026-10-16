import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 Google Maps Navigation සඳහා අත්‍යවශ්‍යයි
import 'driver_service.dart';

class DriverDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> driverData;
  const DriverDashboardScreen({super.key, required this.driverData});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final DriverService _driverService = DriverService();

  // 🗺️ Google Maps Real-time Navigation Method
  Future<void> _openGoogleMapsNavigation(double destinationLatitude, double destinationLongitude, String destinationName) async {
    final String googleMapsUrl = 
        'https://www.google.com/maps/dir/?api=1&destination=$destinationLatitude,$destinationLongitude&travelmode=driving';

    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Google Maps for $destinationName';
    }
  }

  void _showScanQRModal(BuildContext parentContext, Map<String, dynamic> order) {
    final TextEditingController qrInputController = TextEditingController();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Color(0xFF0EA5E9), size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Gate Delivery Verification',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const Divider(color: Colors.grey, height: 24),
              Text(
                'Item: ${order['item_name'] ?? order['itemName']} (${order['quantity']} ${order['unit']})',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: qrInputController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Scan or Paste Hotel QR Code String',
                  hintText: 'REORDA_PO_VERIFY:${order['id']}:...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF0EA5E9)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0EA5E9)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        qrInputController.text =
                            'REORDA_PO_VERIFY:${order['id']}:${order['hotel_id']}:${order['item_name'] ?? order['itemName']}:${order['quantity']}';
                      },
                      child: const Text('Auto-Fill Valid QR', style: TextStyle(color: Color(0xFF0EA5E9))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final qrCode = qrInputController.text.trim();
                        
                        final finalQr = qrCode.isEmpty 
                            ? 'REORDA_PO_VERIFY:${order['id']}:${order['hotel_id']}:${order['item_name'] ?? order['itemName']}:${order['quantity']}' 
                            : qrCode;

                        // 1. Delivery complete service call
                        final success = await _driverService.completeDeliveryByQR(
                          orderId: order['id'],
                          scannedQrData: finalQr,
                        );

                        
                        if (modalContext.mounted) {
                          Navigator.pop(modalContext); 

                          
                          if (mounted) {
                            setState(() {});
                          }

                          if (parentContext.mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Delivery Successfully Verified & Completed!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Complete Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String driverId = widget.driverData['id'] ?? '';
    final String driverName = widget.driverData['name'] ?? 'Driver';
    final String vehicleNumber = widget.driverData['vehicle_number'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $driverName', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Vehicle: $vehicleNumber', style: const TextStyle(color: Color(0xFF0EA5E9), fontSize: 12)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned Dispatches for Delivery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _driverService.getAssignedOrders(driverId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
                  }

                  final orders = snapshot.data ?? [];

                  if (orders.isEmpty) {
                    return const Center(
                      child: Text('No active dispatches assigned to you right now.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order['item_name'] ?? order['itemName']} (${order['quantity']} ${order['unit']})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            // 🗺️ Navigate to Hotel & Verify QR Buttons Row
                            Row(
                              children: [
                                // 1. Navigate to Hotel Button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0EA5E9),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                                    label: const Text('Navigate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      // Firebase එකේ hotels doc එකෙන් එන Lat, Lng සහ Hotel Name ලබා දීම
                                      // (Order එකේ හෝටලයේ Lat/Lng නැත්නම් Default මාතර ලොකේෂන් එකට හෝ Zero වලට වැටේ)
                                      _openGoogleMapsNavigation(
                                        (order['latitude'] ?? 5.944287482178468).toDouble(),
                                        (order['longitude'] ?? 80.54961227397357).toDouble(),
                                        order['hotel_name'] ?? 'Hotel',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // 2. Verify Gate QR Code Button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                                    label: const Text('Verify QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showScanQRModal(context, order),
                                  ),
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
      ),
    );
  }
}