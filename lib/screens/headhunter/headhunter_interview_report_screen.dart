import 'package:flutter/cupertino.dart';

import 'headhunter_interview_data.dart';

class HeadhunterInterviewReportScreen extends StatefulWidget {
  const HeadhunterInterviewReportScreen({
    super.key,
    required this.interviewId,
    this.previewData,
    this.loadOverride,
  });

  final String interviewId;
  final HeadhunterInterviewReportData? previewData;
  final Future<HeadhunterInterviewReportData> Function(String id)? loadOverride;

  @override
  State<HeadhunterInterviewReportScreen> createState() =>
      _HeadhunterInterviewReportScreenState();
}

class _HeadhunterInterviewReportScreenState
    extends State<HeadhunterInterviewReportScreen> {
  HeadhunterInterviewReportData? _data;
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
            loadHeadhunterInterviewReport(widget.interviewId));
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0D111C),
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(
            CupertinoIcons.chevron_back,
            color: CupertinoColors.white,
          ),
        ),
        middle: const Text(
          'Informe de entrevista',
          style: TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: const Color(0xFF0D111C),
        border: null,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(
                child: CupertinoActivityIndicator(color: CupertinoColors.white),
              )
            : _body(),
      ),
    );
  }

  Widget _body() {
    final data = _data!;
    if (data.error) {
      return _state(
        'No pudimos cargar el informe',
        'Revisá tu conexión y volvé a intentar.',
        retry: true,
      );
    }
    if (data.notFound || !data.hasContent) {
      return _state(
        'Informe no disponible',
        'Esta entrevista todavía no tiene un informe real generado.',
      );
    }
    final interview = data.interview;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      children: [
        const Row(
          children: [
            Icon(CupertinoIcons.sparkles, color: Color(0xFF8B6CFF)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resumen de la entrevista',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _card(
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF4C2CF3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  interview.isConfidential
                      ? CupertinoIcons.lock_fill
                      : CupertinoIcons.person_fill,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interview.candidateName,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      interview.isConfidential
                          ? 'Identidad protegida'
                          : interview.jobTitle,
                      style: const TextStyle(color: Color(0xFFADB6C8)),
                    ),
                  ],
                ),
              ),
              if (data.score case final score?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6B4A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score/100',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (interview.isConfidential) ...[
          const SizedBox(height: 12),
          _card(
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.shield_fill, color: Color(0xFF8B6CFF)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este informe preserva la identidad, imagen, ubicación, contacto y video del talento.',
                    style: TextStyle(color: Color(0xFFD1D6E2), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!interview.isConfidential && data.summary?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          _section('Resumen', data.summary!),
        ],
        if (!interview.isConfidential &&
            data.rationale?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          _section('Fundamento', data.rationale!),
        ],
        if (data.competencies.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Competencias',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in data.competencies)
                  _competency(item, hideFreeText: interview.isConfidential),
              ],
            ),
          ),
        ],
        if (!interview.isConfidential && data.keywords.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Palabras clave',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: data.keywords
                      .map(
                        (keyword) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF29233D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            keyword,
                            style: const TextStyle(color: Color(0xFFC9BBFF)),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _competency(Map<String, dynamic> item, {required bool hideFreeText}) {
    final name = item['name']?.toString().trim() ?? '';
    final note = hideFreeText ? '' : item['note']?.toString().trim() ?? '';
    final score = item['score'] is num ? (item['score'] as num).round() : null;
    if (name.isEmpty && note.isEmpty && score == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Competencia' : name,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (score != null)
                Text(
                  '$score/100',
                  style: const TextStyle(color: Color(0xFF65D6A1)),
                ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(color: Color(0xFFADB6C8), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, String text) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          text,
          style: const TextStyle(color: Color(0xFFD1D6E2), height: 1.5),
        ),
      ],
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFF171D29),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF293143)),
    ),
    child: child,
  );

  Widget _state(String title, String message, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.doc_text_search,
            size: 48,
            color: Color(0xFF8B6CFF),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFADB6C8)),
          ),
          if (retry)
            CupertinoButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
