import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/user_columns.dart';
import 'mis_herramientas_screen.dart';

class ToolsHubEntryScreen extends StatefulWidget {
  const ToolsHubEntryScreen({super.key});

  @override
  State<ToolsHubEntryScreen> createState() => _ToolsHubEntryScreenState();
}

class _ToolsHubEntryScreenState extends State<ToolsHubEntryScreen> {
  late final Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadUser();
  }

  Future<Map<String, dynamic>?> _loadUser() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    return Supabase.instance.client
        .from('users')
        .select('$kUserColumns, is_admin')
        .eq('id', uid)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
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
            child: Center(
              child: Text('No se pudo cargar Mis herramientas.'),
            ),
          );
        }

        final profile = NexUser.fromJson(data);
        final isAdmin = data['is_admin'] == true;
        return MisHerramientasScreen(profile: profile, isAdmin: isAdmin);
      },
    );
  }
}
