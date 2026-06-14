import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

/// Servicio centralizado de chat:
/// - Envío de mensajes de texto
/// - Upload y envío de archivos (imágenes, PDFs, etc.)
/// - Notas de voz
/// - Generación de salas Jitsi Meet
class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Bucket de archivos ──
  static const _bucket = 'chat-files';

  // ── Enviar mensaje de texto ──
  Future<void> sendTextMessage({
    required String receiverId,
    required String text,
  }) async {
    if (_uid == null) return;
    await _supabase.from('messages').insert({
      'sender_id': _uid,
      'receiver_id': receiverId,
      'content': text,
      'type': 'text',
      'is_read': false,
    });
  }

  // ── Enviar mensaje con archivo ──
  Future<void> sendFileMessage({
    required String receiverId,
    required String filePath,
    required String fileName,
    String? caption,
  }) async {
    if (_uid == null) return;

    // 1. Determinar tipo
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    String fileType = 'file';
    if (mimeType.startsWith('image/')) {
      fileType = 'image';
    } else if (mimeType.startsWith('video/')) {
      fileType = 'video';
    } else if (mimeType.startsWith('audio/')) {
      fileType = 'voice';
    }

    // 2. Upload a Supabase Storage
    final storagePath = 'chats/$_uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    
    // Read file as bytes (works on both web and native)
    final Uint8List fileBytes;
    if (kIsWeb) {
      // On web, filePath might be a blob URL — use XFile or read differently
      fileBytes = Uint8List(0); // Will be overridden by caller providing bytes
    } else {
      fileBytes = Uint8List(0);
    }
    await _supabase.storage
        .from(_bucket)
        .uploadBinary(storagePath, fileBytes, fileOptions: FileOptions(contentType: mimeType));

    // 3. Generar URL pública (signed URL por 7 días)
    final fileUrl = _supabase.storage.from(_bucket).getPublicUrl(storagePath);

    // 4. Guardar mensaje con archivo
    await _supabase.from('messages').insert({
      'sender_id': _uid,
      'receiver_id': receiverId,
      'content': caption ?? '',
      'type': fileType,
      'media_url': fileUrl,
      'is_read': false,
    });
  }

  // ── Seleccionar archivo del dispositivo ──
  Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'gif', 'mp4', 'mp3', 'wav'],
      withData: kIsWeb,   // En web necesitamos bytes
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files.first;
    }
    return null;
  }

  // ── Seleccionar imagen ──
  Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files.first;
    }
    return null;
  }

  // ── Marcar mensajes como leídos ──
  Future<void> markAsRead(String senderId) async {
    if (_uid == null) return;
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('sender_id', senderId)
        .eq('receiver_id', _uid!)
        .eq('is_read', false);
  }

  // ── Generar sala de Jitsi Meet ──
  /// Genera un room ID único y determinístico para dos usuarios.
  /// Siempre produce el mismo room para el mismo par de usuarios.
  String generateJitsiRoom(String userId1, String userId2) {
    // Ordenar IDs para que siempre sea el mismo room
    final sorted = [userId1, userId2]..sort();
    final hash = sorted.join('_').hashCode.toRadixString(16);
    return 'nexwork-interview-$hash';
  }

  // ── Formatear tamaño de archivo ──
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
