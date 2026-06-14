import 'package:flutter/cupertino.dart';
import '../l10n/app_strings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UnsavedChangesGuard — Wraps a form screen to prevent accidental back navigation
//
// Usage:
//   UnsavedChangesGuard(
//     hasUnsavedChanges: () => _titleController.text.isNotEmpty,
//     child: CupertinoPageScaffold(...)
//   )
// ─────────────────────────────────────────────────────────────────────────────

class UnsavedChangesGuard extends StatelessWidget {
  /// Callback that returns true if there are unsaved changes.
  final bool Function() hasUnsavedChanges;

  /// The form screen to protect.
  final Widget child;

  /// Custom dialog title.
  final String title;

  /// Custom dialog message.
  final String message;

  const UnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.title = AppStrings.unsavedChangesTitle,
    this.message = AppStrings.unsavedChangesBody,
  });

  Future<bool> _onWillPop(BuildContext context) async {
    if (!hasUnsavedChanges()) return true;

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.unsavedChangesDiscard),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.unsavedChangesKeep),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Use PopScope (replacement for deprecated WillPopScope in Flutter 3.22+)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
