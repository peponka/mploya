import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

/// Map screen placeholder showing nearby jobs on a map.
///
/// Will integrate Flutter Map (OpenStreetMap) once location
/// services are configured.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mapa',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filtrar',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Mi ubicación',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.map_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mapa de empleos',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                'Próximamente podrás ver empleos cerca de tu ubicación en un mapa interactivo',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.location_searching_rounded),
              label: const Text('Activar ubicación'),
            ),
          ],
        ),
      ),
    );
  }
}
