import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class VacantesScreen extends StatefulWidget {
  const VacantesScreen({super.key});

  @override
  State<VacantesScreen> createState() => _VacantesScreenState();
}

class _VacantesScreenState extends State<VacantesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vacantes = [];

  @override
  void initState() {
    super.initState();
    _fetchVacantes();
  }

  Future<void> _fetchVacantes() async {
    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await _supabase
          .from('jobs')
          .select()
          .eq('company_id', uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _vacantes = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch vacantes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateJobModal() {
    final titleCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    bool isStealth = false;
    bool isPublishing = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lanzar Nueva Búsqueda', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    CupertinoTextField(
                      controller: titleCtrl,
                      placeholder: 'Ej. CTO / Mkt Director',
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: salaryCtrl,
                      placeholder: 'Rango Salarial (Ej. \$90K - \$120K)',
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: tagsCtrl,
                      placeholder: 'Reglas Algoritmo (#React, #B2B, #Ingles)',
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Estrategia de Sourcing:', style: TextStyle(color: context.textSecondary)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setModalState(() => isStealth = !isStealth),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isStealth ? MployaTheme.brandAccent.withValues(alpha: 0.08) : CupertinoColors.systemGrey6.resolveFrom(context),
                          border: Border.all(color: isStealth ? MployaTheme.brandAccent : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Radar C-Level (Stealth)', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                            if (isStealth) const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: MployaTheme.brandAccent)
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: MployaTheme.brandAccent,
                        borderRadius: BorderRadius.circular(30),
                        child: isPublishing 
                            ? const CupertinoActivityIndicator(color: Colors.white) 
                            : const Text('Publicar Vacante con GPS', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (titleCtrl.text.isEmpty || isPublishing) return;
                          
                          setModalState(() => isPublishing = true);

                          final uid = _supabase.auth.currentUser?.id;
                          if (uid != null) {
                            try {
                              double? lat, lng;
                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (serviceEnabled) {
                                  LocationPermission permission = await Geolocator.checkPermission();
                                  if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                                      final pos = await Geolocator.getCurrentPosition(
                                        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
                                      );
                                      lat = pos.latitude;
                                      lng = pos.longitude;
                                  }
                              }

                              final listTags = tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                              await _supabase.rpc('create_job_with_postgis', params: {
                                'p_title': titleCtrl.text,
                                'p_salary': salaryCtrl.text,
                                'p_tags': listTags,
                                'p_is_stealth': isStealth,
                                'p_lat': lat,
                                'p_lng': lng,
                              });

                              if (!context.mounted) return;
                              Navigator.pop(ctx);
                              _fetchVacantes();
                            } catch (e) {
                              debugPrint('Error creando job geoespacial: $e');
                              setModalState(() => isPublishing = false);
                            }
                          }
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor,
        middle: Text('Mis Vacantes Activas', style: TextStyle(color: context.textPrimary)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showCreateJobModal,
          child: const Icon(CupertinoIcons.add_circled_solid, color: MployaTheme.brandAccent),
        ),
      ),
      child: SafeArea(
        child: _isLoading 
            ? const Center(child: CupertinoActivityIndicator())
            : _vacantes.isEmpty 
               ? _buildEmptyState()
               : ListView.builder(
                   padding: const EdgeInsets.all(16),
                   itemCount: _vacantes.length + 1,
                   itemBuilder: (context, index) {
                     if (index == 0) {
                       return Padding(
                         padding: const EdgeInsets.only(bottom: 16),
                         child: Text('Plazas Disponibles', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                       );
                     }
                     final job = _vacantes[index - 1];
                     final isStealth = job['type'] == 'Stealth';
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 16),
                       child: _buildVacanteCard(
                           job['title'] ?? 'Sin Título',
                           '${job['salary_range'] ?? 'Salario No Info'} / ${job['location'] ?? 'Remoto'}',
                           '0 matches en pipeline',
                           isStealth
                       ),
                     );
                   },
                 ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text('No has publicado vacantes.\n\nToca el icono "+" arriba a la derecha para lanzar tu primera búsqueda.', textAlign: TextAlign.center, style: TextStyle(color: context.textTertiary)),
    ),
  );

  Widget _buildVacanteCard(String title, String subtitle, String status, bool isStealth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.cardShadow,
        border: isStealth ? Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
              if (isStealth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('C-Level Radar', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.w800)),
                )
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(CupertinoIcons.person_2_fill, color: MployaTheme.brandAccent, size: 16),
              const SizedBox(width: 8),
              Text(status, style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}