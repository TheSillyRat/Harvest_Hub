import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  /// Opens Google Maps with driving directions to the given coordinates or address.
  /// Falls back to search query if coordinates are absent, and tries multiple URI schemes (geo:, https:)
  static Future<bool> openDirections({
    double? latitude,
    double? longitude,
    String? address,
    String? label,
    BuildContext? context,
  }) async {
    final hasCoords = latitude != null &&
        longitude != null &&
        (latitude.abs() > 0.0001 || longitude.abs() > 0.0001);

    final cleanAddress = address?.trim() ?? '';
    final placeLabel = (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : (cleanAddress.isNotEmpty ? cleanAddress : 'Farm Pickup Hub');

    final List<Uri> urisToTry = [];

    if (hasCoords) {
      // 1. Google Maps directions URL (Universal web & deep link)
      urisToTry.add(Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
      ));
      // 2. geo intent (Direct to Android Google Maps app)
      final encodedLabel = Uri.encodeComponent(placeLabel);
      urisToTry.add(Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)'));
      urisToTry.add(Uri.parse('https://maps.google.com/?daddr=$latitude,$longitude'));
    } else if (cleanAddress.isNotEmpty) {
      final encodedQuery = Uri.encodeComponent(cleanAddress);
      urisToTry.add(Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedQuery'));
      urisToTry.add(Uri.parse('geo:0,0?q=$encodedQuery'));
      urisToTry.add(Uri.parse('https://maps.google.com/?q=$encodedQuery'));
    }

    if (urisToTry.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm address or pickup location is not available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    for (final uri in urisToTry) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } catch (_) {
        try {
          final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launched) return true;
        } catch (_) {}
      }
    }

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open map app. Please ensure Google Maps or a web browser is installed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
