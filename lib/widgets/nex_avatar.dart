import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/profile_screen.dart';

class NexAvatar extends StatelessWidget {
  final NexUser user;
  final double size;
  final bool showBadge;
  final bool showStoryRing;
  final VoidCallback? onTap;
  /// Optional hero tag for shared element transitions.
  /// Use user.id for cross-screen avatar animations.
  final String? heroTag;

  const NexAvatar({
    super.key,
    required this.user,
    this.size = 48,
    this.showBadge = false,
    this.showStoryRing = false,
    this.onTap,
    this.heroTag,
  });

  // Deterministic color from user name
  Color _avatarColor() {
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF057642),
      const Color(0xFFB24020),
      const Color(0xFF5F3DC4),
      const Color(0xFFC2185B),
      const Color(0xFF00838F),
      const Color(0xFFEA580C),
      const Color(0xFF2E7D32),
    ];
    int hash = 0;
    for (var c in user.name.codeUnits) {
      hash = (hash + c) % colors.length;
    }
    return colors[hash];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColor(),
        image: (user.avatarUrl ?? '').isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(user.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: (user.avatarUrl ?? '').isEmpty
          ? Center(
              child: Text(
                user.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
    );

    if (showStoryRing) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(0xFF004E99),
              Color(0xFF715092),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.bgColor,
          ),
          child: avatar,
        ),
      );
    }

    if (showBadge) {
      String? badgeText;
      Color? badgeColor;

      if (user.isOpenToWork) {
        badgeText = '⚡';
        badgeColor = MployaTheme.openToWork;
      } else if (user.isHiring) {
        badgeText = '⬆';
        badgeColor = MployaTheme.hiring;
      } else if (user.isVerified) {
        badgeText = '✓';
        badgeColor = const Color(0xFF057642);
      } else if (user.isPremium) {
        badgeText = '★';
        badgeColor = const Color(0xFFD4A843);
      }

      if (badgeText != null) {
        avatar = Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.cardColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    final wrappedAvatar = Semantics(
      button: true,
      label: 'Avatar de ${user.name}${user.isOpenToWork ? ', buscando trabajo' : ''}${user.isVerified ? ', verificado' : ''}',
      child: GestureDetector(
        onTap: onTap ?? () {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
        child: avatar,
      ),
    );

    // Wrap in Hero for shared element transitions
    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: wrappedAvatar,
      );
    }
    return wrappedAvatar;
  }
}
