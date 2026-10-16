import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_item.dart';
import 'purchase_order.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String hotelId; // <-- හෝටල් ID එක මෙතැනට ගන්නවා

  InventoryService({required this.hotelId});

  // Haversine Formula: GPS coordinates දෙකක් අතර දුර (KM වලින්) ගණනය කරයි
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Super Admin දාපු Master Catalog එක Live Stream එකක් විදිහට ලබාගැනීම
  Stream<List<MasterItem>> getMasterItemsStream() {
    return _firestore.collection('master_catalog').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MasterItem(
          id: doc.id,
          name: data['name'] ?? '',
          category: data['category'] ?? '',
          unit: data['unit'] ?? 'Kg',
        );
      }).toList();
    });
  }

  // අදාළ Hotel එකට පමණක් අයිති Inventory එක Fetch කිරීම (Strict Multi-Tenancy)
  Stream<List<InventoryItem>> getHotelInventory() {
    return _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('inventory')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  // 🔑 Alias for Dashboard Compatibility (Error එක මඟහරවා ගැනීමට)
  Stream<List<InventoryItem>> getInventoryItemsStream() {
    return getHotelInventory();
  }

  // අදාළ Hotel එකට පමණක් අයිති Purchase Orders Fetch කිරීම
  Stream<List<PurchaseOrder>> getHotelPurchaseOrders() {
    return _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('orders')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PurchaseOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  // 🔑 Alias for Dashboard Compatibility (Error එක මඟහරවා ගැනීමට)
  Stream<List<PurchaseOrder>> getHotelOrdersStream() {
    return getHotelPurchaseOrders();
  }

  // Stream Hotel Profile / Location Details
  Stream<DocumentSnapshot> getHotelProfile() {
    return _firestore.collection('hotels').doc(hotelId).snapshots();
  }

  // Update Hotel Location Profile
  Future<void> updateHotelProfile({
    required String address,
    required String city,
    required double latitude,
    required double longitude,
    required String contactNumber,
  }) async {
    await _firestore.collection('hotels').doc(hotelId).set({
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'contact_number': contactNumber,
      'updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// 🧠 SMART ROUTING DISPATCHER: හෝටලයේ ලොකේෂන් එක සහ Stock එක බලලා ළඟම ඉන්න Vendor ට Order එක යවයි
  Future<bool> createPurchaseOrder({
    required String itemName,
    required String category,
    required double quantity,
    required String unit,
  }) async {
    try {
      print("--- 🚀 STARTING SMART ORDER DISPATCH ---");
      print("Target Item: $itemName, Category: $category, Qty: $quantity $unit");

      // 1. හෝටලයේ GPS ලොකේෂන් එක ලබාගැනීම
      final hotelDoc = await _firestore.collection('hotels').doc(hotelId).get();
      if (!hotelDoc.exists) {
        print("❌ Error: Hotel profile not found for ID: $hotelId");
        return false;
      }

      final hotelData = hotelDoc.data()!;
      final double hotelLat = (hotelData['latitude'] ?? 0.0).toDouble();
      final double hotelLng = (hotelData['longitude'] ?? 0.0).toDouble();
      print("📍 Hotel Location -> Lat: $hotelLat, Lng: $hotelLng");

      // 2. සිස්ටම් එකේ ඉන්න සියලුම Vendors ලා ලබාගැනීම
      final vendorsSnapshot = await _firestore.collection('vendors').get();
      print("🏢 Total vendors found in system: ${vendorsSnapshot.docs.length}");

      String? bestVendorId;
      String bestVendorName = "Authorized Vendor";
      double shortestDistance = double.infinity;

      // 3. එක එක Vendor ගේ Warehouse Location සහ Catalog Stock පරීක්ෂා කිරීම
      for (var vendorDoc in vendorsSnapshot.docs) {
        final vendorData = vendorDoc.data();
        final vendorId = vendorDoc.id;
        final vendorName = vendorData['vendor_name'] ?? vendorData['company_name'] ?? 'Unknown Vendor';

        final double vendorLat = (vendorData['latitude'] ?? 0.0).toDouble();
        final double vendorLng = (vendorData['longitude'] ?? 0.0).toDouble();

        print("🔍 Checking Vendor: $vendorName ($vendorId) at Lat: $vendorLat, Lng: $vendorLng");

        // Vendor ගේ catalog එක fetch කිරීම
        final catalogSnapshot = await _firestore
            .collection('vendors')
            .doc(vendorId)
            .collection('catalog')
            .get();

        bool foundItem = false;
        for (var catalogDoc in catalogSnapshot.docs) {
          final itemData = catalogDoc.data();
          final catalogItemName = (itemData['name'] ?? '').toString().trim();
          
          // Case-insensitive comparison (අකුරු වල පොඩි වෙනස්කම් මඟහරවා ගැනීමට)
          if (catalogItemName.toLowerCase() == itemName.trim().toLowerCase()) {
            foundItem = true;
            final double availableStock = (itemData['stock_qty'] ?? 0).toDouble();
            print("   ↳ Found item '$catalogItemName' with stock: $availableStock");

            // Condition 1: අවශ්‍ය ප්‍රමාණයට Stock එක තිබේද?
            if (availableStock >= quantity) {
              // Condition 2: දුර මැනීම (KM)
              double distance = calculateDistance(
                hotelLat,
                hotelLng,
                vendorLat,
                vendorLng,
              );
              print("   ↳ Distance to hotel: ${distance.toStringAsFixed(2)} KM");

              // Condition 3: ළඟම ඉන්න Vendor ව තෝරාගැනීම
              if (distance < shortestDistance) {
                shortestDistance = distance;
                bestVendorId = vendorId;
                bestVendorName = vendorName;
                print("   ⭐ New best vendor selected: $bestVendorName (${distance.toStringAsFixed(2)} KM)");
              }
            } else {
              print("   ⚠️ Insufficient stock! Available: $availableStock, Required: $quantity");
            }
            break;
          }
        }
        if (!foundItem) {
          print("   ❌ Item '$itemName' not found in this vendor's catalog.");
        }
      }

      // 4. සුදුසුම Vendor කෙනෙක් හමු වුවහොත් පමණක් Order එක Assign කර Save කිරීම
      if (bestVendorId != null) {
        // 👇 එකම Document ID එකක් මුලින්ම Generate කර ගැනීම
        final String orderId = _firestore.collection('orders').doc().id;

        final orderData = {
          'order_id': orderId, // 🔑 ID එක Field එකක් ලෙසද ඇතුළත් කිරීම
          'hotel_id': hotelId,
          'vendor_id': bestVendorId,
          'vendor_name': bestVendorName,
          'item_name': itemName,
          'category': category,
          'quantity': quantity,
          'unit': unit,
          'status': 'PENDING',
          'created_date': DateTime.now().toIso8601String(),
          'distance_km': double.parse(shortestDistance.toStringAsFixed(2)),
        };

        // 👇 add() වෙනුවට doc(orderId).set(orderData) භාවිතා කිරීම (මෙයින් ID දෙකම එකම වේ)
        
        // 1. Global orders collection එකට එම ID එකෙන්ම සේව් කිරීම
        await _firestore.collection('orders').doc(orderId).set(orderData);

        // 2. Hotel sub-collection එකටත් එම ID එකෙන්ම සේව් කිරීම
        await _firestore
            .collection('hotels')
            .doc(hotelId)
            .collection('orders')
            .doc(orderId)
            .set(orderData);

        print("✅ SUCCESS: Smart Order routed to: $bestVendorName at ${shortestDistance.toStringAsFixed(2)} KM");
        return true;
      }else {
        print("❌ FAILED: No eligible vendor found with sufficient stock for item: $itemName");
        return false;
      }
    } catch (e) {
      print("🔥 EXCEPTION in Smart Order Dispatch: $e");
      return false;
    }
  }

  Future<void> completeRestockOrder({
    required String orderId,
    required String itemName,
    required double quantity,
  }) async {
    final now = DateTime.now();

    await _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('orders')
        .doc(orderId)
        .update({
      'status': 'DELIVERED',
      'delivered_date': now.toIso8601String(),
    });

    final inventorySnapshot = await _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('inventory')
        .where('name', isEqualTo: itemName)
        .get();

    if (inventorySnapshot.docs.isNotEmpty) {
      final docRef = inventorySnapshot.docs.first.reference;
      final currentStock = (inventorySnapshot.docs.first.data()['current_stock'] ?? 0).toDouble();
      await docRef.update({
        'current_stock': currentStock + quantity,
      });
    }

    double unitPrice = 1200.0;
    final vendorCatalogSnapshot = await _firestore
        .collection('vendor_catalog')
        .where('name', isEqualTo: itemName)
        .get();

    if (vendorCatalogSnapshot.docs.isNotEmpty) {
      unitPrice = (vendorCatalogSnapshot.docs.first.data()['unit_price'] ?? 1200.0).toDouble();
    }

    await _firestore.collection('vendor_invoices').add({
      'order_id': orderId,
      'hotel_id': hotelId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': 'Kg/Liters',
      'unit_price': unitPrice,
      'total_amount': quantity * unitPrice,
      'vendor_name': 'Authorized Vendor',
      'issued_date': now.toIso8601String(),
    });
  }

  Future<void> addItemToInventory({
    required MasterItem masterItem,
    required double initialStock,
    required double reorderLimit,
    DateTime? expiryDate,
  }) async {
    await _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('inventory')
        .add({
      'hotel_id': hotelId,
      'name': masterItem.name,
      'category': masterItem.category,
      'current_stock': initialStock,
      'threshold': reorderLimit,
      'unit': masterItem.unit,
      'created_date': DateTime.now().toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
    });
  }

  Future<void> releaseStock(String itemId, double releaseQty) async {
    final docRef = _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('inventory')
        .doc(itemId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentStock = (snapshot.data()?['current_stock'] ?? 0).toDouble();
        final newStock = (currentStock - releaseQty) < 0 ? 0.0 : (currentStock - releaseQty);
        transaction.update(docRef, {
          'current_stock': newStock,
        });
      }
    });
  }

  Future<void> deleteItem(String itemId) async {
    await _firestore
        .collection('hotels')
        .doc(hotelId)
        .collection('inventory')
        .doc(itemId)
        .delete();
  }
}