import 'package:flutter/material.dart';

/// Placeholder hasta que exista la pantalla real de "Nombre de usuario"
/// (INT-89). El splash navega aquí cuando el dispositivo no tiene todavía un
/// nombre de usuario guardado.
class UsernamePlaceholderScreen extends StatelessWidget {
  const UsernamePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Nombre de usuario — pendiente (INT-89)')),
    );
  }
}
