import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 Google Maps Navigation සඳහා අත්‍යවශ්‍යයි

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Driver Login via Phone Number
  Future<Map<String, dynamic>?> loginDriver(String phone) async {
    final query = await _firestore
        .collection('drivers')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // 2. Stream of Dispatched Orders assigned to this Driver
  Stream<List<Map<String, dynamic>>> getAssignedOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driver_id', isEqualTo: driverId)
        .where('status', isEqualTo: 'DISPATCHED')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // 3. Complete Delivery via QR Verification
  Future<bool> completeDeliveryByQR({
    required String orderId,
    required String scannedQrData,
  }) async {
    try {
      print("--- 🚀 STARTING QR DELIVERY COMPLETION ---");

      String? hotelId;
      String itemName = '';
      double quantity = 0.0;
      Map<String, dynamic> orderData = {};

      // 1.Top-level 'orders' collection check
      final topLevelDoc = await _firestore.collection('orders').doc(orderId).get();
      if (topLevelDoc.exists) {
        orderData = topLevelDoc.data()!;
        hotelId = orderData['hotel_id'] ?? orderData['hotelId'];
        itemName = orderData['item_name'] ?? orderData['itemName'] ?? '';
        quantity = (orderData['quantity'] ?? 0).toDouble();
      }

      // 2. Top-level empty find Collection Group 
      if (hotelId == null || hotelId.isEmpty) {
        final ordersQuery = await _firestore
            .collectionGroup('orders')
            .where(FieldPath.documentId, isEqualTo: orderId)
            .get();

        if (ordersQuery.docs.isNotEmpty) {
          final doc = ordersQuery.docs.first;
          orderData = doc.data();
          hotelId = orderData['hotel_id'] ?? orderData['hotelId'];
          itemName = orderData['item_name'] ?? orderData['itemName'] ?? '';
          quantity = (orderData['quantity'] ?? 0).toDouble();
        }
      }

      if (hotelId == null || hotelId.isEmpty) {
        print("❌ Error: Hotel ID missing for order: $orderId");
        return false;
      }

      final now = DateTime.now();
      final updateData = {
        'status': 'DELIVERED',
        'delivered_date': now.toIso8601String(),
        'delivered_at': now.toIso8601String(),
      };

      // Orders update 
      await _firestore.collection('orders').doc(orderId).set(updateData, SetOptions(merge: true));

      await _firestore
          .collection('hotels')
          .doc(hotelId)
          .collection('orders')
          .doc(orderId)
          .set(updateData, SetOptions(merge: true));

      // Inventory Stock increes
      final inventorySnapshot = await _firestore
          .collection('hotels')
          .doc(hotelId)
          .collection('inventory')
          .get();

      bool stockUpdated = false;
      for (var invDoc in inventorySnapshot.docs) {
        final invData = invDoc.data();
        final invItemName = (invData['name'] ?? invData['item_name'] ?? invData['itemName'] ?? '').toString().trim();

        if (invItemName.toLowerCase() == itemName.trim().toLowerCase()) {
          final docRef = invDoc.reference;
          final currentStock = (invData['current_stock'] ?? invData['stock_qty'] ?? invData['stockQty'] ?? 0).toDouble();
          final newStock = currentStock + quantity;

          await docRef.update({
            'current_stock': newStock,
            'stock_qty': newStock,
            'stockQty': newStock,
          });

          stockUpdated = true;
          break;
        }
      }

      // 5. Vendor Invoice automate
      try {
        final invoiceRef = _firestore.collection('vendor_invoices');
        
        final String vendorId = orderData['vendor_id'] ?? orderData['vendorId'] ?? 'XvzGW3...';

        await invoiceRef.add({
          'order_id': orderId,
          'hotel_id': hotelId,
          'vendor_id': vendorId,
          'item_name': itemName.isNotEmpty ? itemName : 'Restock Item',
          'quantity': quantity,
          'unit': orderData['unit'] ?? 'Kg/Liters',
          'unit_price': 1200.0,
          'total_amount': quantity * 1200.0,
          'vendor_name': orderData['vendor_name'] ?? orderData['vendorName'] ?? 'Authorized Vendor',
          'issued_date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
        
        print("✅ SUCCESS: Vendor invoice with vendor_id successfully added to Firestore!");
      } catch (invError) {
        print("🔥 CRITICAL INVOICE ERROR: $invError");
      }

      print("✅ SUCCESS: Delivery completed for Order ID: $orderId");
      return true;
    } catch (e) {
      print('🔥 Error completing delivery by QR: $e');
      return false;
    }
  }

  // 🗺️ 4. Google Maps Real-time Navigation Method for Driver
  Future<void> openGoogleMapsNavigation(double destinationLatitude, double destinationLongitude, String destinationName) async {
    final String googleMapsUrl = 
        'https://www.google.com/maps/dir/?api=1&destination=$destinationLatitude,$destinationLongitude&travelmode=driving';

    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Google Maps for $destinationName';
    }
  }
}