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
  final bool isSystemError;
  final String? violationType;
  final String? productName;
  final String? categoryId;
  final String reason;

  const ProduceInspectionResult({
    required this.isProduce,
    this.isSafetyViolation = false,
    this.isSystemError = false,
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
    violationType: 'non_produce',
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
    'sex', 'porn', 'nude', 'khỏa thân', 'khoa than', 'khiêu dâm', 'khieu dam',
    'gái gọi', 'gai goi', 'kích dục', 'kich duc', 'dâm', 'dam duc', 'bdsm',

    'đụ', 'du ma', 'địt', 'dit me', 'lồn', 'lon me', 'cặc', 'buồi', 'đĩ',
    'vcl', 'dcm', 'fuck', 'shit', 'bitch', 'asshole', 'bastard',

    'súng', 'sung dan', 'đạn', 'thuốc nổ', 'thuoc no', 'lựu đạn', 'luu dan',
    'khủng bố', 'khung bo', 'chém người', 'chem nguoi', 'giết người', 'giet nguoi',
    'dao găm', 'dao gam', 'vũ khí', 'vu khi', 'weapon', 'gun', 'bomb', 'explosive',
    'terrorist', 'assassinate',

    'ma túy', 'ma tuy', 'cần sa', 'can sa', 'heroin', 'thuốc lắc', 'thuoc lac',
    'ma túy đá', 'ma tuy da', 'bóng cười', 'bong cuoi', 'vape lậu', 'thuoc phien',
    'narcotics', 'cannabis', 'cocaine', 'methamphetamine', 'ecstasy',

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
      'papaya', 'dragonfruit', 'avocado', 'grape', 'lemon', 'lime', 'lựu', 'luu', 'pomegranate',
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

  String? detectSuggestedCategory(String name, String description) {
    final combined = '${name.toLowerCase()} ${description.toLowerCase()}';
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        final regex = RegExp('(^|\\s|[.,!?;])${RegExp.escape(kw)}(\$|\\s|[.,!?;])');
        if (regex.hasMatch(combined)) {
          return entry.key;
        }
      }
    }
    return null;
  }

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

    if (cleanDesc.length < 15) {
      return const ModerationResult(
        isApproved: false,
        violationType: 'invalid_description',
        message: 'Product description is required and must be at least 15 characters long to provide clear quality and origin details.',
        severity: 'low',
      );
    }

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

  Future<ProduceInspectionResult> inspectProduceImage({
    required File imageFile,
  }) async {
    String lastSystemError = 'Could not connect to AI service. Please check your network and try again.';
    try {
      final apiKey = await FaqService.resolveApiKey(firestore: _firestore);
      if (apiKey.isEmpty) {
        return const ProduceInspectionResult(
          isProduce: false,
          isSystemError: true,
          violationType: 'system_error',
          reason: 'AI service API key is not configured. Please check system settings.',
        );
      }
      final client = http.Client();
      try {
        final models = [
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
          'gemini-2.0-flash',
          'gemini-2.0-flash-lite',
          'gemini-3.0-flash',
          'gemini-3.1-flash-lite',
          'gemini-3.6-flash',
          'gemini-3.7-flash',
          'gemini-3.8-flash',
          'gemini-3.5-flash-lite',
          'gemini-2.5-pro',
          'gemini-3.5-flash',
        ];
        for (final model in models) {
          try {
            if (kDebugMode) {
              print('inspectProduceImage trying model $model');
            }
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
You are the HarvestHub Agricultural Produce and Community Safety Inspector.
Determine whether this image is agricultural produce or food crops.

1. COMMUNITY SAFETY (STRICT ZERO TOLERANCE):
If the image shows weapons, firearms, handguns, rifles, bullets, ammunition, explosives, knives, physical violence, blood, gore, illicit drugs, or sexually explicit/NSFW content:
{
  "isProduce": false,
  "isSafetyViolation": true,
  "violationType": "weapons_or_violence",
  "productName": null,
  "categoryId": null,
  "reason": "Image contains prohibited weapons, violence, or sensitive material violating community safety standards."
}

2. AGRICULTURAL PRODUCE CHECK:
- If this image shows ANY agricultural produce, fresh food crops, fruits (such as pomegranate, watermelon, guava, apple, orange, banana, strawberry, grape, etc.), vegetables, corn, mushrooms, herbs, spices, grains, honey, or farm eggs:
{
  "isProduce": true,
  "isSafetyViolation": false,
  "violationType": null,
  "productName": "<Clean English produce name, e.g. Corn, Pomegranate, Watermelon, Carrot>",
  "categoryId": "<fruits | vegetables | berries | mushrooms | herbs | grains>",
  "reason": "Agricultural produce verified."
}
- If this image is clearly NOT agricultural produce (such as electronics, laptops, phones, vehicles, cars, furniture, clothes, buildings, memes, non-food objects):
{
  "isProduce": false,
  "isSafetyViolation": false,
  "violationType": "non_produce",
  "productName": null,
  "categoryId": null,
  "reason": "Image does not appear to be agricultural produce."
}

Return ONLY valid JSON.
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
              ).timeout(const Duration(seconds: 15));

              if (response.statusCode == 200) {
                final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;

                final promptFeedback = jsonBody['promptFeedback'] as Map<String, dynamic>?;
                if (promptFeedback != null && promptFeedback['blockReason'] != null) {
                  return const ProduceInspectionResult(
                    isProduce: false,
                    isSafetyViolation: true,
                    isSystemError: false,
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
                      isSystemError: false,
                      violationType: 'weapons_or_violence',
                      reason: 'Image violates community safety guidelines: prohibited weapons, firearms, violence, or sensitive material.',
                    );
                  }

                  final content = firstCandidate['content'] as Map<String, dynamic>?;
                  final responseParts = content?['parts'] as List<dynamic>?;
                  if (responseParts != null && responseParts.isNotEmpty) {
                    final rawText = responseParts.first['text'] as String?;
                    if (rawText != null && rawText.isNotEmpty) {
                      final start = rawText.indexOf('{');
                      final end = rawText.lastIndexOf('}');
                      if (start != -1 && end != -1 && end > start) {
                        final cleanJson = rawText.substring(start, end + 1);
                        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
                        final isProduce = parsed['isProduce'] as bool? ?? false;
                        final isSafety = parsed['isSafetyViolation'] as bool? ?? false;
                        final violationType = parsed['violationType'] as String?;
                        final reason = parsed['reason'] as String? ?? (isProduce ? 'Agricultural produce verified.' : 'Image does not appear to be agricultural produce.');

                        return ProduceInspectionResult(
                          isProduce: isProduce,
                          isSafetyViolation: isSafety,
                          isSystemError: false,
                          violationType: isSafety ? 'weapons_or_violence' : (isProduce ? null : (violationType ?? 'non_produce')),
                          productName: parsed['productName'] as String?,
                          categoryId: parsed['categoryId'] as String?,
                          reason: reason,
                        );
                      }
                    }
                  }
                }
              } else if (response.statusCode == 400 || response.statusCode == 422) {
                final bodyLower = response.body.toLowerCase();
                if (bodyLower.contains('safety') || bodyLower.contains('harm') || bodyLower.contains('violation')) {
                  return const ProduceInspectionResult(
                    isProduce: false,
                    isSafetyViolation: true,
                    isSystemError: false,
                    violationType: 'weapons_or_violence',
                    reason: 'Image was blocked due to community safety violations (weapons, violence, or illicit content).',
                  );
                } else {
                  lastSystemError = 'AI verification service returned Bad Request (${response.statusCode}).';
                  if (kDebugMode) {
                    print('Gemini model $model returned error ${response.statusCode}: ${response.body}');
                  }
                }
              } else if (response.statusCode == 429) {
                lastSystemError = 'AI service rate limit reached. Please wait a moment and retry.';
                if (kDebugMode) {
                  print('Gemini model $model returned 429 rate limit');
                }
              } else if (response.statusCode == 403 || response.statusCode == 401) {
                lastSystemError = 'AI service authorization error (${response.statusCode}). Please contact administrator.';
                if (kDebugMode) {
                  print('Gemini model $model returned auth error ${response.statusCode}');
                }
              } else if (response.statusCode >= 500) {
                lastSystemError = 'AI server temporarily unavailable (${response.statusCode}). Please retry later.';
                if (kDebugMode) {
                  print('Gemini model $model returned server error ${response.statusCode}');
                }
              } else {
                if (kDebugMode) {
                  print('Gemini model $model returned status: ${response.statusCode}');
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('inspectProduceImage error with $model: $e');
            }
            if (e.toString().contains('TimeoutException')) {
              lastSystemError = 'AI verification timed out. Please check your internet connection.';
            } else if (e.toString().contains('SocketException')) {
              lastSystemError = 'Network connection failed. Please check your device internet connection.';
            }
            continue;
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) {
        print('inspectProduceImage general error: $e');
      }
    }
    return ProduceInspectionResult(
      isProduce: false,
      isSystemError: true,
      violationType: 'system_error',
      reason: lastSystemError,
    );
  }

  static bool isProduceNameMatching({
    required String inputName,
    required String detectedProduce,
  }) {
    final cleanInput = _normalizeProduceString(inputName);
    final cleanDetected = _normalizeProduceString(detectedProduce);

    if (cleanInput.isEmpty || cleanDetected.isEmpty) return true;

    if (cleanInput.contains(cleanDetected) || cleanDetected.contains(cleanInput)) {
      return true;
    }

    final inputTokens = cleanInput.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    final detectedTokens = cleanDetected.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    if (inputTokens.intersection(detectedTokens).isNotEmpty) {
      return true;
    }

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
      'corn': ['bap', 'ngo', 'bap ngo', 'trai bap', 'qua ngo', 'corn', 'sweet corn', 'maize', 'bap nep', 'bap my', 'bap ngot'],
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
      'pomegranate': ['luu', 'trai luu', 'qua luu', 'pomegranate'],
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

      final models = ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-3.6-flash', 'gemini-3.8-flash'];

      for (final model in models) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );

          final parts = <Map<String, dynamic>>[];

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
   - root_vegetables: beetroot, beets, carrots, potatoes, radishes, turnips, sweet potatoes, yams, ginger, cassava, etc.
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
                    continue;
                  }
                }
              }
            }
          } else if (response.statusCode == 404 || response.statusCode == 429) {
            continue;
          }
        } catch (_) {
          continue;
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

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

      await NotificationService().sendNotification(
        userId: 'all_admins',
        title: 'Community Guidelines Violation: $productName',
        body: 'Farmer "$farmerName" submitted a product violating policies ($violationType): $reason',
        type: 'COMMUNITY_VIOLATION',
        targetId: docRef.id,
        showInAppPopup: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error reporting violation to admin: $e');
      }
    }
  }
}
