import 'package:flutter/cupertino.dart';

class HeadhunterClientsScreen extends StatelessWidget {
  const HeadhunterClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clientes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Empresas para las que reclutás',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
              ),
              Spacer(),
              Center(
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.building_2_fill,
                      size: 50,
                      color: Color(0xFF9AA7B8),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Sin clientes conectados',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF263247),
                      ),
                    ),
                    SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 310),
                      child: Text(
                        'Mploya todavía no tiene un registro de clientes asociado a tu cuenta. No mostramos empresas ni búsquedas simuladas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: Color(0xFF738095),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
