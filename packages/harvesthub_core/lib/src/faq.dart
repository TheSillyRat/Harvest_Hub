import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class FaqTopic {
  final String id;
  final String label;
  final String icon;
  final String prompt;

  const FaqTopic({
    required this.id,
    required this.label,
    required this.icon,
    required this.prompt,
  });
}

class AiResponseResult {
  final String text;
  final String category;
  final List<String> pinnedProductIds;
  final String modelUsed;

  const AiResponseResult({
    required this.text,
    required this.category,
    required this.pinnedProductIds,
    this.modelUsed = 'Gemini 3.6 Flash',
  });
}

class FaqService {
  static const String defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String defaultModel = 'gemini-2.5-flash';

  static const List<String> supportedModels = [
    'gemini-3.6-flash',
    'gemini-3.8-flash',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-flash-latest',
  ];

  static const String greeting =
      'Hello! I am AI Sprout 🌱 — your HarvestHub AI Assistant. I can:\n\n• 🥦 Recommend fresh produce available in stock\n• 💊 Provide nutrition & health benefits\n• 📦 Give storage & preservation tips\n• 🗓️ Share seasonal harvest information\n• 💰 Compare store prices vs market average\n\nHow can I assist you today? (I answer in English by default, or in Vietnamese if requested!)';

  static const List<FaqTopic> quickTopics = [
    FaqTopic(
      id: 'nutrition',
      label: 'Nutrition & Health',
      icon: '🥦',
      prompt: 'What are the health and nutrition benefits of vegetables available in our store?',
    ),
    FaqTopic(
      id: 'storage',
      label: 'Storage & Preservation',
      icon: '📦',
      prompt: 'How should I preserve fresh leafy greens and fruits from HarvestHub?',
    ),
    FaqTopic(
      id: 'seasonal',
      label: 'Seasonal Harvest',
      icon: '🗓️',
      prompt: 'Which organic produce in our catalog is currently in peak season?',
    ),
    FaqTopic(
      id: 'products',
      label: 'In-Store Recommendations',
      icon: '🥕',
      prompt: 'Recommend top fresh produce currently available in stock at local farm stores.',
    ),
    FaqTopic(
      id: 'market',
      label: 'Market Price Check',
      icon: '💰',
      prompt: 'How do HarvestHub farm store prices compare with market average prices?',
    ),
  ];

  final String apiKey;
  final String preferredModel;

  FaqService({String? apiKey, String? modelName})
      : apiKey = apiKey ?? defaultApiKey,
        preferredModel = modelName ?? defaultModel;

  Future<AiResponseResult> getAiResponse(
    String query, {
    List<Product>? liveProducts,
    List<Map<String, String>>? chatHistory,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const AiResponseResult(
        text: greeting,
        category: 'General',
        pinnedProductIds: [],
        modelUsed: 'Gemini 1.5 Pro',
      );
    }

    if (apiKey.isNotEmpty) {
      /* Try preferred model first, then fallback to other models in cascade */
      final modelsToTry = <String>[
        preferredModel,
        ...supportedModels.where((m) => m != preferredModel),
      ];

      for (final model in modelsToTry) {
        try {
          final result = await _callGeminiApi(
            cleanQuery,
            modelName: model,
            liveProducts: liveProducts,
            chatHistory: chatHistory,
          );
          if (result != null) {
            return result;
          }
        } catch (e) {
          if (kDebugMode) {
            print('HarvestHub FaqService Gemini API Error with $model: $e');
          }
        }
      }
    }

    return _getLocalFallbackAnswer(cleanQuery, liveProducts: liveProducts);
  }

  Future<AiResponseResult?> _callGeminiApi(
    String query, {
    required String modelName,
    List<Product>? liveProducts,
    List<Map<String, String>>? chatHistory,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    /* Construct live product catalog context string */
    final productContext = StringBuffer();
    if (liveProducts != null && liveProducts.isNotEmpty) {
      productContext.writeln('LIVE HARVESTHUB INVENTORY:');
      for (final p in liveProducts.take(15)) {
        if (p.isActive) {
          final priceFormatted = '\$${(p.price / 100).toStringAsFixed(2)}';
          productContext.writeln(
            '- ID: ${p.id} | Name: "${p.name}" | Price: $priceFormatted/${p.unit} | Stock: ${p.stockQty} ${p.stockQty > 0 ? 'in stock' : 'OUT OF STOCK'} | Farm: "${p.farmerName}" | Category: ${p.categoryId}',
          );
        }
      }
    } else {
      productContext.writeln('LIVE HARVESTHUB INVENTORY: Catalog loading or unavailable.');
    }

    final systemInstructionText = '''
You are AI Sprout — the official AI Assistant of the HarvestHub Mobile Application, powered by $modelName.

═══════════════════════════════════════
LANGUAGE RULE (CRITICAL & STRICT):
═══════════════════════════════════════
- ALWAYS respond in ENGLISH by default for ALL customer queries, EVEN IF the user input question is typed in Vietnamese or any other language.
- EXCEPTION: ONLY respond in Vietnamese if the user explicitly asks/commands to speak or reply in Vietnamese (e.g., "nói tiếng việt", "trả lời bằng tiếng việt", "bằng tiếng việt", "dùng tiếng việt", "speak in vietnamese", "answer in vietnamese").
- Do NOT switch to Vietnamese just because the prompt or question is in Vietnamese. You MUST default to ENGLISH unless explicitly asked to speak Vietnamese.

═══════════════════════════════════════
STRICT DOMAIN SCOPE:
═══════════════════════════════════════
You ONLY answer questions related to:
1. Fresh organic farm produce available in HarvestHub inventory
2. Nutrition & health benefits of fruits and vegetables
3. Food storage, preservation & shelf-life tips
4. Seasonal harvest schedules
5. Market price comparison vs HarvestHub prices
6. HarvestHub app operations (placing orders, pickup slots, wishlist, following farms)

If the user asks about off-topic subjects (news, sports, coding, politics, general chitchat), politely decline in English and invite them to ask about fresh produce or store items instead.

═══════════════════════════════════════
APP OPERATIONS CONTEXT:
═══════════════════════════════════════
- HarvestHub connects local organic farmers directly with customers.
- Simulated demo payment (no real credit card charges).
- Customers pick up orders at farm stalls during selected time slots.
- Real-time order tracking: Pending -> Confirmed -> Ready -> Completed (or Cancelled with auto-restock).
- Wishlist & Follow Farm features are active.

═══════════════════════════════════════
LIVE IN-STOCK INVENTORY:
═══════════════════════════════════════
$productContext

═══════════════════════════════════════
RECOMMENDING & PINNING PRODUCTS RULES:
═══════════════════════════════════════
- When recommending specific items from the catalog above, mention accurate product names, prices, and farms.
- ONLY pin products when the customer is explicitly asking for product recommendations, store catalog items, or specific produce.
- DO NOT pin products for general nutrition advice, storage tips, price checks, or app operation questions.
- DO NOT pin out-of-stock items (Stock: OUT OF STOCK).
- Pin maximum 3 most relevant in-stock items using the exact format at the very end of your response.

OUTPUT TAGS AT THE VERY END OF YOUR RESPONSE:
1. Topic category tag (ALWAYS REQUIRED):
   [CATEGORY: Nutrition] or [CATEGORY: Storage] or [CATEGORY: Seasonal] or [CATEGORY: Product] or [CATEGORY: Market] or [CATEGORY: App]

2. Product pinning tag (ONLY when relevant in-stock produce items exist):
   [PIN_PRODUCTS: id1, id2]

EXAMPLES:
- User: "App đang có những sản phẩm nào" -> Respond in ENGLISH describing available produce + [CATEGORY: Product] + [PIN_PRODUCTS: prod_1, prod_2]
- User: "Mình cần tìm rau sạch" -> Respond in ENGLISH introducing fresh leafy greens in stock + [CATEGORY: Product] + [PIN_PRODUCTS: prod_1]
- User: "Nói tiếng Việt đi" -> Respond in VIETNAMESE introducing your capabilities + [CATEGORY: App]
''';

    /* Build contents array ensuring strictly alternating turns */
    final contents = <Map<String, dynamic>>[];

    if (chatHistory != null && chatHistory.isNotEmpty) {
      String? lastRole;
      for (final msg in chatHistory) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        final text = (msg['text'] ?? '').trim();

        /* Skip empty messages or consecutive identical roles */
        if (text.isEmpty || role == lastRole) continue;

        contents.add({
          'role': role,
          'parts': [
            {'text': text}
          ]
        });
        lastRole = role;
      }

      /* Ensure last turn in history was 'model' before adding current 'user' query */
      if (lastRole == 'user') {
        contents.removeLast();
      }
    }

    /* Add current user query */
    contents.add({
      'role': 'user',
      'parts': [
        {'text': query}
      ]
    });

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemInstructionText}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 900,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final rawText = parts[0]['text'] as String?;
          if (rawText != null && rawText.isNotEmpty) {
            final formattedModel = modelName.contains('3.6')
                ? 'Gemini 3.6 Flash'
                : modelName.contains('3.8')
                    ? 'Gemini 3.8 Flash'
                    : modelName.contains('3.5')
                        ? 'Gemini 3.5 Flash'
                        : modelName.contains('2.5')
                            ? 'Gemini 2.5 Flash'
                            : 'Gemini Flash';
            return _parseAiResponse(rawText, modelUsed: formattedModel);
          }
        }
      }
    } else {
      if (kDebugMode) {
        print('Gemini API Error ($modelName) Status ${response.statusCode}: ${response.body}');
      }
    }

    return null;
  }

  AiResponseResult _parseAiResponse(String rawText, {String modelUsed = 'Gemini 1.5 Pro'}) {
    String category = 'Product';
    final pinnedIds = <String>[];
    String cleanText = rawText;

    /* Extract Category */
    final categoryMatch = RegExp(r'\[CATEGORY:\s*([\w\s]+)\]', caseSensitive: false).firstMatch(cleanText);
    if (categoryMatch != null) {
      category = categoryMatch.group(1)?.trim() ?? 'Product';
      cleanText = cleanText.replaceAll(categoryMatch.group(0)!, '').trim();
    }

    /* Extract Pinned Products */
    final pinMatch = RegExp(r'\[PIN_PRODUCTS:\s*([^\]]+)\]', caseSensitive: false).firstMatch(cleanText);
    if (pinMatch != null) {
      final idsString = pinMatch.group(1) ?? '';
      cleanText = cleanText.replaceAll(pinMatch.group(0)!, '').trim();
      final ids = idsString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      pinnedIds.addAll(ids);
    }

    return AiResponseResult(
      text: cleanText,
      category: category,
      pinnedProductIds: pinnedIds,
      modelUsed: modelUsed,
    );
  }

  AiResponseResult _getLocalFallbackAnswer(String query, {List<Product>? liveProducts}) {
    final q = query.toLowerCase();
    final pinnedIds = <String>[];
    String category = 'Product';
    String answerText = '';

    final requestsVietnamese = q.contains('tiếng việt') ||
        q.contains('nói tiếng việt') ||
        q.contains('bằng tiếng việt') ||
        q.contains('dùng tiếng việt') ||
        q.contains('in vietnamese') ||
        q.contains('speak vietnamese');

    final isProductQuery = q.contains('sản phẩm') ||
        q.contains('nông sản') ||
        q.contains('mua') ||
        q.contains('gợi ý') ||
        q.contains('recommend') ||
        q.contains('có gì') ||
        q.contains('hôm nay có') ||
        q.contains('cho tôi xem') ||
        q.contains('product') ||
        q.contains('item') ||
        q.contains('rau') ||
        q.contains('củ') ||
        q.contains('quả') ||
        q.contains('trái') ||
        q.contains('mushroom') ||
        q.contains('lettuce') ||
        (q.contains('what') && (q.contains('available') || q.contains('stock') || q.contains('have')));

    if (requestsVietnamese) {
      if (q.contains('chào') || q.contains('hi') || q.contains('hello')) {
        answerText = 'Xin chào! Tôi là AI Sprout của HarvestHub. Tôi có thể giúp bạn xem danh mục nông sản, dinh dưỡng, bảo quản và so sánh giá cả!';
      } else if (q.contains('dinh dưỡng') || q.contains('sức khỏe')) {
        category = 'Nutrition';
        answerText = 'Nông sản hữu cơ tươi ngon giàu vitamin và chất xơ. Bổ sung các loại rau củ quả tươi theo mùa giúp tối ưu hóa dinh dưỡng cho gia đình.';
      } else if (q.contains('bảo quản') || q.contains('tủ lạnh')) {
        category = 'Storage';
        answerText = 'Rau xanh nên bọc trong khăn giấy ẩm trước khi để ngăn mát tủ lạnh (4°C). Các loại củ quả nên bảo quản ở nơi khô ráo, thoáng mát.';
      } else if (q.contains('giá') || q.contains('thị trường')) {
        category = 'Market';
        answerText = 'Giá nông sản tại HarvestHub được cung cấp trực tiếp từ các nông trại địa phương, đảm bảo giá cả công bằng và sản phẩm đạt chuẩn hữu cơ.';
      } else {
        answerText = 'Cảm ơn câu hỏi của bạn! Tôi có thể tư vấn chi tiết về các sản phẩm nông sản tươi ngon đang có sẵn tại cửa hàng HarvestHub.';
      }
    } else {
      if (q.contains('hi') || q.contains('hello') || q.contains('hey')) {
        answerText = 'Hello there! I am AI Sprout, your HarvestHub assistant. How can I help you with our fresh produce, nutrition, or store items today?';
      } else if (q.contains('nutrition') || q.contains('vitamin') || q.contains('health')) {
        category = 'Nutrition';
        answerText = 'Fresh organic vegetables are rich in essential vitamins A, C, and K. Eating locally harvested produce maximizes nutritional intake!';
      } else if (q.contains('store') || q.contains('preserve') || q.contains('keep') || q.contains('fresh')) {
        category = 'Storage';
        answerText = 'Store leafy greens in damp cloth bags inside the crisp drawer at 4°C. Keep produce like tomatoes and potatoes at cool room temperature.';
      } else if (q.contains('season') || q.contains('harvest') || q.contains('month')) {
        category = 'Seasonal';
        answerText = 'Fresh strawberries, organic bell peppers, and leafy greens are currently in peak harvest season for optimal taste and nutrition!';
      } else if (q.contains('price') || q.contains('market') || q.contains('cost')) {
        category = 'Market';
        answerText = 'HarvestHub prices come directly from local organic farms, offering fair market rates without middleman markups.';
      } else {
        answerText = 'Thank you for reaching out! HarvestHub connects local organic farmers with customers. Feel free to ask about available produce, nutrition, or store options.';
      }
    }

    if (isProductQuery && liveProducts != null && liveProducts.isNotEmpty) {
      final available = liveProducts.where((p) => p.isActive && p.stockQty > 0).take(3).toList();
      if (available.isNotEmpty) {
        for (final p in available) {
          pinnedIds.add(p.id);
        }
        final namesList = available.map((p) => '${p.name} (\$${(p.price / 100).toStringAsFixed(2)}/${p.unit})').join(', ');
        if (requestsVietnamese) {
          answerText = 'Cửa hàng HarvestHub hiện đang có sẵn các sản phẩm tươi ngon: $namesList. Bạn có thể xem thông tin chi tiết các món bên dưới!';
        } else {
          answerText = 'HarvestHub store currently has the following fresh produce in stock: $namesList. Check out the details below!';
        }
      }
    }

    return AiResponseResult(
      text: answerText,
      category: category,
      pinnedProductIds: pinnedIds,
      modelUsed: 'Local Fallback',
    );
  }

  String answer(String query) {
    return _getLocalFallbackAnswer(query).text;
  }
}
