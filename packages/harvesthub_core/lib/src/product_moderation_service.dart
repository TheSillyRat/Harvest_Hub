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
    File? imageFile,
    String? existingImageUrl,
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
          imageFile: imageFile,
          existingImageUrl: existingImageUrl,
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

  /* Multi-modal call to Gemini Vision API */
  Future<ModerationResult?> _auditWithGemini({
    required String apiKey,
    required String name,
    required String description,
    required String categoryId,
    File? imageFile,
    String? existingImageUrl,
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
          if (imageFile != null && await imageFile.exists()) {
            final bytes = await imageFile.readAsBytes();
            final base64Image = base64Encode(bytes);
            final ext = imageFile.path.split('.').last.toLowerCase();
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
          } else if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
            /*
             * Attempt to download and embed existing product image for re-audit.
             * If network fetch fails, continue without image (text-only audit).
             */
            try {
              final imageResponse = await client.get(Uri.parse(existingImageUrl))
                  .timeout(const Duration(seconds: 8));
              if (imageResponse.statusCode == 200) {
                final base64Image = base64Encode(imageResponse.bodyBytes);
                final urlLower = existingImageUrl.toLowerCase();
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
              /* Existing image download failed — proceed with text-only audit */
            }
          }

          final promptText = '''
You are the HarvestHub Agricultural Community Safety Auditor.
Evaluate this farmer produce listing for strict compliance with our platform community guidelines:

PRODUCT DETAILS:
- Name: "$name"
- Selected Category: "$categoryId" ($currentCategoryName)
- Description: "$description"

AUDIT RULES:
1. Adult / NSFW: Reject any pornography, nudity, sexual organs, or suggestive content in text or image.
2. Violence / Terrorism: Reject any weapons, guns, explosives, blood, violence, terror symbols, attack intent.
3. Illicit Substances: Reject any narcotics, drugs, gambling promotions, contraband, non-organic poisons.
4. Category Semantic Match: Ensure the product is logically grouped into the selected category.
   Standard categories:
   - fruits (fruits: pineapples, guavas, oranges, apples, bananas, mangoes, etc.)
   - vegetables (vegetables: lettuces, cabbages, carrots, cucumbers, spinach, tomatoes, etc.)
   - berries (strawberries, blueberries, raspberries, etc.)
   - mushrooms (mushrooms, edible fungi)
   - herbs (herbs and spices: mint, cilantro, garlic, ginger, chili, lemongrass, pepper, etc.)
   - grains (grains, nuts, seeds, rice, corn, beans, oats, peanuts, cashews, etc.)
   If the product is clearly in the wrong category (e.g. pineapple labeled as vegetable), set isApproved: false and violationType: "category_mismatch".
5. Image Authenticity: If an image is provided, ensure it represents real agricultural or food produce.
   Reject: unrelated spam, malware screenshots, meme graphics, dangerous objects, non-food items.
6. If no policy violation is found in either text or image, set isApproved: true and violationType: null.

Return ONLY a valid JSON object in this exact schema without any markdown codeblocks or extra text:
{
  "isApproved": boolean,
  "violationType": null | "sensitive_keywords" | "category_mismatch" | "nsfw_image" | "violence_image" | "prohibited_items" | "spam_image" | "invalid_description",
  "reason": "English explanation of audit result",
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
            final candidates = jsonBody['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates.first['content'] as Map<String, dynamic>?;
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
