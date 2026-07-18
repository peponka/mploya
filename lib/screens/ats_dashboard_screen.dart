import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import '../services/ai_interview_service.dart';
import 'interview_flow_screen.dart';
import 'interview_report_screen.dart';
import 'premium_paywall_screen.dart';

// ═══════════════════════════════════════════════════════════════
// DEMO DATA
// ═══════════════════════════════════════════════════════════════
final _demoCandidates = [
  _C(name: 'Elena G.', role: 'Data Scientist', match: 92, skills: ['Python', 'SQL', 'Project Mgmt.'], photo: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face', stage: 'revision', hasVideo: true, pitchTitle: 'DATA SCIENTIST PITCH'),
  _C(name: 'Alex R.', role: 'Frontend Dev', match: 92, skills: ['React', 'TypeScript', 'Figma'], photo: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face', stage: 'interview', hasVideo: true, pitchTitle: 'FRONTEND PITCH'),
  _C(name: 'Sofía C.', role: 'UX Designer', match: 92, skills: ['Figma', 'Research', 'UI/UX'], photo: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face', stage: 'interview', hasVideo: true, pitchTitle: 'UX DESIGN PITCH'),
  _C(name: 'David L.', role: 'Backend Eng', match: 92, skills: ['Go', 'AWS', 'PostgreSQL'], photo: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face', stage: 'interview', hasVideo: false, pitchTitle: 'BACKEND PITCH'),
  _C(name: 'Carlos M.', role: 'DevOps', match: 88, skills: ['Docker', 'K8s', 'Terraform'], photo: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face', stage: 'revision', hasVideo: true, pitchTitle: 'DEVOPS PITCH'),
  _C(name: 'Lucía P.', role: 'Product Mgr', match: 85, skills: ['Agile', 'Analytics', 'SQL'], photo: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop&crop=face', stage: 'revision', hasVideo: true, pitchTitle: 'PRODUCT PITCH'),
];

class _C {
  final String name, role, photo, stage, pitchTitle;
  final int match;
  final List<String> skills;
  final bool hasVideo;
  const _C({required this.name, required this.role, required this.match, required this.skills, required this.photo, required this.stage, required this.hasVideo, required this.pitchTitle});
}

// ═══════════════════════════════════════════════════════════════

class AtsDashboardScreen extends StatefulWidget {
  const AtsDashboardScreen({super.key});
  @override
  State<AtsDashboardScreen> createState() => _AtsDashboardScreenState();
}

class _AtsDashboardScreenState extends State<AtsDashboardScreen> {
  int _tabIdx = 0; // 0=Pendientes, 1=Contactos, 2=Confidencial
  int _mobilePitchIdx = 0;
  bool _confidencialUnlocked = false;
  final _tabs = ['Pendientes', 'Contactos', 'Confidencial'];

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);
    if (wide) return _webLayout(context);
    return _mobileLayout(context);
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB LAYOUT
  // ═══════════════════════════════════════════════════════════════
  Widget _webLayout(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      child: WebPage(
        title: 'Candidatos',
        actions: [
          _filterDropdown('Rol'),
          const SizedBox(width: 6),
          _filterDropdown('Ubicación'),
          const SizedBox(width: 6),
          _filterDropdown('Coincidencia'),
          const SizedBox(width: 6),
          _filterDropdown('Experiencia'),
        ],
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Tabs
            _webTabs(context),
            const SizedBox(height: 16),
            // Content by tab
            if (_tabIdx == 0) _pendientesWeb(context),
            if (_tabIdx == 1) _contactosWeb(context),
            if (_tabIdx == 2) _confidencialWeb(context),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _filterDropdown(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(width: 4),
        const Icon(CupertinoIcons.chevron_down, size: 12, color: Color(0xFF94A3B8)),
      ]),
    );
  }

  Widget _webTabs(BuildContext context) {
    return Row(children: List.generate(3, (i) {
      final active = i == _tabIdx;
      return GestureDetector(
        onTap: () => setState(() => _tabIdx = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Text(_tabs[i], style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1E293B) : const Color(0xFF94A3B8))),
        ),
      );
    }));
  }

  Widget _pendientesWeb(BuildContext context) {
    final revision = _demoCandidates.where((c) => c.stage == 'revision').toList();
    final interview = _demoCandidates.where((c) => c.stage == 'interview').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kanban columns (Full width scrollable)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kanbanCol('Pendientes', revision, const Color(0xFFF97316)),
              const SizedBox(width: 16),
              _kanbanCol('Revisión Inicial', revision, const Color(0xFF3B82F6)),
              const SizedBox(width: 16),
              _kanbanCol('Listo para Entrevista', interview, const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _kanbanCol('Listo para Entrevista', [interview.first], const Color(0xFF8B5CF6)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // AI Sourcing panel (Positioned below, constrained)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: _aiSourcingPanel(context),
        ),
      ],
    );
  }

  Widget _kanbanCol(String title, List<_C> candidates, Color color) {
    return SizedBox(width: 330, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
      const SizedBox(height: 14),
      ...candidates.map((c) => _kanbanCard(c, color)),
    ]));
  }

  Widget _kanbanCard(_C c, Color stageColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipOval(child: CachedNetworkImage(imageUrl: c.photo, width: 54, height: 54, fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: 54, height: 54, color: Colors.grey.shade200),
            errorWidget: (_, __, ___) => Container(width: 54, height: 54, color: Colors.grey.shade300))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 3),
            Text('Coincidencia ${c.match}%', style: TextStyle(fontSize: 13, color: stageColor, fontWeight: FontWeight.w700)),
          ])),
          if (c.hasVideo) const Icon(CupertinoIcons.play_circle_fill, size: 24, color: Color(0xFF3B82F6)),
        ]),
        const SizedBox(height: 14),
        // Skills
        Wrap(spacing: 6, runSpacing: 6, children: c.skills.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
          child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        )).toList()),
        const SizedBox(height: 16),
        // Buttons
        if (c.hasVideo) ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Revisar Pitch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF97316)))),
          ),
          const SizedBox(height: 8),
        ] else ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Ver Perfil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
          ),
          const SizedBox(height: 8),
        ],
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _handleIAInterview(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'Entrevista IA ✨',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Aceptar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)))),
          )),
          const SizedBox(width: 8),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Rechazar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)))),
          )),
        ]),
      ]),
    );
  }

  Widget _aiSourcingPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]), borderRadius: BorderRadius.circular(8)),
            child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14)),
          const SizedBox(width: 8),
          const Text('AI-Powered Sourcing', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        ]),
        const SizedBox(height: 6),
        const Text('AI-Powered Sourcing a una poderosa da candidatos en su internamente el candidato de las mismas.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        _aiFilterField('Rol'),
        const SizedBox(height: 8),
        _aiFilterField('Ubicación'),
        const SizedBox(height: 8),
        _aiFilterField('Coincidencia'),
        const SizedBox(height: 8),
        _aiFilterField('Candidate Status'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.lock_fill, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('Permissions', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ),
        const SizedBox(height: 8),
        Center(child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]), shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 8)]),
          child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 16),
        )),
      ]),
    );
  }

  Widget _aiFilterField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
        const Spacer(),
        const Icon(CupertinoIcons.chevron_down, size: 12, color: Color(0xFF94A3B8)),
      ]),
    );
  }

  // ── Contactos tab ──
  Widget _contactosWeb(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Contactos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _demoCandidates.map((c) => _contactCard(c)).toList(),
      ),
    ]);
  }

  Widget _contactCard(_C c) {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: c.photo,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 54, height: 54, color: Colors.grey.shade200),
                  errorWidget: (_, __, ___) => Container(width: 54, height: 54, color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.role,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.ellipsis, size: 20, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 14),
          // Skills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: c.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            )).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Perfil completo con historial detallado de experiencia y evaluación de habilidades técnicas.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Coincidencia General',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Text(
                '${c.match}%',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buttons
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Schedule Interview',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _handleIAInterview(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Entrevista IA ✨',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confidencial tab ──
  Widget _confidencialWeb(BuildContext context) {
    if (!_confidencialUnlocked) {
      return Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                child: const Icon(CupertinoIcons.lock_shield_fill, size: 28, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text('Private database access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              const Text('Private database access to access your permissions.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              const SizedBox(height: 20),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const PremiumPaywallScreen()),
                  ).then((_) {
                    setState(() => _confidencialUnlocked = true);
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Desbloquear acceso', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unlocked view: show the confidential candidates!
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Candidatos Confidenciales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_demoCandidates.length, (index) {
            final c = _demoCandidates[index];
            return _confidencialCandidateCard(c, index);
          }),
        ),
      ],
    );
  }

  Widget _confidencialCandidateCard(_C c, int index) {
    final confidentialId = 100 + index * 17;
    return Container(
      width: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Blurred or lock avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(CupertinoIcons.eye_slash_fill, size: 22, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talento Confidencial #$confidentialId',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.role,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.lock_fill, size: 10, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Premium', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Skills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: c.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            )).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Este candidato prefiere mantener su perfil en modo confidencial. Revisa su video pitch o solicita contacto directo.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Coincidencia por IA',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Text(
                '${c.match}%',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buttons
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Solicitar Identidad (Match)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _handleIAInterview(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Entrevista IA ✨',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════
  Widget _mobileLayout(BuildContext context) {
    final c = _demoCandidates[_mobilePitchIdx];
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: Text('Candidatos', style: TextStyle(color: context.textPrimary, fontFamily: '.SF Pro Display', letterSpacing: -0.5, fontWeight: FontWeight.w900)),
            backgroundColor: context.bgColor,
            border: null,
          ),
          // ── Pendientes header with arrows ──
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Text('Pendientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _mobilePitchIdx = (_mobilePitchIdx - 1).clamp(0, _demoCandidates.length - 1)),
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(8), boxShadow: context.cardShadow),
                  child: Icon(CupertinoIcons.chevron_left, size: 14, color: context.textSecondary))),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _mobilePitchIdx = (_mobilePitchIdx + 1).clamp(0, _demoCandidates.length - 1)),
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(8), boxShadow: context.cardShadow),
                  child: Icon(CupertinoIcons.chevron_right, size: 14, color: context.textSecondary))),
            ]),
          )),
          // ── Video Pitch Card ──
          SliverToBoxAdapter(child: _mobilePitchCard(context, c)),
          // ── Accept / Reject ──
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Aceptar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981)))),
              )),
              const SizedBox(width: 10),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Rechazar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)))),
              )),
            ]),
          )),
          // ── Entrevista IA ──
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _handleIAInterview(context),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('Entrevista IA ✨', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 14, fontWeight: FontWeight.w700))),
              ),
            ),
          )),
          // ── Ver Todos los Contactos ──
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Ver Todos los Contactos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
            ),
          )),
          // ── Badges row ──
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _badgePill(CupertinoIcons.person_fill, 'Profile\nComplete', const Color(0xFFF97316)),
              _badgePill(CupertinoIcons.checkmark_seal_fill, 'Skill\nBadge', const Color(0xFF10B981)),
              _badgePill(CupertinoIcons.videocam_fill, 'Pitch\nRecibido', const Color(0xFF3B82F6)),
              _badgePill(CupertinoIcons.sparkles, 'Skill\nPython', const Color(0xFF8B5CF6)),
              _badgePill(CupertinoIcons.video_camera_solid, 'Video\nInterview', const Color(0xFFE91E63)),
            ])),
          )),
          // ── Map ──
          SliverToBoxAdapter(child: _mobileMap(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      )),
    );
  }

  Widget _mobilePitchCard(BuildContext context, _C c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 280,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))]),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Background photo
          Positioned.fill(child: CachedNetworkImage(imageUrl: c.photo.replaceAll('w=200&h=200', 'w=600&h=800'), fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF1E293B)),
            errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E293B)))),
          // Gradient overlay
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)])))),
          // LIVE badge
          if (c.hasVideo) Positioned(top: 12, right: 12, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.circle_fill, color: Colors.white, size: 6), SizedBox(width: 4), Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))]),
          )),
          // Play button
          Center(child: Container(width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)),
            child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28))),
          // Bottom info
          Positioned(left: 14, right: 14, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c.name} - ${c.pitchTitle}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            // Skills
            Wrap(spacing: 5, children: c.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            )).toList()),
          ])),
          // Match badge
          Positioned(top: 12, left: 12, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
            child: Text('Coincidencia ${c.match}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
          )),
        ]),
      ),
    );
  }

  Widget _badgePill(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _mobileMap(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 10),
      Container(height: 160, width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFBBDEFB))),
        child: Stack(children: [
          ...List.generate(5, (i) => Positioned(top: i * 32.0 + 16, left: 0, right: 0, child: Container(height: 0.5, color: const Color(0xFFCFD8DC)))),
          Positioned(top: 60, left: 120, child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE2860B)]), borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 8)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(CupertinoIcons.building_2_fill, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                child: const Text('Company A', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFF97316)))),
            ]),
          )),
          Positioned(top: 35, right: 60, child: _mapAvatar('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face')),
          Positioned(top: 90, left: 70, child: _mapAvatar('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face')),
          // Navigation icon
          Positioned(top: 10, right: 10, child: Container(width: 30, height: 30,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
            child: const Icon(CupertinoIcons.location_fill, size: 14, color: Color(0xFF3B82F6)))),
        ])),
    ]));
  }

  Widget _mapAvatar(String url) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
      child: ClipOval(child: CachedNetworkImage(imageUrl: url, width: 26, height: 26, fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 26, height: 26, color: Colors.grey.shade200),
        errorWidget: (_, __, ___) => Container(width: 26, height: 26, color: Colors.grey.shade300))),
    );
  }

  Future<void> _handleIAInterview(BuildContext context) async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Entrevistas por IA'),
        message: const Text('Selecciona una opción. El Modo Demo funciona instantáneamente de forma local.'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Simular Entrevista (Candidato) - Modo Demo 🚀'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const InterviewFlowScreen(interviewId: 'demo-pending'),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Ver Reporte IA (Reclutador) - Modo Demo 📊'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const InterviewReportScreen(interviewId: 'demo-completed'),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Simular Entrevista (Base de Datos Real)'),
            onPressed: () {
              Navigator.pop(context);
              _launchDemoInterview(context, isCandidate: true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Ver Reporte IA (Base de Datos Real)'),
            onPressed: () {
              Navigator.pop(context);
              _launchDemoInterview(context, isCandidate: false);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _launchDemoInterview(BuildContext context, {required bool isCandidate}) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 16)),
    );

    try {
      final client = Supabase.instance.client;
      final jobs = await client.from('jobs').select('id').limit(1).timeout(const Duration(seconds: 3));
      final users = await client.from('users').select('id').limit(1).timeout(const Duration(seconds: 3));

      if (!mounted) return;
      Navigator.pop(context); // Quitar loader

      if (jobs.isEmpty || users.isEmpty) {
        _showDemoFallbackDialog(context, isCandidate, 'Falta de registros');
        return;
      }

      final jobId = jobs[0]['id'] as String;
      final candidateId = users[0]['id'] as String;

      final existing = await client
          .from('interviews')
          .select('id')
          .eq('job_id', jobId)
          .eq('candidate_id', candidateId)
          .limit(1)
          .timeout(const Duration(seconds: 3));

      String interviewId;
      if (existing.isNotEmpty) {
        interviewId = existing[0]['id'] as String;
      } else {
        final interview = await AIInterviewService.instance.createInterview(
          jobId: jobId,
          candidateId: candidateId,
        ).timeout(const Duration(seconds: 3));
        if (interview == null) throw Exception('No se pudo crear el registro de entrevista.');
        interviewId = interview.id;
      }

      if (!mounted) return;
      if (isCandidate) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => InterviewFlowScreen(interviewId: interviewId),
          ),
        );
      } else {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => InterviewReportScreen(interviewId: interviewId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Quitar loader en caso de error
        _showDemoFallbackDialog(context, isCandidate, 'Timeout o error de red');
      }
    }
  }

  void _showDemoFallbackDialog(BuildContext context, bool isCandidate, String reason) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Conexión Supabase'),
        content: Text(
          'No se pudo conectar a la base de datos de Supabase ($reason).\n\n'
          '¿Deseas probar el flujo usando el Modo de Demostración Local?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Modo Demo'),
            onPressed: () {
              Navigator.pop(context);
              final demoId = isCandidate ? 'demo-pending' : 'demo-completed';
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => isCandidate
                      ? InterviewFlowScreen(interviewId: demoId)
                      : InterviewReportScreen(interviewId: demoId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}