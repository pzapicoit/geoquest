import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'route_observer.dart';
import 'screens/marco_de_movil.dart';
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

  // INT-117: inicializa el SDK de Google Mobile Ads antes de que cualquier
  // pantalla pueda pedir un RewardedInterstitialAd. No bloquea el arranque
  // si tarda o falla (fail-open general de video-ads): no se espera aquí a
  // que termine, solo se dispara.
  //
  // En web no se llama: `google_mobile_ads` declara soporte solo para Android
  // e iOS, así que el plugin no está registrado y esta llamada terminaba en un
  // error no capturado en la consola del navegador en cada arranque. Ahí el
  // gateway de anuncios es `AnunciosGatewayWeb`, que no toca el SDK.
  if (!kIsWeb) {
    unawaited(MobileAds.instance.initialize());
  }

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
      // Encajona la app en una franja vertical si la ventana es más ancha que
      // el diseño (navegador de escritorio, tablet). Va en `builder` y no
      // envolviendo `home` para que también alcance a las rutas que empuje el
      // Navigator, no solo a la primera pantalla.
      builder: (context, child) => MarcoDeMovil(child: child!),
      home: SplashScreen(config: config),
    );
  }
}
