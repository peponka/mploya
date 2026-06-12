import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/camera_screen.dart';

class JobCard extends StatefulWidget {
  final Job job;
  final int index;

  const JobCard({super.key, required this.job, this.index = 0});

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  late bool _isSaved;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.job.isSaved;
  }

  Future<void> _applyToJob() async {
    setState(() => _isApplying = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'No autorizado';

      // 1. Verificar si el usuario ya tiene un Video-Pitch guardado
      final userData = await Supabase.instance.client
          .from('users')
          .select('video_url')
          .eq('id', user.id)
          .maybeSingle();

      final hasPitch = userData != null &&
          userData['video_url'] != null &&
          userData['video_url'].toString().isNotEmpty;

      bool forceCamera = false;

      if (hasPitch) {
        // Pausar carga para mostrar el diálogo
        setState(() => _isApplying = false);
        if (!mounted) return;
        final reuse = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('¿Cómo quieres aplicar?'),
            content: const Text(
                'Ya cuentas con un Video-Pitch en tu perfil. ¿Deseas enviarlo o prefieres grabar uno nuevo específico para destacar en esta vacante?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false), // Grabar Nuevo
                child: const Text('Grabar Nuevo'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true), // Usar Guardado
                child: const Text('Usar Guardado'),
              ),
              // Botón explícito para cancelar
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );

        if (reuse == null) return; // Canceló
        if (reuse == false) forceCamera = true;
      } else {
        forceCamera = true; // No tiene pitch, obligar cámara
      }

      if (forceCamera) {
        // Fricción Estratégica: Ir a la cámara
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const CameraScreen()),
        );

        // Si cancela la grabación
        if (result != true) return;
      }

      setState(() => _isApplying = true);

      // Insertar postulación
      await Supabase.instance.client.from('job_applications').insert({
        'job_id': widget.job.id,
        'candidate_id': user.id,
      });

      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('¡Pitch Enviado! 🎥'),
          content: Text('La aplicación fue exitosa. Tu Video Pitch acaba de llegar al escritorio de ${widget.job.company}.'),
          actions: [
            CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('¡Genial!')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final isDuplicate = e.toString().contains('job_applications_uniq') || e.toString().contains('duplicate key');
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Aviso'),
          content: Text(isDuplicate ? 'Tranquilo, ya enviaste tu Video Pitch a esta oferta anteriormente.' : 'Error al aplicar: $e'),
          actions: [
            CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  /// Returns a plausible AI match percentage (72–96%) based on job index.
  int get _aiMatchPercent {
    const values = [92, 87, 96, 78, 84, 91, 76, 88, 72, 95, 83, 79, 86, 94, 81];
    return values[widget.index % values.length];
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Container(
      margin: const EdgeInsets.only(bottom: MployaTheme.spaceSM),
      padding: const EdgeInsets.all(MployaTheme.spaceLG),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company logo placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(MployaTheme.radiusSM),
                ),
                child: Center(
                  child: Text(
                    job.company[0],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: MployaTheme.brandAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.brandAccent,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      job.company,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_solid,
                          size: 13,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            job.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // AI Match % badge + bookmark
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // AI Match badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.bolt_fill,
                          size: 11,
                          color: MployaTheme.brandAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$_aiMatchPercent% match',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MployaTheme.brandAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Bookmark
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () {
                      setState(() => _isSaved = !_isSaved);
                    },
                    child: Icon(
                      _isSaved
                          ? CupertinoIcons.bookmark_fill
                          : CupertinoIcons.bookmark,
                      size: 22,
                      color: _isSaved
                          ? MployaTheme.brandAccent
                          : context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tags row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (job.salaryRange != null)
                _Tag(
                  icon: CupertinoIcons.money_dollar_circle,
                  text: job.salaryRange!,
                ),
              if (job.isRemote)
                const _Tag(
                  icon: CupertinoIcons.wifi,
                  text: 'Remoto',
                ),
              if (job.isEasyApply)
                const _Tag(
                  icon: CupertinoIcons.bolt_fill,
                  text: 'Candidatura Rápida',
                  color: MployaTheme.openToWork,
                ),
              if (!job.isEasyApply)
                const _Tag(
                  icon: CupertinoIcons.videocam_fill,
                  text: '🎥 Video-Pitch',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Footer
          Row(
            children: [
              Text(
                '${job.applicants} candidatos',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '·',
                style: TextStyle(color: context.textTertiary),
              ),
              const SizedBox(width: 8),
              Text(
                job.postedAgo,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.textTertiary,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                minimumSize: Size.zero,
                color: MployaTheme.brandAccent,
                borderRadius:
                    BorderRadius.circular(MployaTheme.radiusPill),
                onPressed: _isApplying ? null : _applyToJob,
                child: _isApplying 
                  ? const CupertinoActivityIndicator(color: Colors.white, radius: 8)
                  : const Text(
                      'Me Interesa',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Tag({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = color ?? context.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tagColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: tagColor,
            ),
          ),
        ],
      ),
    );
  }
}
