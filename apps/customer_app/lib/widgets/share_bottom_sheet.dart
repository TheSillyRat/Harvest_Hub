/*
 * Share Bottom Sheet Widget
 * Provides single-row horizontally scrollable sharing options for products and farms.
 * Ensures English-only UI text and strict rule compliance.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

enum ShareType { product, farmer }

class _ShareOptionItem {
  final String id;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final bool isGradient;
  final List<Color>? gradientColors;

  const _ShareOptionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.isGradient = false,
    this.gradientColors,
  });
}

class ShareBottomSheet extends StatelessWidget {
  final ShareType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;

  const ShareBottomSheet({
    super.key,
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
  });

  String get shareUrl {
    if (type == ShareType.product) {
      return 'https://harvesthub.app/product/id=$id';
    } else {
      return 'https://harvesthub.app/farmer/id=$id';
    }
  }

  String get shareMessage {
    return 'Check out $title on HarvestHub! $shareUrl';
  }

  static Future<void> show({
    required BuildContext context,
    required ShareType type,
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShareBottomSheet(
        type: type,
        id: id,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
      ),
    );
  }

  List<_ShareOptionItem> get _options => const [
        _ShareOptionItem(
          id: 'copy',
          label: 'Copy link',
          icon: Icons.link_rounded,
          backgroundColor: Color(0xFFF0F4F1),
          iconColor: HhColors.primary,
        ),
        _ShareOptionItem(
          id: 'messenger',
          label: 'Messenger',
          icon: Icons.chat_bubble_rounded,
          backgroundColor: Color(0xFF0084FF),
        ),
        _ShareOptionItem(
          id: 'zalo',
          label: 'Zalo',
          icon: Icons.message_rounded,
          backgroundColor: Color(0xFF0068FF),
        ),
        _ShareOptionItem(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.phone_android_rounded,
          backgroundColor: Color(0xFF25D366),
        ),
        _ShareOptionItem(
          id: 'facebook',
          label: 'Facebook',
          icon: Icons.facebook_rounded,
          backgroundColor: Color(0xFF1877F2),
        ),
        _ShareOptionItem(
          id: 'telegram',
          label: 'Telegram',
          icon: Icons.send_rounded,
          backgroundColor: Color(0xFF229ED9),
        ),
        _ShareOptionItem(
          id: 'instagram',
          label: 'Instagram',
          icon: Icons.camera_alt_rounded,
          backgroundColor: Color(0xFFE4405F),
          isGradient: true,
          gradientColors: [
            Color(0xFF833AB4),
            Color(0xFFFD1D1D),
            Color(0xFFFCB045),
          ],
        ),
        _ShareOptionItem(
          id: 'more',
          label: 'More',
          icon: Icons.more_horiz_rounded,
          backgroundColor: Color(0xFFEFEFEF),
          iconColor: Colors.black87,
        ),
      ];

  Future<void> _onOptionTapped(BuildContext context, _ShareOptionItem option) async {
    Navigator.of(context).pop();
    final encodedUrl = Uri.encodeComponent(shareUrl);
    final encodedMessage = Uri.encodeComponent(shareMessage);

    if (option.id == 'copy') {
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (context.mounted) {
        TopToast.show(context, 'Link copied to clipboard!');
      }
      return;
    }

    Uri? targetUri;
    switch (option.id) {
      case 'messenger':
        targetUri = Uri.parse('https://www.facebook.com/dialog/share?app_id=123456789&href=$encodedUrl');
        break;
      case 'zalo':
        targetUri = Uri.parse('https://zalo.me/share?url=$encodedUrl');
        break;
      case 'whatsapp':
        targetUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage');
        break;
      case 'facebook':
        targetUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');
        break;
      case 'telegram':
        targetUri = Uri.parse('https://t.me/share/url?url=$encodedUrl&text=${Uri.encodeComponent(title)}');
        break;
      case 'instagram':
        targetUri = Uri.parse('https://www.instagram.com/');
        break;
      case 'more':
        await Clipboard.setData(ClipboardData(text: shareMessage));
        if (context.mounted) {
          TopToast.show(context, 'Share message copied to clipboard!');
        }
        return;
    }

    if (targetUri != null) {
      try {
        final launched = await launchUrl(targetUri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await Clipboard.setData(ClipboardData(text: shareUrl));
          if (context.mounted) {
            TopToast.show(context, 'Link copied to clipboard!');
          }
        }
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: shareUrl));
        if (context.mounted) {
          TopToast.show(context, 'Link copied to clipboard!');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share with friends & family',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
                IconButton(
                  tooltip: 'Close share options',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: HhColors.text, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = _options[index];
                  return InkWell(
                    onTap: () => _onOptionTapped(context, item),
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.isGradient ? null : item.backgroundColor,
                              gradient: item.isGradient
                                  ? LinearGradient(
                                      colors: item.gradientColors!,
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              color: item.iconColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HhColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
