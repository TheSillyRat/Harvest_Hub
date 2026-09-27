/*
 * Share Bottom Sheet Widget
 * Provides single-row horizontally scrollable sharing options for products and farms.
 * Ensures English-only UI text and strict rule compliance.
 */

import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Path;
import 'package:flutter/services.dart';
import 'package:harvesthub_core/harvesthub_core.dart' hide Path;
import 'package:share_plus/share_plus.dart';

enum ShareType { product, farmer }

class _ShareOptionItem {
  final String id;
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color iconColor;
  final bool isGradient;
  final List<Color>? gradientColors;
  final WidgetBuilder? customIconBuilder;

  const _ShareOptionItem({
    required this.id,
    required this.label,
    this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.isGradient = false,
    this.gradientColors,
    this.customIconBuilder,
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

  List<_ShareOptionItem> get _options => [
        const _ShareOptionItem(
          id: 'copy',
          label: 'Copy link',
          icon: Icons.link_rounded,
          backgroundColor: Color(0xFFF0F4F1),
          iconColor: HhColors.primary,
        ),
        const _ShareOptionItem(
          id: 'messenger',
          label: 'Messenger',
          backgroundColor: Color(0xFF0084FF),
          isGradient: true,
          gradientColors: [
            Color(0xFF0078FF),
            Color(0xFF00C6FF),
            Color(0xFFA033FF),
            Color(0xFFFF5280),
          ],
          customIconBuilder: _buildMessengerIcon,
        ),
        const _ShareOptionItem(
          id: 'zalo',
          label: 'Zalo',
          backgroundColor: Color(0xFF0068FF),
          customIconBuilder: _buildZaloIcon,
        ),
        const _ShareOptionItem(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.call_rounded,
          backgroundColor: Color(0xFF25D366),
        ),
        const _ShareOptionItem(
          id: 'facebook',
          label: 'Facebook',
          icon: Icons.facebook_rounded,
          backgroundColor: Color(0xFF1877F2),
        ),
        const _ShareOptionItem(
          id: 'telegram',
          label: 'Telegram',
          icon: Icons.send_rounded,
          backgroundColor: Color(0xFF229ED9),
        ),
        const _ShareOptionItem(
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
        const _ShareOptionItem(
          id: 'more',
          label: 'More',
          icon: Icons.more_horiz_rounded,
          backgroundColor: Color(0xFFEFEFEF),
          iconColor: Colors.black87,
        ),
      ];

  static Widget _buildMessengerIcon(BuildContext context) {
    return const _MessengerIconWidget();
  }

  static Widget _buildZaloIcon(BuildContext context) {
    return const _ZaloIconWidget();
  }

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

    if (option.id == 'more') {
      try {
        await SharePlus.instance.share(ShareParams(text: shareMessage, subject: title));
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: shareMessage));
        if (context.mounted) {
          TopToast.show(context, 'Share message copied to clipboard!');
        }
      }
      return;
    }

    Uri? primaryUri;
    Uri? fallbackUri;

    switch (option.id) {
      case 'messenger':
        primaryUri = Uri.parse('fb-messenger://share/?link=$encodedUrl');
        fallbackUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');
        break;
      case 'zalo':
        primaryUri = Uri.parse('zalo://share?url=$encodedUrl');
        fallbackUri = Uri.parse('https://zalo.me/share?url=$encodedUrl');
        break;
      case 'whatsapp':
        primaryUri = Uri.parse('whatsapp://send?text=$encodedMessage');
        fallbackUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage');
        break;
      case 'facebook':
        primaryUri = Uri.parse('fb://faceweb/f?href=$encodedUrl');
        fallbackUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');
        break;
      case 'telegram':
        primaryUri = Uri.parse('tg://msg_url?url=$encodedUrl&text=$encodedMessage');
        fallbackUri = Uri.parse('https://t.me/share/url?url=$encodedUrl&text=$encodedMessage');
        break;
      case 'instagram':
        primaryUri = Uri.parse('instagram://');
        fallbackUri = Uri.parse('https://www.instagram.com/');
        break;
    }

    bool launched = false;
    if (primaryUri != null) {
      try {
        if (await canLaunchUrl(primaryUri)) {
          launched = await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && fallbackUri != null) {
      try {
        if (await canLaunchUrl(fallbackUri)) {
          launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        launched = false;
      }
    }

    /* Fallback to system share sheet to ensure user navigation never gets stuck */
    if (!launched) {
      try {
        await SharePlus.instance.share(ShareParams(text: shareMessage, subject: title));
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: shareMessage));
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
                            child: item.customIconBuilder != null
                                ? item.customIconBuilder!(context)
                                : Icon(
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

class _MessengerIconWidget extends StatelessWidget {
  const _MessengerIconWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CustomPaint(
          painter: _MessengerIconPainter(),
        ),
      ),
    );
  }
}

class _MessengerIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    /* Main chat bubble */
    final bubblePath = ui.Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.46),
            width: w * 0.94,
            height: h * 0.80,
          ),
          Radius.circular(w * 0.40),
        ),
      );

    /* Bottom-left bubble tail */
    final tailPath = ui.Path()
      ..moveTo(w * 0.22, h * 0.70)
      ..lineTo(w * 0.08, h * 0.94)
      ..lineTo(w * 0.38, h * 0.82)
      ..close();

    final fullBubble = ui.Path.combine(ui.PathOperation.union, bubblePath, tailPath);

    /* Center lightning bolt */
    final boltPath = ui.Path()
      ..moveTo(w * 0.57, h * 0.22)
      ..lineTo(w * 0.35, h * 0.50)
      ..lineTo(w * 0.49, h * 0.50)
      ..lineTo(w * 0.43, h * 0.70)
      ..lineTo(w * 0.65, h * 0.42)
      ..lineTo(w * 0.51, h * 0.42)
      ..close();

    /* Subtract lightning bolt to let gradient shine through */
    final result = ui.Path.combine(ui.PathOperation.difference, fullBubble, boltPath);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(result, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZaloIconWidget extends StatelessWidget {
  const _ZaloIconWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Zalo',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.5,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
    );
  }
}
