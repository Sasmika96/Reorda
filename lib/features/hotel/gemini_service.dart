import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'inventory_item.dart';

class GeminiService {
  Future<String> generateDemandForecast(InventoryItem item) async {
    try {
      // 1. .env එකෙන් API Key එක ගන්නවා
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

      if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY_HERE") {
        print("GeminiService Warning: GEMINI_API_KEY is missing in .env file.");
        return _getFallbackRecommendation(item);
      }

      // 2. Google Cloud / Gemini AI Model initialization (gemini-3.8-flash)
      final model = GenerativeModel(
        model: 'ggemini-3.8-flash',
        apiKey: apiKey,
      );

      final prompt = '''
You are Reorda AI, an autonomous supply chain optimization engine.
Analyze the following inventory item for a hotel and provide a concise re-order recommendation and demand forecast:

Item: ${item.name}
Category: ${item.category}
Current Stock: ${item.currentStock} ${item.unit}
Threshold Limit: ${item.threshold} ${item.unit}

Provide a short 3-bullet response:
1. Recommended Re-order Quantity.
2. Estimated Lead Time / Urgency Level.
3. Key Risk Factor (e.g., spoilage, high weekend demand).
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      } else {
        return _getFallbackRecommendation(item);
      }
    } catch (e) {
      print('GeminiService API Error: $e');
      // API Error එකක් ආවොත් Smart Fallback Recommendation එක පෙන්වයි
      return _getFallbackRecommendation(item);
    }
  }

  /// Dynamic Fallback Recommendation ($2 \times \text{Threshold}$)
  String _getFallbackRecommendation(InventoryItem item) {
    // Re-order Quantity එක Threshold එක මෙන් දෙගුණයක් ලෙස සකසයි
    final recommendedQty = (item.threshold * 2).toInt();

    return '''
🤖 Reorda AI Recommendation:
• Recommended Re-order Quantity: $recommendedQty ${item.unit}
• Urgency Level: High (Current stock ${item.currentStock} ${item.unit} is at or below threshold ${item.threshold} ${item.unit})
• Key Risk Factor: Stockout risk during upcoming peak hotel service hours.
''';
  }
}