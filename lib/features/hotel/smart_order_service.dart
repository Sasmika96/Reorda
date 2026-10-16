import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmartOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // Result in Kilometers
  }

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
  
      final vendorsSnapshot = await _firestore.collection('vendors').get();

      String? bestVendorId;
      String bestVendorName = "Authorized Vendor";
      double shortestDistance = double.infinity;


      for (var vendorDoc in vendorsSnapshot.docs) {
        final vendorData = vendorDoc.data();
        final vendorId = vendorDoc.id;

        // Vendor ගේ Warehouse Location (Latitude, Longitude)
        final double vendorLat = (vendorData['latitude'] ?? 0.0).toDouble();
        final double vendorLng = (vendorData['longitude'] ?? 0.0).toDouble();

     
        final catalogSnapshot = await _firestore
            .collection('vendors')
            .doc(vendorId)
            .collection('catalog')
            .where('name', isEqualTo: itemName)
            .get();

        if (catalogSnapshot.docs.isNotEmpty) {
          final itemData = catalogSnapshot.docs.first.data();
          final double availableStock = (itemData['stock_qty'] ?? 0).toDouble();

       
          if (availableStock >= requiredQty) {

            double distance = calculateDistance(
              hotelLat,
              hotelLng,
              vendorLat,
              vendorLng,
            );


            if (distance < shortestDistance) {
              shortestDistance = distance;
              bestVendorId = vendorId;
              bestVendorName = vendorData['vendor_name'] ?? 'Authorized Vendor';
            }
          }
        }
      }


      if (bestVendorId != null) {
        final orderData = {
          'hotel_id': hotelId,
          'vendor_id': bestVendorId, 
          'vendor_name': bestVendorName,
          'item_name': itemName,
          'category': category,
          'quantity': requiredQty,
          'unit': unit,
          'status': 'PENDING',
          'created_date': DateTime.now().toIso8601String(),
          'distance_km': double.parse(shortestDistance.toStringAsFixed(2)),
        };

        await _firestore.collection('orders').add(orderData);


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