import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class SaveButton extends StatelessWidget {
  final SavedKind kind;
  final String itemId;
  final bool allowSave;
  const SaveButton(
      {super.key,
      required this.kind,
      required this.itemId,
      this.allowSave = true});

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
        // Removing a row can unmount this button before a rejected write rolls
        // back. Keep feedback on the page, without leaking it to another account.
        if (!messenger.mounted || saved.userId != account) return;
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not save this change. Please try again.')));
      }
    }

    final disabled = busy || loading || (!selected && !allowSave);
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
