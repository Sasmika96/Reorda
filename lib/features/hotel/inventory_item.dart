class InventoryItem {
  final String id;
  final String hotelId;
  final String name;
  final String category;
  final double currentStock;
  final double threshold;
  final String unit;
  final DateTime createdDate;
  final DateTime? expiryDate;

  InventoryItem({
    required this.id,
    required this.hotelId,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.threshold,
    required this.unit,
    required this.createdDate,
    this.expiryDate,
  });

  bool get isLowStock => currentStock <= threshold;

  bool get isNearExpiry {
    if (expiryDate == null) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft <= 7 && daysLeft >= 0; // Expires in <= 7 days
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      hotelId: map['hotel_id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      currentStock: (map['current_stock'] ?? 0).toDouble(),
      threshold: (map['threshold'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'units',
      createdDate: map['created_date'] != null 
          ? DateTime.parse(map['created_date']) 
          : DateTime.now(),
      expiryDate: map['expiry_date'] != null 
          ? DateTime.parse(map['expiry_date']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hotel_id': hotelId,
      'name': name,
      'category': category,
      'current_stock': currentStock,
      'threshold': threshold,
      'unit': unit,
      'created_date': createdDate.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }
}

class MasterItem {
  final String id;
  final String category;
  final String name;
  final String unit;

  MasterItem({
    required this.id,
    required this.category,
    required this.name,
    required this.unit,
  });
}