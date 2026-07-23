import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../services/referral_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _code;
  int _count = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final code = await ReferralService.instance.getMyCode();
    final count = await ReferralService.instance.myReferralCount();
    if (mounted) setState(() { _code = code; _count = count; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('Invitar Amigos'), previousPageTitle: 'Atrás'),
      child: _loading ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              // Header
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF185FA5)]),
                borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
                boxShadow: [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Column(children: [
                  const Icon(CupertinoIcons.gift_fill, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text('Invitá y ganá', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Cada amigo que se registre te da un boost de visibilidad', style: TextStyle(fontSize: 14, color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text('$_count invitaciones exitosas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                ])),
              const SizedBox(height: 24),

              // Code card
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                child: Column(children: [
                  const Text('Tu código de invitación', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () { Clipboard.setData(ClipboardData(text: _code ?? '')); HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado'), duration: Duration(seconds: 1))); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E5EA))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_code ?? '...', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E), letterSpacing: 2)),
                        const SizedBox(width: 12),
                        const Icon(CupertinoIcons.doc_on_doc, size: 18, color: Color(0xFF8E8E93)),
                      ]))),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: CupertinoButton(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(14),
                    onPressed: () { final link = ReferralService.instance.getShareLink(_code ?? '');
                      Share.share('Unite a Mploya con mi código y ganá un perfil destacado.\n\n$link\n\nCódigo: $_code'); },
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(CupertinoIcons.share, color: Colors.white, size: 18), SizedBox(width: 8),
                      Text('Compartir invitación', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ]))),
                ])),
              const Spacer(),
              // Rewards info
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [
                  Icon(CupertinoIcons.star_fill, color: Color(0xFFFFCC00), size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Por cada 5 invitaciones exitosas, recibís 1 semana de Mploya Pro gratis.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6D4C00), height: 1.3))),
                ])),
            ]))),
    );
  }
}
