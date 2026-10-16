import 'package:flutter/material.dart';

class InventoryAlertBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const InventoryAlertBanner({
    super.key,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade700.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: Colors.amber.shade400, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white70, // <-- මෙතැන වෙනස් කළා
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: onClose,
            tooltip: 'Dismiss Alert',
          ),
        ],
      ),
    );
  }
}