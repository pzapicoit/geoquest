import 'package:flutter/material.dart';

/// Placeholder hasta que exista el Mapa de temáticas real. El splash navega
/// aquí cuando el dispositivo ya tiene un nombre de usuario guardado.
class TopicsMapPlaceholderScreen extends StatelessWidget {
  const TopicsMapPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mapa de temáticas — pendiente')),
    );
  }
}
