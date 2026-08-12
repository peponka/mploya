import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'onboarding_tour_screen.dart';

class TalentOnboardingCompleteScreen extends StatelessWidget {
  const TalentOnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  _TopBar(onClose: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const Text(
                            'Tu perfil esta listo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15163D),
                              letterSpacing: -1.2,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Completaste tu perfil y ya estas listo para recibir oportunidades increibles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF69708F),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 164,
                                height: 164,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF4C7),
                                      Color(0xFFF4EBFF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF5B3DF5,
                                      ).withValues(alpha: 0.14),
                                      blurRadius: 28,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.person_crop_circle_fill,
                                    size: 112,
                                    color: Color(0xFFB9B3FF),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 10,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF5B3DF5),
                                        Color(0xFF7E66FF),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.pencil_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Expanded(child: _CompletionRing()),
                              SizedBox(width: 16),
                              Expanded(child: _AiScoreCard()),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _RecommendationCard(),
                          const SizedBox(height: 18),
                          const _ConfidentialCard(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostActionButton(
                          label: 'Grabar otro video',
                          icon: CupertinoIcons.video_camera,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: _PrimaryActionButton(
                          label: 'Ir al Feed',
                          subtitle: 'Descubri oportunidades',
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              CupertinoPageRoute(
                                builder: (_) => const OnboardingTourScreen(
                                  accountType: 'candidato',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;

  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B3DF5), Color(0xFF7E66FF)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Asistente A10',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onClose,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.xmark, color: Color(0xFF15163D)),
          ),
        ),
      ],
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 208,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3DAFF)),
      ),
      child: Center(
        child: SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 0.95,
                strokeWidth: 10,
                backgroundColor: const Color(0xFFECE7FF),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF5B3DF5),
                ),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '95%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15163D),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Perfil completado',
                      style: TextStyle(fontSize: 14, color: Color(0xFF69708F)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiScoreCard extends StatelessWidget {
  const _AiScoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 208,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3DAFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.sparkles, color: Color(0xFF5B3DF5), size: 18),
              SizedBox(width: 8),
              Text(
                'IA Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15163D),
                ),
              ),
            ],
          ),
          SizedBox(height: 26),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '8.7',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B3DF5),
                  ),
                ),
                TextSpan(
                  text: ' / 10',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7A819E),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Excelente!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF12A150),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Tu perfil tiene altas posibilidades de match.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF69708F),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3DAFF)),
      ),
      child: Column(
        children: const [
          Row(
            children: [
              Icon(CupertinoIcons.sparkles, color: Color(0xFF5B3DF5)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recomendaciones de la IA',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15163D),
                  ),
                ),
              ),
              _SmallBadge(label: '3 sugerencias'),
            ],
          ),
          SizedBox(height: 18),
          _RecommendationRow(
            icon: CupertinoIcons.video_camera,
            iconBg: Color(0xFFF0EAFF),
            iconColor: Color(0xFF5B3DF5),
            title: 'Graba otro video',
            subtitle: 'Los perfiles con 2 videos reciben 3x mas visitas.',
          ),
          _RecommendationDivider(),
          _RecommendationRow(
            icon: CupertinoIcons.rosette,
            iconBg: Color(0xFFE9F9EF),
            iconColor: Color(0xFF12A150),
            title: 'Agrega mas certificaciones',
            subtitle: 'Aumenta tu credibilidad y destacate mas.',
          ),
          _RecommendationDivider(),
          _RecommendationRow(
            icon: CupertinoIcons.folder,
            iconBg: Color(0xFFFFF6DF),
            iconColor: Color(0xFFFFB020),
            title: 'Completa tu portfolio',
            subtitle: 'Mostra mas proyectos y logros.',
          ),
        ],
      ),
    );
  }
}

class _ConfidentialCard extends StatelessWidget {
  const _ConfidentialCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3DAFF)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE9F9EF),
            child: Icon(
              CupertinoIcons.shield_lefthalf_fill,
              color: Color(0xFF12A150),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu perfil es confidencial',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15163D),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Solo empresas que vos apruebes podran ver tu informacion completa.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF69708F),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.lock_fill, color: Color(0xFFC0B2FF), size: 54),
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _RecommendationRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: iconBg,
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15163D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF69708F),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const Icon(CupertinoIcons.chevron_right, color: Color(0xFF98A1C4)),
      ],
    );
  }
}

class _RecommendationDivider extends StatelessWidget {
  const _RecommendationDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: Color(0xFFF0ECFF)),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;

  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5B3DF5),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _GhostActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFB9A8FF), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF5B3DF5), size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5B3DF5),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B3DF5), Color(0xFF7E66FF)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B3DF5).withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: const Icon(
                CupertinoIcons.compass,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.arrow_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
