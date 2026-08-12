import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _assistantPrimary = Color(0xFF5B3DF5);
const _assistantBorder = Color(0xFFE3DAFF);
const _assistantText = Color(0xFF15163D);
const _assistantMuted = Color(0xFF69708F);

class AssistantSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AssistantSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _assistantBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F5B3DF5),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AssistantFieldLabel extends StatelessWidget {
  final String title;
  final String? hint;

  const AssistantFieldLabel({super.key, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _assistantText,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _assistantMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class AssistantTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;

  const AssistantTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      maxLines: maxLines,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      placeholderStyle: const TextStyle(color: Color(0xFFA0A6C0)),
      style: const TextStyle(color: _assistantText, fontSize: 15),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _assistantBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x085B3DF5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class AssistantChoiceChips extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const AssistantChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final active = selected.contains(option);
        return GestureDetector(
          onTap: () => onToggle(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active ? _assistantPrimary : CupertinoColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? _assistantPrimary : _assistantBorder,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _assistantPrimary.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              option,
              style: TextStyle(
                color: active ? Colors.white : _assistantText,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class AssistantReviewCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  const AssistantReviewCard({
    super.key,
    required this.title,
    required this.lines,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _assistantBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _assistantText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 30),
                onPressed: onEdit,
                child: const Text(
                  'Editar',
                  style: TextStyle(
                    color: _assistantPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(
                  color: _assistantMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
