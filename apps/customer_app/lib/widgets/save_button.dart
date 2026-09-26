import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class SaveButton extends StatelessWidget {
  final SavedKind kind;
  final String itemId;
  final bool allowSave;
  final bool iconOnly;

  const SaveButton({
    super.key,
    required this.kind,
    required this.itemId,
    this.allowSave = true,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedItemsController?>();
    final selected = saved?.contains(kind, itemId) ?? false;
    final busy = saved?.pending(kind, itemId) ?? false;
    final failed = saved?.failed(kind) ?? false;
    final loading = saved?.signedIn == true && !saved!.loaded(kind) && !failed;
    final isProduct = kind == SavedKind.product;
    final label = failed
        ? 'Retry saved items'
        : isProduct
            ? (selected ? 'Remove from wishlist' : 'Save to wishlist')
            : (selected ? 'Unfollow farm' : 'Follow farm');

    Future<void> toggle() async {
      final messenger = ScaffoldMessenger.of(context);
      if (saved?.signedIn != true) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Sign in to save products and follow farms.')));
        return;
      }
      if (failed) {
        saved!.retry(kind);
        return;
      }
      final account = saved!.userId;
      try {
        await saved.setSaved(kind, itemId, !selected);
      } catch (_) {
        if (!messenger.mounted || saved.userId != account) return;
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not save this change. Please try again.')));
      }
    }

    final disabled = busy || loading || (!selected && !allowSave);

    if (iconOnly) {
      final starIcon = busy || loading
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              failed
                  ? Icons.refresh_rounded
                  : (selected
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded),
              size: 22,
              color: selected ? const Color(0xFFFFB800) : HhColors.text.withValues(alpha: 0.7),
            );

      return Semantics(
        toggled: selected,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: disabled ? null : toggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF8E1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFD54F)
                      : HhColors.text.withValues(alpha: 0.18),
                ),
              ),
              child: starIcon,
            ),
          ),
        ),
      );
    }

    final icon = busy || loading
        ? const SizedBox.square(
            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(
            failed
                ? Icons.refresh_rounded
                : isProduct
                    ? (selected
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded)
                    : (selected ? Icons.check_rounded : Icons.add_rounded),
            size: 21);

    return Semantics(
      toggled: selected,
      child: isProduct
          ? IconButton.filledTonal(
              tooltip: label,
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor:
                      selected ? HhColors.danger : HhColors.primary,
                  minimumSize: const Size(48, 48)),
              onPressed: disabled ? null : toggle,
              icon: icon)
          : Tooltip(
              message: label,
              child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: HhColors.primary,
                      backgroundColor:
                          selected ? HhColors.sageLight : Colors.white,
                      minimumSize: const Size(48, 48),
                      side: BorderSide(
                          color: HhColors.primary.withValues(alpha: .2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: disabled ? null : toggle,
                  icon: icon,
                  label: Text(failed
                      ? 'Retry'
                      : selected
                          ? 'Following'
                          : 'Follow'))),
    );
  }
}
