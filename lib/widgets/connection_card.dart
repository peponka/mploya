import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'nex_avatar.dart';
import '../services/social_service.dart';

class ConnectionCard extends StatefulWidget {
  final NexUser user;
  final int mutualConnections;
  final double affinityScore;

  const ConnectionCard({
    super.key,
    required this.user,
    this.mutualConnections = 0,
    this.affinityScore = 0,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  bool _isLoading = false;
  String _status = 'none';

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final res = await SocialService.instance.getConnectionStatus(widget.user.id);
    if (res['status'] != null && mounted) {
      setState(() => _status = res['status'] as String);
    }
  }

  Future<void> _handleConnect() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _status = 'pending'; // Siempre queda en pending — el otro acepta
    });
    await SocialService.instance.sendConnectionRequest(widget.user.id);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // Calcular texto de afinidad real
    final hasAffinity = widget.affinityScore > 0;
    final affinityText = hasAffinity
        ? '${widget.affinityScore.clamp(0, 100).toStringAsFixed(0)}% Afinidad'
        : null;
    final mutualText = widget.mutualConnections > 0
        ? '${widget.mutualConnections} en común'
        : null;

    return Container(
      width: 170,
      padding: const EdgeInsets.all(MployaTheme.spaceLG),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner + dismiss
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Banner
              Container(
                height: 52,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MployaTheme.radiusSM),
                  gradient: LinearGradient(
                    colors: [
                      MployaTheme.brandAccent.withValues(alpha: 0.15),
                      MployaTheme.brandAccent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Avatar overlapping banner
              Positioned(
                bottom: 0,
                child: NexAvatar(user: user, size: 56, showBadge: true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user.name,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            user.headline,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // ── Datos reales de afinidad/mutuos ──
          if (affinityText != null || mutualText != null)
            Column(
              children: [
                if (affinityText != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.sparkles, size: 12, color: context.brandAccent),
                      const SizedBox(width: 4),
                      Text(
                        affinityText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.brandAccent,
                        ),
                      ),
                    ],
                  ),
                if (mutualText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    mutualText,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          // Connect button
          SizedBox(
            width: double.infinity,
            child: _status != 'none'
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(MployaTheme.radiusPill),
                      border: Border.all(
                        color: context.textTertiary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _status == 'pending' ? 'Match Solicitado' : 'Contactos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  )
                : CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    borderRadius:
                        BorderRadius.circular(MployaTheme.radiusPill),
                    color: MployaTheme.brandAccent,
                    onPressed: _isLoading ? null : _handleConnect,
                    child: _isLoading 
                      ? const CupertinoActivityIndicator(radius: 8, color: CupertinoColors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.person_add,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Contactar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}
