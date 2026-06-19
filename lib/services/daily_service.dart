import 'dart:convert';
import 'package:http/http.dart' as http;

class DailyService {
  static final DailyService instance = DailyService._();
  DailyService._();

  static const _apiKey = 'd0238698f61a3ab2b6d63ed9e158da339737190ddfc7126da829d2757d8edbf8';
  static const _domain = 'mploya';

  // Crea o reutiliza una sala Daily.co y devuelve la URL embebible
  Future<String> getOrCreateRoom(String roomName) async {
    // Nombre compatible con Daily.co: solo letras, números y guiones
    final safeName = roomName.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '-').toLowerCase();

    // Intentar crear la sala (si ya existe, Daily devuelve 200 igualmente o un error específico)
    final response = await http.post(
      Uri.parse('https://api.daily.co/v1/rooms'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': safeName,
        'properties': {
          'enable_prejoin_ui': false,
          'enable_knocking': false,
          'start_video_off': false,
          'start_audio_off': false,
          'exp': DateTime.now().add(const Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000,
        },
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['url'] as String;
    }

    // Si la sala ya existe (409), construir la URL directamente
    if (response.statusCode == 409) {
      return 'https://$_domain.daily.co/$safeName';
    }

    throw Exception('Daily.co error ${response.statusCode}: ${response.body}');
  }
}
