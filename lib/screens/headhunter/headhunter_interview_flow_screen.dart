import 'package:flutter/cupertino.dart';

import 'headhunter_interview_data.dart';
import 'headhunter_interview_report_screen.dart';

class HeadhunterInterviewFlowScreen extends StatefulWidget {
  const HeadhunterInterviewFlowScreen({
    super.key,
    required this.interviewId,
    this.previewData,
    this.loadOverride,
  });

  final String interviewId;
  final HeadhunterInterviewData? previewData;
  final Future<HeadhunterInterviewData> Function(String id)? loadOverride;

  @override
  State<HeadhunterInterviewFlowScreen> createState() =>
      _HeadhunterInterviewFlowScreenState();
}

class _HeadhunterInterviewFlowScreenState
    extends State<HeadhunterInterviewFlowScreen> {
  HeadhunterInterviewData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewData case final data?) {
      _data = data;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final data =
        await (widget.loadOverride?.call(widget.interviewId) ??
            loadHeadhunterInterview(widget.interviewId));
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Detalle de entrevista'),
        previousPageTitle: 'Entrevistas',
        backgroundColor: CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : _body(),
      ),
    );
  }

  Widget _body() {
    final data = _data!;
    if (data.error) {
      return _state(
        CupertinoIcons.exclamationmark_triangle,
        'No pudimos cargar la entrevista',
        'Revisá tu conexión y volvé a intentar.',
        action: 'Reintentar',
        onAction: _load,
      );
    }
    if (data.notFound) {
      return _state(
        CupertinoIcons.doc_text_search,
        'Entrevista no disponible',
        'No existe o ya no tenés acceso a esta entrevista.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        _candidateCard(data),
        const SizedBox(height: 16),
        _statusCard(data),
        const SizedBox(height: 16),
        _counts(data),
        if (data.isConfidential) ...[
          const SizedBox(height: 16),
          _privacyCard(),
        ],
        if (data.hasReport) ...[
          const SizedBox(height: 22),
          CupertinoButton.filled(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) =>
                    HeadhunterInterviewReportScreen(interviewId: data.id),
              ),
            ),
            child: const Text('Ver informe de entrevista'),
          ),
        ] else ...[
          const SizedBox(height: 22),
          const Text(
            'El informe aparecerá cuando exista un registro real para esta entrevista.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B778C), height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _candidateCard(HeadhunterInterviewData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17112E), Color(0xFF34256E)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF5C43CC),
              shape: BoxShape.circle,
              image: !data.isConfidential && data.avatarUrl?.isNotEmpty == true
                  ? DecorationImage(
                      image: NetworkImage(data.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: data.isConfidential || data.avatarUrl?.isEmpty != false
                ? Icon(
                    data.isConfidential
                        ? CupertinoIcons.lock_fill
                        : CupertinoIcons.person_fill,
                    color: CupertinoColors.white,
                  )
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.candidateName,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.isConfidential
                      ? 'Identidad protegida'
                      : data.candidateHeadline?.isNotEmpty == true
                      ? data.candidateHeadline!
                      : 'Candidato',
                  style: const TextStyle(color: Color(0xFFCDC6E8)),
                ),
                const SizedBox(height: 5),
                Text(
                  data.jobTitle,
                  style: const TextStyle(
                    color: Color(0xFFAFA3D4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(HeadhunterInterviewData data) {
    final label = switch (data.status) {
      'completed' => 'Completada',
      'in_progress' => 'En curso',
      _ => 'Pendiente',
    };
    final color = switch (data.status) {
      'completed' => const Color(0xFF199A5B),
      'in_progress' => const Color(0xFF4C2CF3),
      _ => const Color(0xFFE18A20),
    };
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B778C)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(CupertinoIcons.checkmark_seal_fill, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Creada ${_date(data.createdAt)}${data.completedAt == null ? '' : ' · Finalizada ${_date(data.completedAt!)}'}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B778C)),
          ),
        ],
      ),
    );
  }

  Widget _counts(HeadhunterInterviewData data) {
    return Row(
      children: [
        Expanded(
          child: _metric(
            'Preguntas',
            data.questionCount,
            CupertinoIcons.question_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric(
            'Respuestas',
            data.answerCount,
            CupertinoIcons.videocam,
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, int value, IconData icon) => _card(
    Column(
      children: [
        Icon(icon, color: const Color(0xFF4C2CF3)),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B778C)),
        ),
      ],
    ),
  );

  Widget _privacyCard() => _card(
    const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(CupertinoIcons.shield_fill, color: Color(0xFF4C2CF3)),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'La identidad, imagen, ubicación, contacto y video de este talento están protegidos.',
            style: TextStyle(height: 1.4, color: Color(0xFF3F4960)),
          ),
        ),
      ],
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E9F0)),
    ),
    child: child,
  );

  Widget _state(
    IconData icon,
    String title,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: const Color(0xFF6B778C)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center),
          if (action != null)
            CupertinoButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
