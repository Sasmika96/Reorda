import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmartOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Haversine Formula: GPS Coordinates දෙකක් අතර දුර (KM වලින්) ගණනය කිරීම
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // Result in Kilometers
  }

  /// Stock + Distance අනුව ළඟම ඉන්න සුදුසුම Vendor තෝරාගෙන Order එක Dispatch කිරීම
  Future<bool> dispatchSmartOrder({
    required String hotelId,
    required double hotelLat,
    required double hotelLng,
    required String itemName,
    required String category,
    required double requiredQty,
    required String unit,
  }) async {
    try {
      // 1. Firebase එකෙන් සියලුම Vendors ලාගේ ලැයිස්තුව ලබාගැනීම
      final vendorsSnapshot = await _firestore.collection('vendors').get();

      String? bestVendorId;
      String bestVendorName = "Authorized Vendor";
      double shortestDistance = double.infinity;

      // 2. එක එක Vendor ගේ Stock එක සහ Distance එක Check කිරීම
      for (var vendorDoc in vendorsSnapshot.docs) {
        final vendorData = vendorDoc.data();
        final vendorId = vendorDoc.id;

        // Vendor ගේ Warehouse Location (Latitude, Longitude)
        final double vendorLat = (vendorData['latitude'] ?? 0.0).toDouble();
        final double vendorLng = (vendorData['longitude'] ?? 0.0).toDouble();

        // Vendor ගේ Catalog එකේ අදාළ Item එක තිබේදැයි පරීක්ෂා කිරීම
        final catalogSnapshot = await _firestore
            .collection('vendors')
            .doc(vendorId)
            .collection('catalog')
            .where('name', isEqualTo: itemName)
            .get();

        if (catalogSnapshot.docs.isNotEmpty) {
          final itemData = catalogSnapshot.docs.first.data();
          final double availableStock = (itemData['stock_qty'] ?? 0).toDouble();

          // Condition 1: හෝටලයට අවශ්‍ය ප්‍රමාණයට Stock එක තිබේද?
          if (availableStock >= requiredQty) {
            // Condition 2: හෝටලයට ඇති දුර මැනීම (KM)
            double distance = calculateDistance(
              hotelLat,
              hotelLng,
              vendorLat,
              vendorLng,
            );

            // Condition 3: දැනට හමු වූ ළඟම Vendor තෝරාගැනීම
            if (distance < shortestDistance) {
              shortestDistance = distance;
              bestVendorId = vendorId;
              bestVendorName = vendorData['vendor_name'] ?? 'Authorized Vendor';
            }
          }
        }
      }

      // 3. සුදුසුම Vendor කෙනෙක් හමු වුවහොත් පමනක් Order එක Assign කර සේව් කිරීම
      if (bestVendorId != null) {
        final orderData = {
          'hotel_id': hotelId,
          'vendor_id': bestVendorId, // 🔑 ළඟම ඉන්න Stock එක තියෙන Vendor ගේ ID එක strictly සෙට් කරයි
          'vendor_name': bestVendorName,
          'item_name': itemName,
          'category': category,
          'quantity': requiredQty,
          'unit': unit,
          'status': 'PENDING',
          'created_date': DateTime.now().toIso8601String(),
          'distance_km': double.parse(shortestDistance.toStringAsFixed(2)),
        };

        // Global orders collection එකට සේව් කිරීම (Vendor Stream එක මෙයින් කියවයි)
        await _firestore.collection('orders').add(orderData);

        // Hotel sub-collection එකට සේව් කිරීම
        await _firestore
            .collection('hotels')
            .doc(hotelId)
            .collection('orders')
            .add(orderData);

        print("Order successfully routed to Vendor: $bestVendorName ($bestVendorId) at Distance: ${shortestDistance.toStringAsFixed(2)} KM");
        return true;
      } else {
        print("No matching vendor with sufficient stock found for item: $itemName");
        return false;
      }
    } catch (e) {
      print("Error during Smart Order Dispatch: $e");
      return false;
    }
  }
}