import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../web_centered.dart';

const _assistantPrimary = Color(0xFF5B3DF5);
const _assistantPrimarySoft = Color(0xFFF2EEFF);
const _assistantBorder = Color(0xFFE3DAFF);
const _assistantText = Color(0xFF15163D);
const _assistantMuted = Color(0xFF69708F);

class AssistantShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final int currentStep;
  final int totalSteps;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onClose;

  const AssistantShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
    this.footer,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8F5FF), Color(0xFFFFFFFF), Color(0xFFF6F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: WebCentered(
          maxWidth: 760,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              children: [
                _AssistantTopBar(
                  currentStep: currentStep,
                  totalSteps: totalSteps,
                  onClose: onClose,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _assistantBorder),
                      boxShadow: [
                        BoxShadow(
                          color: _assistantPrimary.withValues(alpha: 0.10),
                          blurRadius: 36,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eyebrow.toUpperCase(),
                                style: const TextStyle(
                                  color: _assistantPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: _assistantText,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.9,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: _assistantMuted,
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              AssistantProgressBar(
                                currentStep: currentStep,
                                totalSteps: totalSteps,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: child,
                          ),
                        ),
                        if (footer != null) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                            child: footer!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onClose;

  const _AssistantTopBar({
    required this.currentStep,
    required this.totalSteps,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_assistantPrimary, Color(0xFF8F7BFF)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(
            CupertinoIcons.sparkles,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assistant de Talento',
                style: TextStyle(
                  color: _assistantText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Paso $currentStep de $totalSteps',
                style: const TextStyle(color: _assistantMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (onClose != null)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(38, 38),
            onPressed: onClose,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _assistantBorder),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.xmark,
                size: 18,
                color: _assistantMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class AssistantProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const AssistantProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps <= 0 ? 0.0 : currentStep / totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: _assistantPrimarySoft,
            valueColor: const AlwaysStoppedAnimation<Color>(_assistantPrimary),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(totalSteps, (index) {
            final stepNumber = index + 1;
            final active = stepNumber <= currentStep;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _assistantPrimary : _assistantPrimarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class AssistantFooterBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isBusy;

  const AssistantFooterBar({
    super.key,
    this.onBack,
    required this.onNext,
    required this.nextLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: isBusy ? null : onBack,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _assistantBorder),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Atras',
                  style: TextStyle(
                    color: _assistantPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        if (onBack != null) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: isBusy ? null : onNext,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_assistantPrimary, Color(0xFF7E66FF)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _assistantPrimary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: isBusy
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(
                      nextLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(width: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: isBusy ? null : onSecondary,
            child: const Text(
              'Saltar por ahora',
              style: TextStyle(
                color: _assistantMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
