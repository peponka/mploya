import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import '../screens/vacantes_screen.dart';

// ── Demo candidate/company data with real photos ──
const _demoUsers = [
  {'name': 'Alex Torres', 'role': 'Frontend Developer', 'photo': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face', 'active': true},
  {'name': 'Elena García', 'role': 'Data Scientist', 'photo': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face', 'active': true},
  {'name': 'Carlos Méndez', 'role': 'Backend Engineer', 'photo': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face', 'active': false},
  {'name': 'Ana Rodríguez', 'role': 'UX Designer', 'photo': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face', 'active': true},
  {'name': 'Diego López', 'role': 'Product Manager', 'photo': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face', 'active': false},
];

const _videoPitches = [
  {'name': 'Elena G.', 'role': 'Data Scientist', 'photo': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&h=400&fit=crop&crop=face', 'live': true, 'pitch': 'DATA SCIENTIST PITCH'},
  {'name': 'Carlos M.', 'role': 'Backend Dev', 'photo': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&h=400&fit=crop&crop=face', 'live': false, 'pitch': 'BACKEND PITCH'},
  {'name': 'Ana R.', 'role': 'UX Designer', 'photo': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&h=400&fit=crop&crop=face', 'live': true, 'pitch': 'UX DESIGN PITCH'},
  {'name': 'Diego L.', 'role': 'Product Mgr', 'photo': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&h=400&fit=crop&crop=face', 'live': false, 'pitch': 'PRODUCT PITCH'},
  {'name': 'Lucía P.', 'role': 'Marketing Lead', 'photo': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&h=400&fit=crop&crop=face', 'live': true, 'pitch': 'MARKETING PITCH'},
];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);

    if (wide) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        child: WebPage(
          title: 'Hiring Hub Dashboard',
          subtitle: 'Tu centro de reclutamiento inteligente.',
          actions: [
            WebButton(
              icon: CupertinoIcons.briefcase_fill,
              label: 'Vacantes',
              filled: false,
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen())),
            ),
          ],
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _connectionsCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _matchSpotlightCard(context)),
                ]),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _explorerCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _milestonesCard(context)),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    // ── Mobile Layout ──
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              transitionBetweenRoutes: false,
              largeTitle: Text('Hiring Hub', style: TextStyle(color: context.textPrimary, fontFamily: '.SF Pro Display', letterSpacing: -0.5, fontWeight: FontWeight.w900)),
              backgroundColor: context.bgColor,
              border: null,
            ),
            SliverToBoxAdapter(child: _featuredPitchesMobile(context)),
            SliverToBoxAdapter(child: _recentChatsMobile(context)),
            SliverToBoxAdapter(child: _mapPreviewMobile(context)),
            SliverToBoxAdapter(child: _milestonesMobile(context)),
            SliverToBoxAdapter(child: _verifyCTA(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PHOTO AVATAR WIDGET
  // ═══════════════════════════════════════════════════════════════
  Widget _photoAvatar(String url, double size, {bool showBorder = false, bool isActive = false}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: isActive ? const Color(0xFF34C759) : Colors.grey.shade300, width: 2.5)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.grey.shade200),
          errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(CupertinoIcons.person_fill, color: Colors.grey)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB: Connections Card
  // ═══════════════════════════════════════════════════════════════
  Widget _connectionsCard(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Connections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const Spacer(),
          _premiumCameraBadge(),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _userWithStatus(_demoUsers[0]),
          const SizedBox(width: 20),
          _userWithStatus(_demoUsers[1]),
          const SizedBox(width: 20),
          _userWithStatus(_demoUsers[2]),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _chatMsg('¿Viste el concepto para el corto?', false, _demoUsers[0]['photo'] as String),
            const SizedBox(height: 10),
            _chatMsg('¡Sí! Me encanta. ¿Grabamos hoy?', true, _demoUsers[1]['photo'] as String),
            const SizedBox(height: 12),
            Text('ELENA G. - VIDEO PITCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.textTertiary, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text('· View Portfolio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
          ]),
        ),
      ]),
    );
  }

  Widget _premiumCameraBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 14),
        SizedBox(width: 5),
        Text('Premium Camera', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _userWithStatus(Map<String, dynamic> user) {
    final active = user['active'] == true;
    return Column(children: [
      Stack(children: [
        _photoAvatar(user['photo'] as String, 50, showBorder: true, isActive: active),
        if (active)
          Positioned(bottom: 0, right: 0, child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: const Color(0xFF34C759), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
          )),
      ]),
      const SizedBox(height: 5),
      Text((user['name'] as String).split(' ').first, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      if (active) const Text('Active Now', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF34C759))),
    ]);
  }

  Widget _chatMsg(String text, bool isMe, String photoUrl) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe) ...[_photoAvatar(photoUrl, 28), const SizedBox(width: 8)],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? null : Colors.white,
              gradient: isMe ? const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]) : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isMe ? Colors.white : const Color(0xFF1E293B))),
          ),
        ),
        if (isMe) ...[const SizedBox(width: 8), _photoAvatar(photoUrl, 28)],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB: Match Spotlight Card
  // ═══════════════════════════════════════════════════════════════
  Widget _matchSpotlightCard(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Match Spotlight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        const SizedBox(height: 14),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=600&h=400&fit=crop&crop=face',
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF1E293B)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
              ),
            ),
            Positioned.fill(child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.7)])),
            )),
            Positioned(top: 10, left: 10, child: _liveBadge()),
            Center(child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)),
              child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28),
            )),
            Positioned(bottom: 12, left: 12, right: 12, child: Row(children: [
              _photoAvatar(_demoUsers[1]['photo'] as String, 34),
              const SizedBox(width: 8),
              const Expanded(child: Text('Elena G. · Data Scientist Pitch', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text('ELENA G. - DATA SCIENTIST PITCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.textTertiary, letterSpacing: 0.5)),
          const Spacer(),
          Text('· View Portfolio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB: Explorer & Growth Card
  // ═══════════════════════════════════════════════════════════════
  Widget _explorerCard(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Explorer & Growth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        const SizedBox(height: 14),
        Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBDEFB)),
          ),
          child: Stack(children: [
            ...List.generate(6, (i) => Positioned(top: i * 28.0 + 10, left: 0, right: 0, child: Container(height: 0.5, color: const Color(0xFFCFD8DC)))),
            ...List.generate(5, (i) => Positioned(left: i * 80.0 + 20, top: 0, bottom: 0, child: Container(width: 0.5, color: const Color(0xFFCFD8DC)))),
            Positioned(top: 60, left: 130, child: _mapCompanyPin()),
            Positioned(top: 35, left: 75, child: _mapUserPin(_demoUsers[0]['photo'] as String, const Color(0xFF3B82F6))),
            Positioned(top: 95, left: 210, child: _mapUserPin(_demoUsers[1]['photo'] as String, const Color(0xFF10B981))),
            Positioned(top: 28, right: 50, child: _mapUserPin(_demoUsers[4]['photo'] as String, const Color(0xFF8B5CF6))),
          ]),
        ),
        const SizedBox(height: 12),
        _companyRow(),
      ]),
    );
  }

  Widget _mapCompanyPin() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: const Icon(CupertinoIcons.building_2_fill, color: Colors.white, size: 18),
    );
  }

  Widget _mapUserPin(String photoUrl, Color color) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)]),
      child: ClipOval(child: CachedNetworkImage(imageUrl: photoUrl, width: 28, height: 28, fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 28, height: 28, color: Colors.grey.shade200),
        errorWidget: (_, __, ___) => Container(width: 28, height: 28, color: Colors.grey.shade300),
      )),
    );
  }

  Widget _companyRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x0F000000))),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFBBF24)]), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('PE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preview Empresa QA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          Text('Tecnología · Fintech', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Text('Empresa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
        ),
        const SizedBox(width: 6),
        const Text('0 · 3 min 📍', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]), borderRadius: BorderRadius.circular(8)),
          child: const Text('Ver', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB: Career Milestones Card
  // ═══════════════════════════════════════════════════════════════
  Widget _milestonesCard(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Career Milestones & Goal Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _milestoneCircle(CupertinoIcons.person_fill, 'Profile', '90% Complete', 0.9, const Color(0xFFF97316)),
          _progressDots(),
          _milestoneCircle(CupertinoIcons.checkmark_seal_fill, 'Skill Badge:', 'Python', 0.75, const Color(0xFFE91E63)),
          _progressDots(),
          _milestoneCircle(CupertinoIcons.videocam_fill, 'Video', 'Interview\nPending', 0.4, const Color(0xFF3B82F6)),
        ]),
        const SizedBox(height: 20),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: 0.68, minHeight: 8,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFF97316)),
        )),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _dot(true), const SizedBox(width: 8),
          _dot(true), const SizedBox(width: 8),
          _dot(false),
        ]),
      ]),
    );
  }

  Widget _milestoneCircle(IconData icon, String label, String value, double progress, Color color) {
    return Column(children: [
      SizedBox(width: 60, height: 60, child: Stack(children: [
        SizedBox(width: 60, height: 60, child: CircularProgressIndicator(
          value: progress, strokeWidth: 3.5,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(color),
        )),
        Center(child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        )),
      ])),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
      Text(value, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]);
  }

  Widget _progressDots() {
    return Row(children: List.generate(3, (i) => Container(
      width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), shape: BoxShape.circle),
    )));
  }

  Widget _dot(bool active) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: active ? MployaTheme.brandAccent : const Color(0xFFE2E8F0), shape: BoxShape.circle),
  );

  // ═══════════════════════════════════════════════════════════════
  // SHARED CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0F000000)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(6)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.circle_fill, color: Colors.white, size: 6),
        SizedBox(width: 4),
        Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE: Featured Video Pitches
  // ═══════════════════════════════════════════════════════════════
  Widget _featuredPitchesMobile(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text('Featured Video Pitches', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary)),
      ),
      SizedBox(height: 170, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _videoPitches.length,
        itemBuilder: (_, i) => _pitchThumbMobile(_videoPitches[i]),
      )),
    ]);
  }

  Widget _pitchThumbMobile(Map<String, dynamic> pitch) {
    return Container(
      width: 120, margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: CachedNetworkImage(imageUrl: pitch['photo'] as String, fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFF1E293B)),
          errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
        )),
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)])))),
        if (pitch['live'] == true) Positioned(top: 8, right: 8, child: _liveBadge()),
        Center(child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 18),
        )),
        Positioned(bottom: 10, left: 10, right: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pitch['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(pitch['role'] as String, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE: Recent Chats
  // ═══════════════════════════════════════════════════════════════
  Widget _recentChatsMobile(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text('Recent Chats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary))),
      _chatTileMobile(context, _demoUsers[0], '¿Viste el concepto para el corto?', '09:22'),
      _chatTileMobile(context, _demoUsers[1], '¡Sí! Me encanta. ¿Grabamos hoy?', '09:25'),
    ]);
  }

  Widget _chatTileMobile(BuildContext context, Map<String, dynamic> user, String msg, String time) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), boxShadow: context.cardShadow),
      child: Row(children: [
        _photoAvatar(user['photo'] as String, 46),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['name'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 3),
          Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.textTertiary)),
        ])),
        const SizedBox(width: 8),
        Text(time, style: TextStyle(fontSize: 11, color: context.textTertiary, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE: Map Preview
  // ═══════════════════════════════════════════════════════════════
  Widget _mapPreviewMobile(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Map', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 12),
        Container(height: 170, width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFBBDEFB))),
          child: Stack(children: [
            ...List.generate(5, (i) => Positioned(top: i * 34.0 + 16, left: 0, right: 0, child: Container(height: 0.5, color: const Color(0xFFCFD8DC)))),
            Positioned(top: 60, left: 100, child: _mapUserPin(_demoUsers[0]['photo'] as String, const Color(0xFF3B82F6))),
            Positioned(top: 40, right: 80, child: _mapUserPin(_demoUsers[1]['photo'] as String, const Color(0xFF10B981))),
            Positioned(top: 75, left: 180, child: _mapCompanyPin()),
            Positioned(top: 100, right: 50, child: _mapUserPin(_demoUsers[4]['photo'] as String, const Color(0xFF8B5CF6))),
          ]),
        ),
      ],
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE: Career Milestones
  // ═══════════════════════════════════════════════════════════════
  Widget _milestonesMobile(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: context.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Career Milestones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 14),
        _milestoneRow(context, CupertinoIcons.person_fill, 'Profile', '90% Complete', const Color(0xFFF97316)),
        const SizedBox(height: 12),
        _milestoneRow(context, CupertinoIcons.checkmark_seal_fill, 'Skill Badge', 'Python ✓', const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _milestoneRow(context, CupertinoIcons.videocam_fill, 'Video Interview', 'Pending', const Color(0xFF3B82F6)),
      ]),
    ));
  }

  Widget _milestoneRow(BuildContext context, IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE: Verify CTA
  // ═══════════════════════════════════════════════════════════════
  Widget _verifyCTA(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(CupertinoIcons.checkmark_shield_fill, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Text('Verify My Skills', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
      ]),
    ));
  }
}
