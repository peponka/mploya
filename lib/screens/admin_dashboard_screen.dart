import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminDashboardScreen — Panel de administración (web)
//
// Gestiona usuarios, empresas, candidatos, ofertas y reportes, con KPIs.
// Acceso restringido: solo usuarios con users.is_admin = true.
//
// Requiere la migración SQL: supabase/admin_setup.sql
//   • Agrega la columna users.is_admin
//   • Crea políticas RLS para que los admins puedan leer/editar todo
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _sb = Supabase.instance.client;

  bool _checkingAccess = true;
  bool _isAdmin = false;
  String? _accessError;

  int _tab = 0;
  static const _tabs = ['Resumen', 'Usuarios', 'Empresas', 'Ofertas', 'Reportes'];

  @override
  void initState() {
    super.initState();
    _verifyAdmin();
  }

  Future<void> _verifyAdmin() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _checkingAccess = false;
        _isAdmin = false;
        _accessError = 'Necesitás iniciar sesión.';
      });
      return;
    }
    try {
      final row =
          await _sb.from('users').select('is_admin').eq('id', uid).maybeSingle();
      final isAdmin = row?['is_admin'] == true;
      setState(() {
        _checkingAccess = false;
        _isAdmin = isAdmin;
        if (!isAdmin) _accessError = 'No tenés permisos de administrador.';
      });
    } catch (e) {
      // La columna is_admin puede no existir todavía (falta migración).
      setState(() {
        _checkingAccess = false;
        _isAdmin = false;
        _accessError =
            'No se pudo verificar el acceso. ¿Ejecutaste supabase/admin_setup.sql?\n\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA),
      body: SafeArea(
        child: _checkingAccess
            ? const Center(child: CircularProgressIndicator())
            : !_isAdmin
                ? _AccessDenied(message: _accessError ?? 'Acceso denegado')
                : _buildAdmin(context),
      ),
    );
  }

  Widget _buildAdmin(BuildContext context) {
    return Column(
      children: [
        _AdminTopBar(
          tabs: _tabs,
          current: _tab,
          onTab: (i) => setState(() => _tab = i),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    _OverviewTab(),
                    _UsersTab(accountFilter: null, title: 'Usuarios'),
                    _UsersTab(accountFilter: 'empresa', title: 'Empresas'),
                    _JobsTab(),
                    _ReportsTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar con tabs
// ─────────────────────────────────────────────────────────────────────────────
class _AdminTopBar extends StatelessWidget {
  final List<String> tabs;
  final int current;
  final ValueChanged<int> onTab;
  final VoidCallback onClose;

  const _AdminTopBar({
    required this.tabs,
    required this.current,
    required this.onTab,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: MployaTheme.brandAccent),
          const SizedBox(width: 10),
          Text(
            'Admin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TabChip(
                        label: tabs[i],
                        active: i == current,
                        onTap: () => onTab(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: context.textSecondary),
            tooltip: 'Salir',
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? MployaTheme.brandAccent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? MployaTheme.brandAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resumen (KPIs)
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  final Map<String, int> _kpis = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(String table, {String? col, Object? val}) async {
    var q = _sb.from(table).select('id');
    if (col != null) q = q.eq(col, val!);
    final res = await q.count(CountOption.exact);
    return res.count;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final since24h =
          DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();

      final results = await Future.wait([
        _count('users'),
        _count('users', col: 'account_type', val: 'candidato'),
        _count('users', col: 'account_type', val: 'empresa'),
        _count('users', col: 'account_type', val: 'headhunter'),
        _count('users', col: 'account_type', val: 'confidencial'),
        _count('jobs'),
        _count('job_applications'),
      ]);
      _kpis['Usuarios'] = results[0];
      _kpis['Candidatos'] = results[1];
      _kpis['Empresas'] = results[2];
      _kpis['Headhunters'] = results[3];
      _kpis['Confidenciales'] = results[4];
      _kpis['Ofertas'] = results[5];
      _kpis['Postulaciones'] = results[6];

      // ── Boosts activos (boost_ends_at en el futuro) ──
      try {
        final b = await _sb
            .from('users')
            .select('id')
            .gt('boost_ends_at', nowIso)
            .count(CountOption.exact);
        _kpis['Boosts activos'] = b.count;
      } catch (_) {
        _kpis['Boosts activos'] = 0;
      }

      // ── Vistas de perfil (total) ──
      try {
        _kpis['Vistas de perfil'] = await _count('profile_views');
      } catch (_) {
        _kpis['Vistas de perfil'] = 0;
      }

      // ── Vistas últimas 24h (actividad reciente) ──
      try {
        final v = await _sb
            .from('profile_views')
            .select('id')
            .gte('created_at', since24h)
            .count(CountOption.exact);
        _kpis['Vistas (24h)'] = v.count;
      } catch (_) {
        _kpis['Vistas (24h)'] = 0;
      }

      // Reportes pendientes (tabla opcional)
      try {
        final r = await _sb
            .from('user_reports')
            .select('id')
            .eq('status', 'pending')
            .count(CountOption.exact);
        _kpis['Reportes pendientes'] = r.count;
      } catch (_) {
        _kpis['Reportes pendientes'] = 0;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    final entries = _kpis.entries.toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          Text('Métricas',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final e in entries)
                _KpiCard(label: e.key, value: e.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  const _KpiCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                  letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Usuarios / Empresas
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  final String? accountFilter;
  final String title;
  const _UsersTab({required this.accountFilter, required this.title});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = _sb
          .from('users')
          .select('id, name, email, account_type, is_verified, is_premium, '
              'location, video_url, created_at');
      if (widget.accountFilter != null) {
        q = q.eq('account_type', widget.accountFilter!);
      }
      final data = await q.order('created_at', ascending: false).limit(200);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggleVerified(Map<String, dynamic> u) async {
    final newVal = !(u['is_verified'] == true);
    try {
      await _sb.from('users').update({'is_verified': newVal}).eq('id', u['id']);
      setState(() => u['is_verified'] = newVal);
    } catch (e) {
      _snack('No se pudo actualizar (¿RLS de admin?): $e');
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    final filtered = _rows.where((u) {
      if (_search.isEmpty) return true;
      final s = _search.toLowerCase();
      return (u['name'] ?? '').toString().toLowerCase().contains(s) ||
          (u['email'] ?? '').toString().toLowerCase().contains(s);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(width: 12),
            Text('(${filtered.length})',
                style: TextStyle(color: context.textTertiary)),
            const Spacer(),
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o email…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Expanded(child: _EmptyState(message: 'Sin resultados'))
        else
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Tipo')),
                    DataColumn(label: Text('Video')),
                    DataColumn(label: Text('Verificado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: [
                    for (final u in filtered)
                      DataRow(cells: [
                        DataCell(Text(u['name']?.toString() ?? '—')),
                        DataCell(Text(u['email']?.toString() ?? '—')),
                        DataCell(Text(u['account_type']?.toString() ?? '—')),
                        DataCell(Icon(
                          (u['video_url'] != null &&
                                  u['video_url'].toString().isNotEmpty)
                              ? Icons.check_circle
                              : Icons.remove_circle_outline,
                          color: (u['video_url'] != null &&
                                  u['video_url'].toString().isNotEmpty)
                              ? Colors.green
                              : context.textTertiary,
                          size: 18,
                        )),
                        DataCell(Switch(
                          value: u['is_verified'] == true,
                          activeColor: MployaTheme.brandAccent,
                          onChanged: (_) => _toggleVerified(u),
                        )),
                        DataCell(Row(children: [
                          TextButton(
                            onPressed: () => _toggleVerified(u),
                            child: Text(u['is_verified'] == true
                                ? 'Quitar verif.'
                                : 'Verificar'),
                          ),
                        ])),
                      ]),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ofertas
// ─────────────────────────────────────────────────────────────────────────────
class _JobsTab extends StatefulWidget {
  const _JobsTab();
  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _sb
          .from('jobs')
          .select('id, title, company_name, location, modality, created_at')
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> j) async {
    try {
      await _sb.from('jobs').delete().eq('id', j['id']);
      setState(() => _rows.remove(j));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar (¿RLS admin?): $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const _EmptyState(message: 'No hay ofertas publicadas');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Ofertas (${_rows.length})',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final j = _rows[i];
              return _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(j['title']?.toString() ?? 'Sin título',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            '${j['company_name'] ?? '—'} · ${j['location'] ?? '—'} · ${j['modality'] ?? '—'}',
                            style: TextStyle(
                                fontSize: 13, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () => _delete(j),
                      icon: const Icon(Icons.delete_outline,
                          color: MployaTheme.danger),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reportes
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _sb
          .from('user_reports')
          .select('id, reported_id, reporter_id, reason, status, created_at')
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error =
            'No se pudo cargar reportes. La tabla user_reports puede no existir aún.\n\n$e';
      });
    }
  }

  Future<void> _resolve(Map<String, dynamic> r) async {
    try {
      await _sb.from('user_reports').update({'status': 'resolved'}).eq('id', r['id']);
      setState(() => r['status'] = 'resolved');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo resolver (¿RLS admin?): $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const _EmptyState(message: 'No hay reportes 🎉');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Reportes (${_rows.length})',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = _rows[i];
              final resolved = r['status'] == 'resolved';
              return _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Motivo: ${r['reason'] ?? '—'}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Reportado: ${r['reported_id'] ?? '—'}  ·  Estado: ${r['status'] ?? '—'}',
                            style: TextStyle(
                                fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!resolved)
                      FilledButton(
                        onPressed: () => _resolve(r),
                        child: const Text('Marcar resuelto'),
                      )
                    else
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers compartidos
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: context.textTertiary),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: MployaTheme.danger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final String message;
  const _AccessDenied({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: MployaTheme.brandAccent),
            const SizedBox(height: 16),
            Text('Panel de administración',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
