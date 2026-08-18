import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'route_observer.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INT-102 (D5): la app se juega solo en vertical. No hay diseño para
  // apaisado en ninguna pantalla, y la cámara del mapa garantiza que el mundo
  // cubra la altura del área visible — una garantía que se vuelve inestable si
  // alto y ancho intercambian sus papeles a mitad de partida. Esto se declara
  // también en Info.plist y AndroidManifest.xml: la configuración nativa es la
  // que gobierna el arranque, antes de que exista motor Dart, y esta es la que
  // sobrevive a que se regeneren las plantillas nativas.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // La configuración se valida antes de inicializar nada. Si falta una
  // variable, MissingConfigError sale por aquí nombrándola, en lugar de dejar
  // la app arrancada contra un proyecto inexistente.
  final config = AppConfig.fromEnvironment();

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );

  runApp(GeoQuestApp(config: config));
}

class GeoQuestApp extends StatelessWidget {
  const GeoQuestApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B4C)),
      ),
      navigatorObservers: [routeObserver],
      home: SplashScreen(config: config),
    );
  }
}
