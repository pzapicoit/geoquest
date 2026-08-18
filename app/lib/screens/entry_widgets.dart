import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'entry_backdrop.dart';

/// Botón "grueso" con sombra sólida en tono dorado cuando está habilitado,
/// como el CTA principal del mock (`Empezar a jugar` / `Seguir jugando`).
/// Envuelve un [FilledButton] transparente para conservar la semántica de
/// habilitado/deshabilitado y la accesibilidad.
class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: enabled
                ? const Color(0xFF996E00).withValues(alpha: 0.75)
                : const Color(0xFF04121A).withValues(alpha: 0.6),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: enabled && !loading ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 19),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: enabled ? entryGold : const Color(0xFF1E2E39),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFF3A2A00),
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.baloo2(
                    color: enabled
                        ? const Color(0xFF3A2A00)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Botón secundario con borde, como "Cambiar de jugador".
class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.85),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size.fromHeight(0),
      ),
      child: Text(
        label,
        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Enlace secundario discreto — se usa tanto para "hueco preparado para el
/// futuro" (sin `onTap`) como para acciones reales (invitado).
class GhostLink extends StatelessWidget {
  const GhostLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 13.5,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Fila decorativa de accesos sociales "Próximamente" — visual, sin
/// `onTap`, tal como en el mock (`showSocial` activo por defecto).
class SocialPlaceholderRow extends StatelessWidget {
  const SocialPlaceholderRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'PRÓXIMAMENTE',
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: Colors.white.withValues(alpha: 0.34),
                ),
              ),
            ),
            Expanded(child: _divider()),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _providerChip('Google')),
            const SizedBox(width: 10),
            Expanded(child: _providerChip('Apple')),
          ],
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 1.5, color: Colors.white.withValues(alpha: 0.1));

  Widget _providerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
