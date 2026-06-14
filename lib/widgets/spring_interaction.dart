import 'package:flutter/cupertino.dart';

class SpringInteraction extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  
  const SpringInteraction({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<SpringInteraction> createState() => _SpringInteractionState();
}

class _SpringInteractionState extends State<SpringInteraction> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
