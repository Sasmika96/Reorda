import 'package:cloud_firestore/cloud_firestore.dart'; 

class PurchaseOrder {
  final String id;
  final String hotelId;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final String vendorName;
  final String status; // 'PENDING', 'DELIVERED'
  final DateTime createdDate;
  final DateTime? deliveredDate;

  PurchaseOrder({
    required this.id,
    required this.hotelId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.vendorName,
    required this.status,
    required this.createdDate,
    this.deliveredDate,
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, String id) {
    // Safe DateTime parsing for created_date
    DateTime parsedCreatedDate;
    try {
      final rawDate = map['created_date'];
      if (rawDate is Timestamp) {
        parsedCreatedDate = rawDate.toDate();
      } else if (rawDate is String && rawDate.isNotEmpty) {
        parsedCreatedDate = DateTime.parse(rawDate);
      } else {
        parsedCreatedDate = DateTime.now();
      }
    } catch (_) {
      parsedCreatedDate = DateTime.now();
    }

    // Safe DateTime parsing for delivered_date
    DateTime? parsedDeliveredDate;
    try {
      final rawDelivered = map['delivered_date'];
      if (rawDelivered is Timestamp) {
        parsedDeliveredDate = rawDelivered.toDate();
      } else if (rawDelivered is String && rawDelivered.isNotEmpty) {
        parsedDeliveredDate = DateTime.parse(rawDelivered);
      }
    } catch (_) {
      parsedDeliveredDate = null;
    }

    return PurchaseOrder(
      id: id,
      hotelId: map['hotel_id'] ?? '',
      itemName: map['item_name'] ?? '',
      category: map['category'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      vendorName: map['vendor_name'] ?? 'Authorized Vendor',
      status: map['status'] ?? 'PENDING',
      createdDate: parsedCreatedDate,
      deliveredDate: parsedDeliveredDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hotel_id': hotelId,
      'item_name': itemName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'vendor_name': vendorName,
      'status': status,
      'created_date': createdDate.toIso8601String(),
      'delivered_date': deliveredDate?.toIso8601String(),
    };
  }
}