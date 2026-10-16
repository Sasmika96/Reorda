import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../hotel/purchase_order.dart';
import 'vendor_invoice.dart';

class VendorItem {
  final String id;
  final String name;
  final String category;
  final double unitPrice;
  final String unit;
  final double stockQty;

  VendorItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.unit,
    required this.stockQty,
  });

  factory VendorItem.fromMap(Map<String, dynamic> map, String id) {
    return VendorItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'Kg',
      stockQty: (map['stock_qty'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'unit_price': unitPrice,
      'unit': unit,
      'stock_qty': stockQty,
    };
  }
}

class VendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String vendorId;

  VendorService({required this.vendorId});

  // Helper: Correct Document ID (e.g., vendor_UID)
  String get formattedVendorId =>
      vendorId.startsWith('vendor_') ? vendorId : 'vendor_$vendorId';

  // Fetch Super Admin Approved Master Catalog Live Stream from Firestore
  Stream<List<Map<String, String>>> getMasterCatalogStream() {
    return _firestore.collection('master_catalog').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': (data['name'] ?? '').toString(),
          'category': (data['category'] ?? '').toString(),
          'unit': (data['unit'] ?? 'Kg').toString(),
        };
      }).toList();
    });
  }

  // Fetch Vendor Catalog - Isolation by Vendor Document ID
  Stream<List<VendorItem>> getVendorCatalog() {
    return _firestore
        .collection('vendors')
        .doc(formattedVendorId)
        .collection('catalog')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addVendorItem({
    required String name,
    required String category,
    required double unitPrice,
    required String unit,
    required double stockQty,
  }) async {
    await _firestore
        .collection('vendors')
        .doc(formattedVendorId)
        .collection('catalog')
        .add({
      'name': name,
      'category': category,
      'unit_price': unitPrice,
      'unit': unit,
      'stock_qty': stockQty,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // 1. අලුත් Driver කෙනෙක් Register කිරීම (formattedVendorId පාවිච්චි කරමින්)
  Future<void> addDriver({
    required String name,
    required String phone,
    required String vehicleNumber,
  }) async {
    await _firestore.collection('drivers').add({
      'vendor_id': formattedVendorId, // 👈 formattedVendorId දැම්මා
      'name': name,
      'phone': phone,
      'vehicle_number': vehicleNumber,
      'status': 'AVAILABLE',
      'latitude': 6.927079, // Initial default location
      'longitude': 79.861244,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // 2. අදාළ Vendor ට අයිති Drivers ලාගේ Live Stream එක ලබාගැනීම (formattedVendorId සමඟ)
  Stream<List<Map<String, dynamic>>> getDriversStream() {
    return _firestore
        .collection('drivers')
        .where('vendor_id', isEqualTo: formattedVendorId) // 👈 formattedVendorId සමඟ ෆිල්ටර් කරයි
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // 3. Order එක Dispatch කරද්දී Driver ව Assign කිරීම
  // 3. Order එක Dispatch කරද්දී Driver ව Assign කිරීම සහ PIN එක සෑදීම
// අහඹු අංක (Random numbers) සෑදීමට

// Order එක Dispatch කරද්දී PIN එක ජනනය කර සේව් කර Return කිරීම
  Future<String> dispatchOrder({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    final now = DateTime.now().toIso8601String();
    
    // 4 අංකයක අහඹු PIN එකක් සෑදීම
    final String deliveryPin = (1000 + Random().nextInt(9000)).toString();

    await _firestore.collection('orders').doc(orderId).update({
      'status': 'DISPATCHED',
      'driver_id': driverId,
      'driver_name': driverName,
      'delivery_pin': deliveryPin,
      'dispatched_at': now,
    });

    await _firestore.collection('drivers').doc(driverId).update({
      'status': 'ON_DELIVERY',
    });

    return deliveryPin;
  }

  Future<void> deleteVendorItem(String itemId) async {
    await _firestore
        .collection('vendors')
        .doc(formattedVendorId)
        .collection('catalog')
        .doc(itemId)
        .delete();
  }

  // Incoming Orders
Stream<List<PurchaseOrder>> getIncomingOrders() {
    return _firestore
        .collection('orders')
        .where('vendor_id', isEqualTo: formattedVendorId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PurchaseOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Invoices - Live Stream from vendor_invoices
  Stream<List<VendorInvoice>> getVendorInvoices() {
    return _firestore
        .collection('vendor_invoices')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorInvoice.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Vendor Profile / Warehouse Location
  Stream<DocumentSnapshot> getVendorProfile() {
    return _firestore.collection('vendors').doc(formattedVendorId).snapshots();
  }

  // Update Vendor Profile
  Future<void> updateVendorProfile({
    required String companyName,
    required String warehouseAddress,
    required String city,
    required String contactPhone,
  }) async {
    await _firestore.collection('vendors').doc(formattedVendorId).set({
      'vendor_name': companyName,
      'address': warehouseAddress,
      'city': city,
      'phone': contactPhone,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}