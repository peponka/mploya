import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MployaHaptics — Centralized haptic feedback patterns
//
// Instead of calling HapticFeedback.heavyImpact() everywhere, use:
//   MployaHaptics.success()     — match, connection, save
//   MployaHaptics.warning()     — rate limit, form error
//   MployaHaptics.error()       — block, delete, reject
//   MployaHaptics.selection()   — tab change, chip select
//   MployaHaptics.light()       — bookmark, like, minor action
//   MployaHaptics.impact()      — double-tap interest, nexus
// ─────────────────────────────────────────────────────────────────────────────

class MployaHaptics {
  MployaHaptics._();

  /// Match, connection accepted, profile saved, upload complete.
  static void success() {
    HapticFeedback.mediumImpact();
    // Double tap for a "success" feel
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Form validation error, rate limit warning, incomplete profile.
  static void warning() {
    HapticFeedback.heavyImpact();
  }

  /// Block user, delete job, reject connection, destructive action.
  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Tab change, chip/segment selection, picker scroll.
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Bookmark, like, minor toggle, pull-to-refresh trigger.
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Heavy action: double-tap interest, nexus send, story creation.
  static void impact() {
    HapticFeedback.heavyImpact();
  }

  /// Subtle notification feel — toast appearance, badge update.
  static void notification() {
    HapticFeedback.selectionClick();
    Future.delayed(const Duration(milliseconds: 60), () {
      HapticFeedback.lightImpact();
    });
  }
}
