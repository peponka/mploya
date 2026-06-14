// jitsi_stub_web.dart
// Web stub for jitsi_meet_flutter_sdk
// On web, Jitsi calls open in a new browser tab via url_launcher
// These classes are never instantiated on web (see kIsWeb guard in messaging_screen.dart)

class JitsiMeet {
  Future<void> join(
    JitsiMeetConferenceOptions options,
    JitsiMeetEventListener listener,
  ) async {}
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
