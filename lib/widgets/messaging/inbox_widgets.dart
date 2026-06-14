import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/nex_avatar.dart';

/// Skeleton Pulse — Loading placeholder with animation
class SkeletonPulse extends StatefulWidget {
  final double width, height, radius;
  const SkeletonPulse({super.key, required this.width, required this.height, required this.radius});
  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFE8E8ED), const Color(0xFFF5F5F5), _ctrl.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Match Avatar Hero (Stories style)
class MatchAvatarHero extends StatelessWidget {
  final NexUser user;
  final bool isNew;
  const MatchAvatarHero({super.key, required this.user, required this.isNew});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isNew ? const LinearGradient(colors: [Color(0xFF004E99), Color(0xFF715092)]) : null,
            border: isNew ? null : Border.all(color: const Color(0xFFE5E5EA), width: 2),
            boxShadow: isNew ? [BoxShadow(color: const Color(0xFF004E99).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Color(0xFFF9F9FA), shape: BoxShape.circle),
            child: NexAvatar(user: user, size: 64, showBadge: false, heroTag: 'avatar_${user.id}'),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(user.name.split(' ').first, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: isNew ? FontWeight.w700 : FontWeight.w500, color: isNew ? context.textPrimary : context.textSecondary)),
        ),
      ],
    );
  }
}

/// Conversation Tile ("No-Line" Rule Applied)
class ConversationTile extends StatelessWidget {
  final NexUser user;
  final bool isLast;
  final String previewText;
  final String timeText;
  final bool hasUnread;
  final VoidCallback onTap;
  const ConversationTile({super.key, required this.user, required this.isLast, required this.previewText, required this.timeText, required this.hasUnread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: const Color(0x0A000000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              NexAvatar(user: user, size: 56, showBadge: true, heroTag: 'avatar_${user.id}'),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(user.name, style: TextStyle(fontSize: 16, fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(timeText.isNotEmpty ? timeText : 'Nuevo', style: TextStyle(fontSize: 13, fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500, color: hasUnread ? MployaTheme.brandAccent : context.textTertiary)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(previewText, style: TextStyle(fontSize: 14, color: hasUnread ? context.textPrimary : context.textSecondary, fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (hasUnread) ...[const SizedBox(width: 8), Container(width: 10, height: 10, decoration: const BoxDecoration(color: MployaTheme.brandAccent, shape: BoxShape.circle))],
                ]),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}
