// jitsi_stub_mobile.dart
// Mobile stub for jitsi_meet_flutter_sdk.
// Abre la sala en el navegador externo en lugar del SDK nativo.

import 'package:url_launcher/url_launcher.dart';

class JitsiMeet {
  Future<void> join(
    JitsiMeetConferenceOptions options,
    JitsiMeetEventListener listener,
  ) async {
    final url = Uri.parse('${options.serverURL ?? "https://meet.jit.si"}/${options.room}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class JitsiMeetConferenceOptions {
  final String room;
  final String? serverURL;
  final JitsiMeetUserInfo? userInfo;
  final Map<String, Object>? featureFlags;
  final Map<String, Object>? configOverrides;

  const JitsiMeetConferenceOptions({
    required this.room,
    this.serverURL,
    this.userInfo,
    this.featureFlags,
    this.configOverrides,
  });
}

class JitsiMeetUserInfo {
  final String? displayName;
  final String? avatar;
  final String? email;

  const JitsiMeetUserInfo({
    this.displayName,
    this.avatar,
    this.email,
  });
}

class JitsiMeetEventListener {
  final void Function(String url)? conferenceJoined;
  final void Function(String url, Object? error)? conferenceTerminated;
  final void Function(String url)? conferenceWillJoin;
  final void Function(String participantId)? participantLeft;

  const JitsiMeetEventListener({
    this.conferenceJoined,
    this.conferenceTerminated,
    this.conferenceWillJoin,
    this.participantLeft,
  });
}
