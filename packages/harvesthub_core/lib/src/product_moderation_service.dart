/*
 * Product Moderation Service
 * Inspects product listings for community guidelines, profanity, sensitive content,
 * category semantic alignment, and AI image safety.
 * Zero single-line comments rule strictly enforced.
 */

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'faq.dart';
import 'notification_service.dart';

class ModerationResult {
  final bool isApproved;
  final String? violationType;
  final String message;
  final String? suggestedCategoryId;
  final String? suggestedCategoryName;
  final String severity;
  final List<String> detectedKeywords;

  const ModerationResult({
    required this.isApproved,
    this.violationType,
    required this.message,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.severity = 'none',
    this.detectedKeywords = const [],
  });

  bool get isCategoryMismatch => violationType == 'category_mismatch';
  bool get isSevere => severity == 'high';

  static const approved = ModerationResult(
    isApproved: true,
    message: 'Product listing complies with community guidelines.',
  );
}

class ProduceInspectionResult {
  final bool isProduce;
  final bool isSafetyViolation;
  final String? violationType;
  final String? productName;
  final String? categoryId;
  final String reason;

  const ProduceInspectionResult({
    required this.isProduce,
    this.isSafetyViolation = false,
    this.violationType,
    this.productName,
    this.categoryId,
    required this.reason,
  });

  static const verified = ProduceInspectionResult(
    isProduce: true,
    reason: 'Verified agricultural produce',
  );

  static const rejectedNonProduce = ProduceInspectionResult(
    isProduce: false,
    reason: 'Image is not related to agricultural produce',
  );

  static const rejectedSafety = ProduceInspectionResult(
    isProduce: false,
    isSafetyViolation: true,
    violationType: 'weapons_or_violence',
    reason: 'Image violates community safety guidelines (prohibited weapons, violence, or sensitive content)',
  );
}

class ProductModerationService {
  final FirebaseFirestore? _db;

  ProductModerationService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;

  static const List<String> _prohibitedKeywords = [
    /* Adult & NSFW */
    'sex', 'porn', 'nude', 'khỏa thân', 'khoa than', 'khiêu dâm', 'khieu dam',
    'gái gọi', 'gai goi', 'kích dục', 'kich duc', 'dâm', 'dam duc', 'bdsm',

    /* Profanity & Insults */
    'đụ', 'du ma', 'địt', 'dit me', 'lồn', 'lon me', 'cặc', 'buồi', 'đĩ',
    'vcl', 'dcm', 'fuck', 'shit', 'bitch', 'asshole', 'bastard',

    /* Weapons, Terrorism & Violence */
    'súng', 'sung dan', 'đạn', 'thuốc nổ', 'thuoc no', 'lựu đạn', 'luu dan',
    'khủng bố', 'khung bo', 'chém người', 'chem nguoi', 'giết người', 'giet nguoi',
    'dao găm', 'dao gam', 'vũ khí', 'vu khi', 'weapon', 'gun', 'bomb', 'explosive',
    'terrorist', 'assassinate',

    /* Drugs & Contraband */
    'ma túy', 'ma tuy', 'cần sa', 'can sa', 'heroin', 'thuốc lắc', 'thuoc lac',
    'ma túy đá', 'ma tuy da', 'bóng cười', 'bong cuoi', 'vape lậu', 'thuoc phien',
    'narcotics', 'cannabis', 'cocaine', 'methamphetamine', 'ecstasy',

    /* Gambling & Scam */
    'cá độ', 'ca do', 'cờ bạc', 'co bac', 'lô đề', 'lo de', 'tài xỉu', 'tai xiu',
    'cho vay nặng lãi', 'vay nong', 'hack acc', 'scam', 'lừa đảo', 'lua dao',
  ];

  static const Map<String, List<String>> _categoryKeywords = {
    'fruits': [
      'thơm', 'thom', 'dứa', 'dua', 'ổi', 'oi', 'xoài', 'xoai', 'chuối', 'chuoi',
      'cam', 'quýt', 'quyt', 'bưởi', 'buoi', 'dưa hấu', 'dua hau', 'sầu riêng',
      'sau rieng', 'mít', 'mit', 'táo', 'tao', 'lê', 'le', 'nho', 'thanh long',
      'đu đủ', 'du du', 'chôm chôm', 'chom chom', 'măng cụt', 'mang cut',
      'bơ', 'bo sáp', 'nhãn', 'nhan', 'vải', 'vai thieu', 'fruit', 'apple',
      'banana', 'orange', 'pineapple', 'mango', 'guava', 'watermelon', 'durian',
      'papaya', 'dragonfruit', 'avocado', 'grape', 'lemon', 'lime',
    ],
    'vegetables': [
      'rau', 'củ', 'cu cai', 'cải', 'cai ngot', 'cai bắp', 'bắp cải', 'bap cai',
      'xà lách', 'xa lach', 'rau muống', 'rau muong', 'mồng tơi', 'mong toi',
      'rau ngót', 'rau ngot', 'súp lơ', 'sup lo', 'cà rốt', 'ca rot', 'khoai tây',
      'khoai tay', 'khoai lang', 'bí đỏ', 'bi do', 'bí đao', 'bi dao', 'khổ qua',
      'kho qua', 'mướp', 'muop', 'dưa leo', 'dua leo', 'dưa chuột', 'dua chuot',
      'đậu cô ve', 'dau co ve', 'vegetable', 'carrot', 'lettuce', 'cabbage',
      'broccoli', 'spinach', 'cucumber', 'potato', 'pumpkin', 'tomato', 'cà chua',
      'ca chua',
    ],
    'berries': [
      'dâu tây', 'dau tay', 'dâu tằm', 'dau tam', 'việt quất', 'viet quat',
      'mâm xôi', 'mam xoi', 'phúc bồn tử', 'phuc bon tu', 'strawberry',
      'blueberry', 'raspberry', 'blackberry', 'cranberry', 'berry',
    ],
    'mushrooms': [
      'nấm', 'nam rom', 'nấm rơm', 'nấm hương', 'nam huong', 'nấm bào ngư',
      'nam bao ngu', 'nấm linh chi', 'nam linh chi', 'nấm đùi gà', 'nam dui ga',
      'nấm kim châm', 'nam kim cham', 'mushroom', 'shiitake', 'fungi',
    ],
    'herbs': [
      'hành lá', 'hanh la', 'ngò rí', 'ngo ri', 'thì là', 'thi la', 'húng quế',
      'hung que', 'bạc hà', 'bac ha', 'tía tô', 'tia to', 'kinh giới', 'kinh gioi',
      'gừng', 'gung', 'sả', 'sa', 'ớt', 'ot', 'tỏi', 'toi', 'tiêu', 'tieu',
      'herb', 'spice', 'mint', 'basil', 'cilantro', 'garlic', 'ginger', 'chili',
      'lemongrass', 'pepper',
    ],
    'grains': [
      'gạo', 'gao', 'nếp', 'nep', 'lúa', 'lua', 'ngô', 'ngo', 'bắp hạt',
      'đậu phộng', 'dau phong', 'lạc', 'đậu xanh', 'dau xanh', 'đậu đen', 'dau den',
      'đậu đỏ', 'dau do', 'yến mạch', 'yen mach', 'mè', 'vừng', 'hạt điều',
      'hat dieu', 'hạt sen', 'hat sen', 'grain', 'rice', 'corn', 'oat', 'bean',
      'peanut', 'cashew', 'seed', 'wheat',
    ],
  };

  static const Map<String, String> _categoryDisplayNames = {
    'fruits': 'Fruits',
    'vegetables': 'Vegetables',
    'berries': 'Berries',
    'mushrooms': 'Mushrooms',
    'herbs': 'Herbs & Spices',
    'grains': 'Grains & Nuts',
  };

  /* Local fast inspection for sensitive keywords */
  List<String> findSensitiveKeywords(String text) {
    final lower = text.toLowerCase();
    final matched = <String>[];
    for (final kw in _prohibitedKeywords) {
      if (lower.contains(kw)) {
        matched.add(kw);
      }
    }
    return matched;
  }

  /* Local check for obvious category mismatch */
  String? detectSuggestedCategory(String name, String description) {
    final combined = '${name.toLowerCase()} ${description.toLowerCase()}';
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        /* Check word boundary match to avoid false partial substring positives */
        final regex = RegExp('(^|\\s|[.,!?;])${RegExp.escape(kw)}(\$|\\s|[.,!?;])');
        if (regex.hasMatch(combined)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /* Primary moderation pipeline combining local rules and Gemini AI */
  Future<ModerationResult> moderateProduct({
    required String name,
    required String description,
    required String categoryId,
    List<File>? imageFiles,
    String? existingImageUrl,
    List<String>? existingImageUrls,
  }) async {
    final cleanName = name.trim();
    final cleanDesc = description.trim();

    /* Step 1: Validate description requirement and minimum length */
    if (cleanDesc.length < 15) {
      return const ModerationResult(
        isApproved: false,
        violationType: 'invalid_description',
        message: 'Product description is required and must be at least 15 characters long to provide clear quality and origin details.',
        severity: 'low',
      );
    }

    /* Step 2: Instant local keyword blacklist screening */
    final textKeywords = [
      ...findSensitiveKeywords(cleanName),
      ...findSensitiveKeywords(cleanDesc),
    ];
    if (textKeywords.isNotEmpty) {
      return ModerationResult(
        isApproved: false,
        violationType: 'sensitive_keywords',
        message: 'Product contains prohibited or sensitive terms (${textKeywords.toSet().join(", ")}). Please review community standards.',
        severity: 'high',
        detectedKeywords: textKeywords.toSet().toList(),
      );
    }

    /* Step 3: Local category semantic check */
    final localSuggestedCat = detectSuggestedCategory(cleanName, cleanDesc);
    if (localSuggestedCat != null && localSuggestedCat != categoryId) {
      final currentName = _categoryDisplayNames[categoryId] ?? categoryId;
      final suggestedName = _categoryDisplayNames[localSuggestedCat] ?? localSuggestedCat;
      return ModerationResult(
        isApproved: false,
        violationType: 'category_mismatch',
        message: 'Your product "$cleanName" appears to belong in "$suggestedName" rather than "$currentName". Please choose the appropriate category.',
        suggestedCategoryId: localSuggestedCat,
        suggestedCategoryName: suggestedName,
        severity: 'medium',
      );
    }

    /* Step 4: AI Gemini Deep Audit (Multimodal Vision & Semantics) */
    try {
      final apiKey = await FaqService.resolveApiKey(firestore: _firestore);
      if (apiKey.isNotEmpty) {
        final aiResult = await _auditWithGemini(
          apiKey: apiKey,
          name: cleanName,
          description: cleanDesc,
          categoryId: categoryId,
          imageFiles: imageFiles,
          existingImageUrl: existingImageUrl,
          existingImageUrls: existingImageUrls,
        );
        if (aiResult != null) {
          return aiResult;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProductModerationService Gemini error: $e');
      }
    }

    return ModerationResult.approved;
  }

  /*
   * Inspect whether an uploaded image complies with community safety standards
   * and is genuine agricultural produce.
   * Zero tolerance for weapons, firearms, ammo, violence, NSFW, or non-produce items.
   */
  Future<ProduceInspectionResult> inspectProduceImage({
    required File imageFile,
  }) async {
    try {
      final apiKey = await FaqService.resolveApiKey(firestore: _firestore);
      if (apiKey.isEmpty) {
        return const ProduceInspectionResult(
          isProduce: false,
          reason: 'Could not connect to vision security verification service.',
        );
      }
      final client = http.Client();
      try {
        final models = ['gemini-3.8-flash', 'gemini-3.7-flash'];
        for (final model in models) {
          try {
            final url = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
            );
            if (await imageFile.exists()) {
              final bytes = await imageFile.readAsBytes();
              final base64Image = base64Encode(bytes);
              final ext = imageFile.path.split('.').last.toLowerCase();
              final mimeType = ext == 'png'
                  ? 'image/png'
                  : ext == 'webp'
                      ? 'image/webp'
                      : 'image/jpeg';
              final parts = [
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Image,
                  }
                },
                {
                  'text': '''
You are the HarvestHub Marketplace Trust & Safety and Agricultural Produce Inspector.
Evaluate this image carefully with ZERO TOLERANCE for policy violations:

RULE 1: COMMUNITY SAFETY STANDARDS (HIGHEST PRIORITY - REJECT IMMEDIATELY)
Inspect for any prohibited or dangerous items:
- Weapons, firearms, handguns, pistols, rifles, ammunition, bullets, magazines, holsters, knives, explosives, military gear
- Violence, blood, gore, physical trauma, hate groups, terrorist material
- Adult content, sexually explicit, nudity, erotic, NSFW
- Illegal drugs, narcotics, weed/cannabis, pills, drug paraphernalia, tobacco/vape
If the image shows ANY of the above, you MUST respond:
{
  "isProduce": false,
  "isSafetyViolation": true,
  "violationType": "weapons_or_violence",
  "productName": null,
  "categoryId": null,
  "reason": "CRITICAL VIOLATION: Image contains prohibited weapons, firearms, ammunition, or violence violating community standards."
}

RULE 2: AGRICULTURAL PRODUCE SCREENING
Is this image genuine, fresh agricultural produce or food crops (fresh fruits, vegetables, berries, mushrooms, culinary herbs, spices, raw grains, honey, farm eggs)?
- If it is electronics (laptops, phones, keyboards, mice, monitors, computers), vehicles, humans/selfies, clothing, furniture, household items, non-food animals, memes, packaging without produce:
{
  "isProduce": false,
  "isSafetyViolation": false,
  "violationType": "non_produce",
  "productName": null,
  "categoryId": null,
  "reason": "Image shows non-produce item and is not related to agricultural produce."
}
- If it IS genuine, fresh agricultural produce:
{
  "isProduce": true,
  "isSafetyViolation": false,
  "violationType": null,
  "productName": "Clean English Produce Name (e.g. 'Watermelon', 'Carrot', 'Shiitake Mushroom', 'Fresh Orange')",
  "categoryId": "fruits" | "vegetables" | "berries" | "mushrooms" | "herbs" | "grains",
  "reason": "Clear agricultural produce detected."
}

Return ONLY valid JSON in this exact schema without any markdown blocks:
{
  "isProduce": boolean,
  "isSafetyViolation": boolean,
  "violationType": string | null,
  "productName": string | null,
  "categoryId": string | null,
  "reason": string
}
''',
                }
              ];
              final response = await client.post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'contents': [
                    {'parts': parts}
                  ],
                  'generationConfig': {
                    'temperature': 0.1,
                    'responseMimeType': 'application/json',
                  },
                }),
              ).timeout(const Duration(seconds: 10));

              if (response.statusCode == 200) {
                final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

                /* Check if prompt or image was blocked by Google Gemini safety filters */
                final promptFeedback = jsonBody['promptFeedback'] as Map<String, dynamic>?;
                if (promptFeedback != null && promptFeedback['blockReason'] != null) {
                  return const ProduceInspectionResult(
                    isProduce: false,
                    isSafetyViolation: true,
                    violationType: 'weapons_or_violence',
                    reason: 'Image blocked by community safety standards: contains prohibited weapons, violence, or sensitive content.',
                  );
                }

                final candidates = jsonBody['candidates'] as List<dynamic>?;
                if (candidates != null && candidates.isNotEmpty) {
                  final firstCandidate = candidates.first as Map<String, dynamic>;
                  final finishReason = firstCandidate['finishReason'] as String?;
                  if (finishReason == 'SAFETY') {
                    return const ProduceInspectionResult(
                      isProduce: false,
                      isSafetyViolation: true,
                      violationType: 'weapons_or_violence',
                      reason: 'Image violates community safety guidelines: prohibited weapons, firearms, violence, or sensitive material.',
                    );
                  }

                  final content = firstCandidate['content'] as Map<String, dynamic>?;
                  final responseParts = content?['parts'] as List<dynamic>?;
                  if (responseParts != null && responseParts.isNotEmpty) {
                    final rawText = responseParts.first['text'] as String?;
                    if (rawText != null && rawText.isNotEmpty) {
                      final parsed = jsonDecode(rawText) as Map<String, dynamic>;
                      return ProduceInspectionResult(
                        isProduce: parsed['isProduce'] as bool? ?? false,
                        isSafetyViolation: parsed['isSafetyViolation'] as bool? ?? false,
                        violationType: parsed['violationType'] as String?,
                        productName: parsed['productName'] as String?,
                        categoryId: parsed['categoryId'] as String?,
                        reason: parsed['reason'] as String? ?? 'Produce inspection complete',
                      );
                    }
                  }
                }
              } else if (response.statusCode == 400 || response.statusCode == 422) {
                final bodyLower = response.body.toLowerCase();
                if (bodyLower.contains('safety') || bodyLower.contains('harm') || bodyLower.contains('violation')) {
                  return const ProduceInspectionResult(
                    isProduce: false,
                    isSafetyViolation: true,
                    violationType: 'weapons_or_violence',
                    reason: 'Image was blocked due to community safety violations (weapons, violence, or illicit content).',
                  );
                }
              }
            }
          } catch (_) {
            /* Try next model in cascade */
            continue;
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) {
        print('inspectProduceImage error: $e');
      }
    }
    return const ProduceInspectionResult(
      isProduce: false,
      reason: 'Could not verify image as agricultural produce. Please upload a clear photo of fresh produce.',
    );
  }

  /*
   * Validates whether user-entered product name matches the produce identified in the photo.
   * Supports bilingual Vietnamese & English synonyms (e.g. Watermelon <-> Dưa hấu).
   */
  static bool isProduceNameMatching({
    required String inputName,
    required String detectedProduce,
  }) {
    final cleanInput = _normalizeProduceString(inputName);
    final cleanDetected = _normalizeProduceString(detectedProduce);

    if (cleanInput.isEmpty || cleanDetected.isEmpty) return true;

    /* Direct substring containment */
    if (cleanInput.contains(cleanDetected) || cleanDetected.contains(cleanInput)) {
      return true;
    }

    /* Word token intersection */
    final inputTokens = cleanInput.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    final detectedTokens = cleanDetected.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    if (inputTokens.intersection(detectedTokens).isNotEmpty) {
      return true;
    }

    /* Bilingual synonym dictionary */
    const produceSynonyms = <String, List<String>>{
      'watermelon': ['dua hau', 'dua', 'watermelon', 'melon'],
      'carrot': ['ca rot', 'carrot', 'cu ca rot'],
      'orange': ['cam', 'trai cam', 'qua cam', 'orange', 'citrus'],
      'apple': ['tao', 'trai tao', 'qua tao', 'apple'],
      'banana': ['chuoi', 'trai chuoi', 'banana'],
      'mango': ['xoai', 'trai xoai', 'mango'],
      'strawberry': ['dau tay', 'dau', 'strawberry', 'berry'],
      'potato': ['khoai tay', 'khoai', 'potato'],
      'tomato': ['ca chua', 'tomato'],
      'onion': ['hanh', 'hanh tay', 'onion'],
      'garlic': ['toi', 'cu toi', 'garlic'],
      'chili': ['ot', 'trai ot', 'chili', 'pepper', 'chili pepper'],
      'mushroom': ['nam', 'nam rom', 'nam huong', 'mushroom', 'shiitake'],
      'grape': ['nho', 'trai nho', 'grape'],
      'lemon': ['chanh', 'trai chanh', 'lemon', 'lime'],
      'corn': ['bap', 'ngo', 'corn', 'maize'],
      'cabbage': ['bap cai', 'cai', 'cabbage'],
      'cucumber': ['dua leo', 'dua chuot', 'cucumber'],
      'pineapple': ['thom', 'dua', 'khom', 'pineapple'],
      'guava': ['oi', 'trai oi', 'guava'],
      'dragon fruit': ['thanh long', 'dragon fruit'],
      'avocado': ['bo', 'trai bo', 'avocado'],
      'papaya': ['du du', 'papaya'],
      'spinach': ['rau bina', 'rau chan vit', 'cai bo xoi', 'spinach'],
      'lettuce': ['xa lach', 'lettuce', 'salad'],
      'pumpkin': ['bi do', 'bi', 'pumpkin', 'squash'],
      'ginger': ['gung', 'cu gung', 'ginger'],
      'rice': ['gao', 'lua', 'rice', 'paddy'],
      'egg': ['trung', 'trung ga', 'trung vit', 'egg', 'eggs'],
      'honey': ['mat ong', 'honey'],
    };

    for (final entry in produceSynonyms.entries) {
      final key = entry.key;
      final syns = entry.value;

      final detectedMatchesGroup = cleanDetected.contains(key) || syns.any((s) => cleanDetected.contains(s));
      if (detectedMatchesGroup) {
        final inputMatchesGroup = cleanInput.contains(key) || syns.any((s) => cleanInput.contains(s));
        if (inputMatchesGroup) {
          return true;
        }
      }
    }

    return false;
  }

  static String _normalizeProduceString(String str) {
    var s = str.toLowerCase().trim();
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var i = 0; i < withDiacritics.length; i++) {
      s = s.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  }

  Future<String?> generateNameFromImage({required File imageFile}) async {
    final inspection = await inspectProduceImage(imageFile: imageFile);
    if (!inspection.isProduce) {
      return null;
    }
    return inspection.productName;
  }

  Future<String?> generateDescriptionFromImages({
    required String productName,
    required String categoryId,
    required List<File> imageFiles,
  }) async {
    try {
      final apiKey = await FaqService.resolveApiKey(firestore: _firestore);
      if (apiKey.isEmpty) return null;
      final client = http.Client();
      try {
        final models = ['gemini-3.8-flash'];
        for (final model in models) {
          try {
            final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
            final parts = <Map<String, dynamic>>[];
            for (final file in imageFiles.take(3)) {
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final base64Image = base64Encode(bytes);
                final ext = file.path.split('.').last.toLowerCase();
                final mimeType = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
                parts.add({
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Image,
                  }
                });
              }
            }
            final promptText = '''
You are a professional agricultural product copywriter for HarvestHub, a Vietnamese fresh produce marketplace.
Based on the product images and details provided, write a clear, honest, and appealing product description.

Product: $productName
Category: $categoryId

CRITICAL PRODUCE GUARD:
If the attached images show electronics, computers, laptops, keyboards, people, or any non-produce item, respond ONLY with the exact text: REJECT_NON_PRODUCE.

DESCRIPTION REQUIREMENTS:
- Write in English
- 2-4 sentences, minimum 50 characters
- Include: freshness/quality indicators, origin hints if visible, taste/texture expectations, serving/usage suggestion
- Do NOT mention price, do NOT use superlatives like "best" or "amazing"
- Focus on real observable qualities from the images
- Natural, farmer-to-customer tone

Return ONLY the description text, no title, no bullet points, no JSON.
''';
            parts.add({'text': promptText});
            final response = await client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts}
                ],
                'generationConfig': {
                  'temperature': 0.7,
                  'responseMimeType': 'text/plain',
                },
              }),
            ).timeout(const Duration(seconds: 12));
            if (response.statusCode == 200) {
              final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
              final candidates = jsonBody['candidates'] as List<dynamic>?;
              if (candidates != null && candidates.isNotEmpty) {
                final content = candidates.first['content'] as Map<String, dynamic>?;
                final responseParts = content?['parts'] as List<dynamic>?;
                if (responseParts != null && responseParts.isNotEmpty) {
                  final rawText = responseParts.first['text'] as String?;
                  if (rawText != null && rawText.isNotEmpty) {
                    if (rawText.contains('REJECT_NON_PRODUCE')) {
                      return null;
                    }
                    return rawText.trim();
                  }
                }
              }
            }
          } catch (_) {
            /* Ignore and try next model */
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) {
        print('generateDescriptionFromImages error: $e');
      }
    }
    return null;
  }

  /* Multi-modal call to Gemini Vision API */
  Future<ModerationResult?> _auditWithGemini({
    required String apiKey,
    required String name,
    required String description,
    required String categoryId,
    List<File>? imageFiles,
    String? existingImageUrl,
    List<String>? existingImageUrls,
  }) async {
    final client = http.Client();
    try {
      final currentCategoryName = _categoryDisplayNames[categoryId] ?? categoryId;

      /*
       * Model cascade order: prefer newest stable Gemini 3.x multimodal models.
       * gemini-3.8-flash   - latest stable, best multimodal vision reasoning
       * gemini-3.7-flash   - previous stable, reliable fallback
       * gemini-3.6-flash   - baseline stable fallback
       * All 1.x and 2.x model ids are deprecated or access-restricted as of late 2026.
       */
      final models = ['gemini-3.8-flash', 'gemini-3.7-flash', 'gemini-3.6-flash'];

      for (final model in models) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );

          final parts = <Map<String, dynamic>>[];

          /* Attach new image upload if provided */
          if (imageFiles != null && imageFiles.isNotEmpty) {
            for (final file in imageFiles.take(3)) {
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final base64Image = base64Encode(bytes);
                final ext = file.path.split('.').last.toLowerCase();
                final mimeType = ext == 'png'
                    ? 'image/png'
                    : ext == 'webp'
                        ? 'image/webp'
                        : 'image/jpeg';
                parts.add({
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Image,
                  }
                });
              }
            }
          } else {
            /* Check existing image URLs */
            final urlsToAudit = <String>{
              if (existingImageUrl != null && existingImageUrl.isNotEmpty)
                existingImageUrl,
              if (existingImageUrls != null)
                ...existingImageUrls.where((u) => u.isNotEmpty),
            }.take(3).toList();

            for (final url in urlsToAudit) {
              try {
                final imageResponse = await client.get(Uri.parse(url))
                    .timeout(const Duration(seconds: 8));
                if (imageResponse.statusCode == 200) {
                  final base64Image = base64Encode(imageResponse.bodyBytes);
                  final urlLower = url.toLowerCase();
                  final mimeType = urlLower.contains('.png')
                      ? 'image/png'
                      : urlLower.contains('.webp')
                          ? 'image/webp'
                          : 'image/jpeg';
                  parts.add({
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Image,
                    }
                  });
                }
              } catch (_) {
                /* Existing image download failed — proceed with remaining parts */
              }
            }
          }

          final imageCount = parts.where((p) => p.containsKey('inlineData')).length;
          final promptText = '''
You are the HarvestHub Agricultural Community Safety Auditor.
Your job is to strictly evaluate a farmer produce listing before it goes live in the marketplace.

PRODUCT DETAILS:
- Product Name: "$name"
- Selected Category: "$categoryId" ($currentCategoryName)
- Description: "$description"

${imageCount > 0 ? '$imageCount image(s) have been provided. You MUST analyze all of them carefully.' : 'No image was provided. Evaluate text only.'}

AUDIT RULES — apply ALL of the following:

1. ADULT / NSFW:
   Reject if the image or text contains pornography, nudity, sexual organs, or any sexually suggestive material.
   → violationType: "nsfw_image"

2. VIOLENCE / TERRORISM:
   Reject if the image or text contains weapons, guns, explosives, blood, gore, terrorist symbols, or intent to harm.
   → violationType: "violence_image"

3. ILLICIT SUBSTANCES:
   Reject if the image or text promotes narcotics, illegal drugs, gambling, contraband, or harmful chemicals.
   → violationType: "prohibited_items"

4. CATEGORY SEMANTIC MATCH (text):
   The product name and description must logically fit the selected category.
   Valid categories:
   - fruits: pineapples, guavas, oranges, apples, bananas, mangoes, watermelons, papayas, dragon fruit, etc.
   - vegetables: lettuces, cabbages, carrots, cucumbers, spinach, tomatoes, sweet potatoes, etc.
   - berries: strawberries, blueberries, raspberries, etc.
   - mushrooms: shiitake, oyster, wood ear, enoki, fungi, etc.
   - herbs: mint, cilantro, garlic, ginger, chili, lemongrass, basil, pepper, etc.
   - grains: rice, corn, oats, beans, peanuts, cashews, seeds, wheat, etc.
   If mismatched, set isApproved: false, violationType: "category_mismatch", and suggest the correct category.

5. IMAGE RELEVANCE & PRODUCT MATCH (image — MOST IMPORTANT if image is present):
   ALL provided images must show the exact product named. If any image does not match the product name "$name", reject it.
   - REJECT if the image shows electronics, devices, laptops, phones, vehicles, people, buildings, text, logos, screenshots, or any non-agricultural object.
   - REJECT if the image is blurry spam, a meme, a stock photo watermark, or visually unrelated to fresh produce.
   - APPROVE only if the images clearly and predominantly show the specific agricultural produce named in the listing.
   → violationType: "irrelevant_image"

6. FINAL DECISION:
   - If ALL rules pass (text is appropriate AND image shows the correct product): isApproved = true, violationType = null, severity = "none".
   - If any rule fails: isApproved = false with the appropriate violationType and severity.

Return ONLY a valid JSON object in this exact schema — no markdown, no extra text, no explanation outside the JSON:
{
  "isApproved": boolean,
  "violationType": null | "sensitive_keywords" | "category_mismatch" | "nsfw_image" | "violence_image" | "prohibited_items" | "irrelevant_image" | "spam_image" | "invalid_description",
  "reason": "Concise English explanation of what was found and why it was approved or rejected",
  "suggestedCategoryId": null | "fruits" | "vegetables" | "berries" | "mushrooms" | "herbs" | "grains",
  "suggestedCategoryName": null | "Fruits" | "Vegetables" | "Berries" | "Mushrooms" | "Herbs & Spices" | "Grains & Nuts",
  "severity": "none" | "low" | "medium" | "high"
}
''';

          parts.add({'text': promptText});

          final response = await client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': parts}
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
              },
            }),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

            /* Check if prompt or image was blocked by safety filters */
            final promptFeedback = jsonBody['promptFeedback'] as Map<String, dynamic>?;
            if (promptFeedback != null && promptFeedback['blockReason'] != null) {
              return const ModerationResult(
                isApproved: false,
                violationType: 'violence_image',
                message: 'Listing violates community safety standards: prohibited weapons, violence, or sensitive content.',
                severity: 'high',
              );
            }

            final candidates = jsonBody['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final firstCandidate = candidates.first as Map<String, dynamic>;
              final finishReason = firstCandidate['finishReason'] as String?;
              if (finishReason == 'SAFETY') {
                return const ModerationResult(
                  isApproved: false,
                  violationType: 'violence_image',
                  message: 'Listing violates community safety standards: prohibited weapons, violence, or sensitive content.',
                  severity: 'high',
                );
              }

              final content = firstCandidate['content'] as Map<String, dynamic>?;
              final responseParts = content?['parts'] as List<dynamic>?;
              if (responseParts != null && responseParts.isNotEmpty) {
                final rawText = responseParts.first['text'] as String?;
                if (rawText != null && rawText.isNotEmpty) {
                  try {
                    final parsed = jsonDecode(rawText) as Map<String, dynamic>;
                    final isApproved = parsed['isApproved'] as bool? ?? true;
                    final violationType = parsed['violationType'] as String?;
                    final reason = parsed['reason'] as String? ?? 'Moderation review complete.';
                    final suggestedCatId = parsed['suggestedCategoryId'] as String?;
                    final suggestedCatName = parsed['suggestedCategoryName'] as String?;
                    final severity = parsed['severity'] as String? ?? 'none';

                    /*
                     * Consistency guard: if AI returns isApproved=true but also
                     * populates a violationType, treat it as a violation to prevent
                     * policy bypass due to an inconsistent model response.
                     */
                    final effectiveApproved = isApproved && (violationType == null || violationType.isEmpty);

                    return ModerationResult(
                      isApproved: effectiveApproved,
                      violationType: violationType,
                      message: reason,
                      suggestedCategoryId: suggestedCatId,
                      suggestedCategoryName: suggestedCatName,
                      severity: effectiveApproved ? 'none' : severity,
                    );
                  } catch (_) {
                    /* JSON parse failed for this model response, try next model */
                    continue;
                  }
                }
              }
            }
          } else if (response.statusCode == 404 || response.statusCode == 429) {
            /* Model not found or rate limited — try next model in cascade */
            continue;
          }
        } catch (_) {
          /* Network error or timeout — try next model in cascade */
          continue;
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  /* Log violation to Firestore and notify Platform Admins */
  Future<void> reportViolationToAdmin({
    required String farmerId,
    required String farmerName,
    required String productName,
    required String violationType,
    required String reason,
    String? imageUrl,
    String severity = 'high',
  }) async {
    try {
      final docRef = await _firestore.collection('product_moderation_logs').add({
        'farmerId': farmerId,
        'farmerName': farmerName,
        'productName': productName,
        'violationType': violationType,
        'reason': reason,
        'imageUrl': imageUrl,
        'severity': severity,
        'status': 'PENDING_ADMIN_ACTION',
        'createdAt': FieldValue.serverTimestamp(),
      });

      /* Send high-priority alert to all Platform Admins */
      await NotificationService().sendNotification(
        userId: 'all_admins',
        title: 'Community Guidelines Violation: $productName',
        body: 'Farmer "$farmerName" submitted a product violating policies ($violationType): $reason',
        type: 'COMMUNITY_VIOLATION',
        targetId: docRef.id,
        showInAppPopup: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error reporting violation to admin: $e');
      }
    }
  }
}
