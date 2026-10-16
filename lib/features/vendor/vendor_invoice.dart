class VendorInvoice {
  final String id;
  final String orderId;
  final String hotelId;
  final String itemName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalAmount;
  final String vendorName;
  final DateTime issuedDate;

  VendorInvoice({
    required this.id,
    required this.orderId,
    required this.hotelId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalAmount,
    required this.vendorName,
    required this.issuedDate,
  });

  factory VendorInvoice.fromMap(Map<String, dynamic> map, String id) {
    return VendorInvoice(
      id: id,
      orderId: map['order_id'] ?? '',
      hotelId: map['hotel_id'] ?? '',
      itemName: map['item_name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      vendorName: map['vendor_name'] ?? '',
      issuedDate: DateTime.parse(map['issued_date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'hotel_id': hotelId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'vendor_name': vendorName,
      'issued_date': issuedDate.toIso8601String(),
    };
  }
}