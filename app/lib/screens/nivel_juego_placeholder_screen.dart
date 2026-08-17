import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _ink = Color(0xFF0E1620);
const _teal = Color(0xFF2BC0A8);

/// Placeholder hasta que exista la pantalla de juego real (INT-91). El
/// camino (INT-90) navega aquí al tocar una parada desbloqueada, para poder
/// probar manualmente qué nivel se iba a abrir.
class NivelJuegoPlaceholderScreen extends StatelessWidget {
  const NivelJuegoPlaceholderScreen({
    super.key,
    required this.nivelId,
    required this.tematicaNombre,
    required this.numeroNivel,
  });

  final String nivelId;
  final String tematicaNombre;
  final int numeroNivel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag_rounded, color: _teal, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Nivel $numeroNivel · $tematicaNombre',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pantalla de juego pendiente (INT-91).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Volver al camino'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
