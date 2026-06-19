import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/daily_service.dart';
import '../widgets/jitsi_embed.dart';

class JitsiCallScreen extends StatefulWidget {
  final String myId;
  final String otherId;
  final String displayName;
  final String otherName;

  const JitsiCallScreen({
    super.key,
    required this.myId,
    required this.otherId,
    required this.displayName,
    required this.otherName,
  });

  @override
  State<JitsiCallScreen> createState() => _JitsiCallScreenState();
}

class _JitsiCallScreenState extends State<JitsiCallScreen> {
  String? _roomUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createRoom();
  }

  Future<void> _createRoom() async {
    try {
      final roomName = ChatService.instance.generateJitsiRoom(widget.myId, widget.otherId);
      final url = await DailyService.instance.getOrCreateRoom(roomName);
      if (mounted) setState(() => _roomUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video area
          Positioned.fill(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: const TextStyle(color: Colors.white)),
                    ),
                  )
                : _roomUrl == null
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : JitsiEmbed(
                        roomUrl: _roomUrl!,
                        displayName: widget.displayName,
                        onCallEnded: () {
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
          ),
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.only(top: 52, left: 16, right: 16, bottom: 24),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.chevron_left, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.otherName,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // Botón colgar
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)],
                  ),
                  child: const Icon(CupertinoIcons.phone_down_fill, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
