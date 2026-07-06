import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
// En web usa el iframe de Jitsi embebido; en móvil el stub (no se usa).
import '../widgets/jitsi_web_view_stub.dart'
    if (dart.library.html) '../widgets/jitsi_web_view.dart';

const _appId = String.fromEnvironment('AGORA_APP_ID');
const _tokenUrl = 'https://qclipzefqndcefwwixdy.supabase.co/functions/v1/agora-token';

class AgoraCallScreen extends StatefulWidget {
  final String channelName;
  final String displayName;
  final String otherName;

  const AgoraCallScreen({
    super.key,
    required this.channelName,
    required this.displayName,
    required this.otherName,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localVideoReady = false;
  bool _muted = false;
  bool _videoOff = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // En web NO inicializamos Agora (no soporta web de forma fiable): la llamada
    // se resuelve con el iframe de Jitsi embebido que se renderiza en build().
    if (!kIsWeb) _init();
  }

  // Devuelve token + appId. El appId lo manda el servidor (es público, no
  // secreto) para no depender de un --dart-define en cada build — que es
  // justamente lo que faltaba y hacía crashear la llamada (appId vacío).
  Future<({String token, String appId})> _fetchToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    final jwt = session?.accessToken ?? '';
    final resp = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({'channelName': widget.channelName, 'uid': 0}),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Token ${resp.statusCode}: ${resp.body}');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    // Respaldo al valor de compilación por si la función aún no fue actualizada.
    final appId = (data['appId'] as String?)?.isNotEmpty == true
        ? data['appId'] as String
        : _appId;
    return (token: data['token'] as String, appId: appId);
  }

  Future<void> _init() async {
    await [Permission.camera, Permission.microphone].request();

    try {
      final creds = await _fetchToken();
      final token = creds.token;

      if (creds.appId.isEmpty) {
        if (mounted) setState(() => _error = 'La videollamada no está configurada (falta App ID).');
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: creds.appId));

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (mounted) setState(() => _localVideoReady = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          if (mounted) setState(() => _error = 'Agora error $err: $msg');
        },
      ));

      await _engine!.enableVideo();
      await _engine!.startPreview();
      await _engine!.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine?.muteLocalAudioStream(_muted);
  }

  void _toggleVideo() {
    setState(() => _videoOff = !_videoOff);
    _engine?.muteLocalVideoStream(_videoOff);
  }

  // ── Web: videollamada Jitsi embebida dentro de la app ──
  Widget _buildWebJitsi(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Videollamada con ${widget.otherName}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: buildJitsiWebView(widget.channelName, widget.displayName)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebJitsi(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video remoto
          Positioned.fill(
            child: _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ))
                : !_localVideoReady
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 12),
                        Text('Canal: ${widget.channelName.substring(0, widget.channelName.length.clamp(0, 20))}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ]))
                    : _remoteUid != null
                        ? AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: _engine!,
                              canvas: VideoCanvas(uid: _remoteUid),
                              connection: RtcConnection(channelId: widget.channelName),
                            ),
                          )
                        : Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 16),
                              Text('Esperando a ${widget.otherName}...', style: const TextStyle(color: Colors.white, fontSize: 16)),
                            ],
                          )),
          ),

          // Video local (esquina)
          if (_localVideoReady && _engine != null)
            Positioned(
              top: 80,
              right: 16,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

          // Header
          Positioned(
            top: 0, left: 0, right: 0,
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
                  Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          // Controles
          Positioned(
            bottom: 48, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlButton(icon: _muted ? CupertinoIcons.mic_slash_fill : CupertinoIcons.mic_fill, onTap: _toggleMute, active: !_muted),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 16)],
                    ),
                    child: const Icon(CupertinoIcons.phone_down_fill, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 24),
                _ControlButton(icon: _videoOff ? Icons.videocam_off : CupertinoIcons.video_camera_solid, onTap: _toggleVideo, active: !_videoOff),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _ControlButton({required this.icon, required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: active ? Colors.white24 : Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: active ? Colors.white : Colors.black, size: 24),
      ),
    );
  }
}
