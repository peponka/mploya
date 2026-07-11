import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/employer_rating_service.dart';
import '../widgets/spring_interaction.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployerRatingSection — Sección de rating en perfil de empresa
//
// Muestra:
//   • Rating promedio con estrellas
//   • Desglose por categoría (comunicación, transparencia, respeto)
//   • Badge de recomendación
//   • Botón para calificar (si aplica)
//   • Lista de reviews recientes
// ─────────────────────────────────────────────────────────────────────────────

class EmployerRatingSection extends StatefulWidget {
  final String companyId;
  final String companyAccountType;
  final bool isOwnProfile;

  const EmployerRatingSection({
    super.key,
    required this.companyId,
    required this.companyAccountType,
    required this.isOwnProfile,
  });

  @override
  State<EmployerRatingSection> createState() => _EmployerRatingSectionState();
}

class _EmployerRatingSectionState extends State<EmployerRatingSection> {
  EmployerRatingSummary? _summary;
  List<EmployerReview> _reviews = [];
  bool _isLoading = true;
  EmployerReview? _myReview;

  bool get _isCompanyProfile =>
      widget.companyAccountType == 'empresa' ||
      widget.companyAccountType == 'headhunter';

  @override
  void initState() {
    super.initState();
    if (_isCompanyProfile) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await EmployerRatingService.instance.getSummary(widget.companyId);
      final reviews = await EmployerRatingService.instance.getReviews(widget.companyId, limit: 5);
      EmployerReview? myReview;
      if (!widget.isOwnProfile) {
        myReview = await EmployerRatingService.instance.getMyReview(widget.companyId);
      }
      if (mounted) {
        setState(() {
          _summary = summary;
          _reviews = reviews;
          _myReview = myReview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCompanyProfile) return const SizedBox.shrink();

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CupertinoActivityIndicator(radius: 12)),
      );
    }

    final summary = _summary ?? const EmployerRatingSummary();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(NexTheme.radiusMD),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [NexTheme.premiumGold, NexTheme.premiumGoldBright],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(CupertinoIcons.star_fill, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'Reputación',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (summary.badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: summary.avgOverall >= 4.0
                          ? NexTheme.success.withValues(alpha: 0.10)
                          : NexTheme.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(NexTheme.radiusPill),
                    ),
                    child: Text(
                      summary.badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: summary.avgOverall >= 4.0
                            ? NexTheme.success
                            : NexTheme.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Rating Overview (o estado vacío si no hay reseñas) ──
          if (summary.totalReviews > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Big rating number
                  Column(
                    children: [
                      Text(
                        '${summary.avgOverall}',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: context.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      _buildStarsRow(summary.avgOverall, 18),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.totalReviews} opiniones',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  // Category bars
                  Expanded(
                    child: Column(
                      children: [
                        _categoryBar(context, 'Comunicación', summary.avgCommunication),
                        const SizedBox(height: 6),
                        _categoryBar(context, 'Transparencia', summary.avgTransparency),
                        const SizedBox(height: 6),
                        _categoryBar(context, 'Respeto', summary.avgRespect),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: NexTheme.premiumGold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NexTheme.premiumGold.withValues(alpha: 0.16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: NexTheme.premiumGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(CupertinoIcons.star, color: NexTheme.premiumGold, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Todavía sin reseñas',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Las primeras opiniones aparecerán acá.',
                              style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Response time badge ──
          if (summary.responseTimeBadge.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: NexTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary.responseTimeBadge,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NexTheme.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // ── Rate button (for candidates viewing a company) ──
          if (!widget.isOwnProfile)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SpringInteraction(
                onTap: () => _showRateDialog(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _myReview != null
                        ? NexTheme.brandAccent.withValues(alpha: 0.10)
                        : NexTheme.brandAccent,
                    borderRadius: BorderRadius.circular(NexTheme.radiusPill),
                  ),
                  child: Text(
                    _myReview != null
                        ? '✏️ Editar mi calificación (${_myReview!.overallStars}⭐)'
                        : '⭐ Calificar esta empresa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _myReview != null
                          ? NexTheme.brandAccent
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // ── Recent Reviews ──
          if (_reviews.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Opiniones recientes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ),
            ..._reviews.take(3).map((r) => _buildReviewCard(context, r)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildStarsRow(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        if (rating >= starValue) {
          return Icon(CupertinoIcons.star_fill, size: size, color: NexTheme.premiumGold);
        } else if (rating >= starValue - 0.5) {
          return Icon(CupertinoIcons.star_lefthalf_fill, size: size, color: NexTheme.premiumGold);
        } else {
          return Icon(CupertinoIcons.star, size: size, color: NexTheme.premiumGold.withValues(alpha: 0.3));
        }
      }),
    );
  }

  Widget _categoryBar(BuildContext context, String label, double value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 5.0,
              minHeight: 6,
              backgroundColor: context.dividerColor,
              valueColor: AlwaysStoppedAnimation(
                value >= 4.0 ? NexTheme.success :
                value >= 3.0 ? NexTheme.premiumGold :
                NexTheme.danger,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            value > 0 ? value.toStringAsFixed(1) : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, EmployerReview review) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: NexTheme.brandAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                child: Text(
                    (review.candidateName ?? 'C').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: NexTheme.brandAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.candidateName ?? 'Candidato',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    if (review.candidateHeadline != null)
                      Text(
                        review.candidateHeadline!,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _buildStarsRow(review.overallStars, 12),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 13,
                color: context.textPrimary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── Rate Dialog ──
  void _showRateDialog(BuildContext context) {
    double overallStars = _myReview?.overallStars ?? 4.0;
    double commStars = _myReview?.communicationStars ?? 0;
    double transStars = _myReview?.transparencyStars ?? 0;
    double respStars = _myReview?.respectStars ?? 0;
    final commentController = TextEditingController(text: _myReview?.comment);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.separator,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    '⭐ Calificá tu experiencia',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu opinión ayuda a otros candidatos.',
                    style: TextStyle(fontSize: 14, color: context.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Overall stars
                  Text('General', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  _buildStarSelector(overallStars, (v) => setModalState(() => overallStars = v)),
                  const SizedBox(height: 16),

                  // Communication
                  Text('Comunicación', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  _buildStarSelector(commStars, (v) => setModalState(() => commStars = v)),
                  const SizedBox(height: 16),

                  // Transparency
                  Text('Transparencia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  _buildStarSelector(transStars, (v) => setModalState(() => transStars = v)),
                  const SizedBox(height: 16),

                  // Respect
                  Text('Respeto / Profesionalismo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  _buildStarSelector(respStars, (v) => setModalState(() => respStars = v)),
                  const SizedBox(height: 16),

                  // Comment
                  Text('Comentario (opcional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: commentController,
                    placeholder: '¿Cómo fue tu experiencia?',
                    padding: const EdgeInsets.all(12),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: NexTheme.brandAccent,
                      borderRadius: BorderRadius.circular(NexTheme.radiusPill),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final error = await EmployerRatingService.instance.submitReview(
                          companyId: widget.companyId,
                          overallStars: overallStars,
                          communicationStars: commStars > 0 ? commStars : overallStars,
                          transparencyStars: transStars > 0 ? transStars : overallStars,
                          respectStars: respStars > 0 ? respStars : overallStars,
                          comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
                        );

                        if (error != null && mounted) {
                          showCupertinoDialog(
                            // ignore: use_build_context_synchronously
                            context: context,
                            builder: (d) => CupertinoAlertDialog(
                              title: const Text('Error'),
                              content: Text(error),
                              actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                            ),
                          );
                        } else {
                          await _loadData();
                        }
                      },
                      child: Text(
                        _myReview != null ? 'Actualizar calificación' : 'Enviar calificación',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStarSelector(double currentValue, ValueChanged<double> onChanged) {
    return Row(
      children: List.generate(5, (i) {
        final starValue = (i + 1).toDouble();
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              currentValue >= starValue
                  ? CupertinoIcons.star_fill
                  : CupertinoIcons.star,
              size: 32,
              color: currentValue >= starValue
                  ? NexTheme.premiumGold
                  : NexTheme.premiumGold.withValues(alpha: 0.3),
            ),
          ),
        );
      }),
    );
  }
}
