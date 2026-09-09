import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/my_profile_service.dart';
import 'empresa/empresa_herramientas_screen.dart';
import 'headhunter/headhunter_tools_screen.dart';
import 'mis_herramientas_screen.dart';

class ToolsHubEntryScreen extends StatefulWidget {
  const ToolsHubEntryScreen({super.key});

  @override
  State<ToolsHubEntryScreen> createState() => _ToolsHubEntryScreenState();
}

class _ToolsHubUserData {
  const _ToolsHubUserData({required this.profile, required this.isAdmin});

  final Map<String, dynamic> profile;
  final bool isAdmin;
}

class _ToolsHubEntryScreenState extends State<ToolsHubEntryScreen> {
  late final Future<_ToolsHubUserData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadUser();
  }

  Future<_ToolsHubUserData?> _loadUser() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    final results = await Future.wait<Object?>([
      loadMyProfile(client: client),
      client.rpc('is_admin'),
    ]);
    final profile = results.first;
    if (profile is! Map) return null;
    return _ToolsHubUserData(
      profile: Map<String, dynamic>.from(profile),
      isAdmin: results.last == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ToolsHubUserData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const CupertinoPageScaffold(
            child: Center(child: Text('No se pudo cargar Mis herramientas.')),
          );
        }

        final profile = NexUser.fromJson(data.profile);
        if (profile.accountType == 'headhunter') {
          return const HeadhunterToolsScreen();
        }
        if (profile.accountType == 'empresa') {
          return const EmpresaHerramientasScreen();
        }
        return MisHerramientasScreen(profile: profile, isAdmin: data.isAdmin);
      },
    );
  }
}
