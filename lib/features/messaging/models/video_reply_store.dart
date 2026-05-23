/// Simple singleton to pass the last recorded video blob URL
/// between the VideoReplyScreen and the ChatScreen.
///
/// In production this would be a server URL, but for the prototype
/// we use the in-memory blob URL from MediaRecorder.
library;

class VideoReplyStore {
  VideoReplyStore._();

  static String? lastRecordedBlobUrl;
  static String? lastRecipientName;

  static void store({required String blobUrl, required String recipientName}) {
    lastRecordedBlobUrl = blobUrl;
    lastRecipientName = recipientName;
  }

  static void clear() {
    lastRecordedBlobUrl = null;
    lastRecipientName = null;
  }
}
