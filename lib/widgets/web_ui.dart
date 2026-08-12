import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors;

import '../theme/app_theme.dart';
import 'mploya_shell.dart';

bool isWebWide(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width > 800;

class WebPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final double maxWidth;
  final Widget? leading;

  const WebPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.maxWidth = 1320,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);
    final horizontal = wide ? 28.0 : 16.0;

    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, wide ? 12 : 8, horizontal, 16),
                  child: MployaShellCard(
                    radius: 28,
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 22 : 18,
                      vertical: wide ? 18 : 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: wide ? 28 : 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.end,
                            children: actions,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, wide ? 20 : 12),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const Color kMployaBlue = Color(0xFF22A8F2);
const Color kMployaPurple = Color(0xFF6D48E5);

class WebButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool loading;
  final bool arrow;
  final Color? color;

  const WebButton({
    super.key,
    this.icon,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.loading = false,
    this.arrow = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return MployaPrimaryButton(
        label: arrow ? '$label  ' : label,
        icon: icon,
        onPressed: loading ? null : onTap,
        compact: true,
      );
    }
    return MployaSecondaryButton(
      label: label,
      icon: icon,
      onPressed: loading ? null : onTap,
    );
  }
}

class WebIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const WebIconBadge({
    super.key,
    required this.icon,
    this.color = NexTheme.brandAccent,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}

class WebBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const WebBadge({
    super.key,
    required this.label,
    this.color = NexTheme.brandAccent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return MployaPill(label: label, color: color, icon: icon);
  }
}

class WebCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const WebCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = MployaShellCard(
      borderColor: borderColor,
      child: child,
      padding: padding,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

class WebGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const WebGrid({
    super.key,
    required this.children,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width > 1120 ? 3 : (width > 680 ? 2 : 1);
        if (cols == 1) {
          return Column(
            children: [
              for (final child in children)
                Padding(
                  padding: EdgeInsets.only(bottom: gap),
                  child: child,
                ),
            ],
          );
        }
        final tileWidth = (width - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class WebEyebrow extends StatelessWidget {
  final String label;
  final Color color;

  const WebEyebrow({
    super.key,
    required this.label,
    this.color = NexTheme.brandAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class WebSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const WebSectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: WebEyebrow(label: text, color: color ?? NexTheme.brandAccent),
    );
  }
}

class WebEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Widget? action;

  const WebEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.action,
  }) : assert(
          description != null || subtitle != null,
          'Either description or subtitle must be provided.',
        );

  @override
  Widget build(BuildContext context) {
    final resolvedDescription = description ?? subtitle ?? '';
    final resolvedAction = action ??
        ((actionLabel != null && onAction != null)
            ? WebButton(
                icon: actionIcon,
                label: actionLabel!,
                onTap: onAction!,
              )
            : null);

    return Center(
      child: MployaShellCard(
        radius: 28,
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WebIconBadge(icon: icon, size: 56),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resolvedDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (resolvedAction != null) ...[
                const SizedBox(height: 18),
                resolvedAction,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
