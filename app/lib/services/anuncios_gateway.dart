import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipo de anuncio pendiente antes de arrancar un intento, tal como lo
/// define el enum `tipo_anuncio_pendiente` en Postgres (`video-ads`, INT-117).
enum TipoAnuncioPendiente {
  ninguno,
  desbloqueo,
  cadencia;

  static TipoAnuncioPendiente fromString(String value) {
    return switch (value) {
      'ninguno' => TipoAnuncioPendiente.ninguno,
      'desbloqueo' => TipoAnuncioPendiente.desbloqueo,
      'cadencia' => TipoAnuncioPendiente.cadencia,
      _ => throw ArgumentError('Tipo de anuncio desconocido: $value'),
    };
  }
}

/// Superficie mínima de AdMob + Supabase para el gating de un intento, para
/// poder probarla con un falso sin salir a la red ni tocar el SDK nativo.
abstract class AnunciosGateway {
  /// Consulta `anuncio_debido` (solo lectura, sin efectos secundarios) para
  /// saber qué anuncio (si alguno) toca antes de arrancar un intento en esa
  /// parada.
  Future<TipoAnuncioPendiente> anuncioDebido(String caminoId);

  /// Si toca anuncio, intenta cargar y mostrar un `RewardedInterstitialAd`
  /// con un timeout corto. Nunca lanza y nunca bloquea más allá del timeout:
  /// cualquier fallo de carga, de conexión o de "no cargó a tiempo" se
  /// resuelve como fail-open (D6 de design.md) — quien llama debe seguir
  /// adelante igual, sin reintentar.
  Future<void> mostrarSiToca(String caminoId);

  /// Carga y muestra un `RewardedAd` para un flujo bajo demanda iniciado por
  /// el jugador (p. ej. "Ver un anuncio" para obtener un comodín,
  /// `comodines`) — distinto de `RewardedInterstitialAd`, reservado al
  /// gating automático (INT-117 delta-1, D1 de design.md). Nunca lanza, pero
  /// a diferencia de `mostrarSiToca` NO es fail-open: devuelve `true` solo
  /// si el jugador llegó a ganar la recompensa (`onUserEarnedReward`), y
  /// `false` en cualquier otro caso (no cargó, falló, se cerró antes de
  /// completarse) — quien llama no debe conceder nada si devuelve `false`.
  Future<bool> mostrarParaRecompensa();
}

class AdMobAnunciosGateway implements AnunciosGateway {
  AdMobAnunciosGateway(
    this._client, {
    this.adUnitId = _adUnitIdPorDefecto,
    this.adUnitIdRecompensado = _adUnitIdRecompensadoPorDefecto,
    this.timeoutCarga = const Duration(seconds: 5),
  });

  /// Ad unit de test oficial de Google (`RewardedInterstitialAd`, iOS) —
  /// sustituible por `--dart-define=ADMOB_AD_UNIT_REWARDED_INTERSTITIAL_IOS=...`
  /// cuando exista cuenta AdMob real (D7 de design.md de
  /// int-117-publicidad-video-admob), sin tocar código. No usa
  /// `MissingConfigError` como `AppConfig`: a diferencia de la URL/clave de
  /// Supabase, este valor siempre tiene un default funcional.
  static const _adUnitIdPorDefecto = String.fromEnvironment(
    'ADMOB_AD_UNIT_REWARDED_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/6978759866',
  );

  /// Ad unit de test oficial de Google para `RewardedAd` (iOS) — mismo
  /// mecanismo de sustitución que `adUnitId` (INT-117 delta-1).
  static const _adUnitIdRecompensadoPorDefecto = String.fromEnvironment(
    'ADMOB_AD_UNIT_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  final SupabaseClient _client;
  final String adUnitId;
  final String adUnitIdRecompensado;
  final Duration timeoutCarga;

  @override
  Future<TipoAnuncioPendiente> anuncioDebido(String caminoId) async {
    final respuesta = await _client.rpc(
      'anuncio_debido',
      params: {'p_camino_id': caminoId},
    );
    return TipoAnuncioPendiente.fromString(respuesta as String);
  }

  @override
  Future<void> mostrarSiToca(String caminoId) async {
    // Todo el cuerpo va protegido, no solo la carga del anuncio: si
    // anuncioDebido() falla (p. ej. sin conexión), el mismo problema hará
    // fallar iniciar_intento_parada justo después con su propia UI de error
    // ya existente en NivelJuegoScreen — no hace falta duplicarla aquí, y
    // dejar escapar la excepción rompería la garantía de "nunca lanza" del
    // contrato de la interfaz.
    try {
      final tipo = await anuncioDebido(caminoId);
      if (tipo == TipoAnuncioPendiente.ninguno) {
        return;
      }
      await mostrarAnuncioRewarded();
    } catch (_) {
      return;
    }
  }

  /// Carga y muestra un `RewardedInterstitialAd` con timeout fail-open (D6
  /// de design.md). Público (sin guion bajo) para poder probar el propio
  /// mecanismo de timeout/fail-open sin pasar por `anuncioDebido` — no
  /// depende de ningún estado de red de Supabase, solo del SDK de AdMob.
  @visibleForTesting
  Future<void> mostrarAnuncioRewarded() async {
    final anuncio = await _cargarConTimeout();
    if (anuncio == null) {
      // Fail-open: no cargó a tiempo, falló la carga o no hay conexión.
      return;
    }

    final cierre = Completer<void>();
    anuncio.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!cierre.isCompleted) cierre.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!cierre.isCompleted) cierre.complete();
      },
    );

    // No se concede ninguna recompensa por este anuncio (Non-Goal de
    // design.md): el callback está vacío a propósito, el "reward" real es
    // dejar continuar al jugador, no un ítem de juego.
    await anuncio.show(onUserEarnedReward: (ad, reward) {});
    await cierre.future;
  }

  @override
  Future<bool> mostrarParaRecompensa() async {
    try {
      final anuncio = await _cargarRecompensadoConTimeout();
      if (anuncio == null) {
        // No hay fail-open aquí (D3 de design.md): simplemente no hay
        // recompensa que conceder.
        return false;
      }

      var recompensaGanada = false;
      final cierre = Completer<void>();
      anuncio.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!cierre.isCompleted) cierre.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          if (!cierre.isCompleted) cierre.complete();
        },
      );

      await anuncio.show(
        onUserEarnedReward: (ad, reward) {
          recompensaGanada = true;
        },
      );
      await cierre.future;
      return recompensaGanada;
    } catch (_) {
      return false;
    }
  }

  Future<RewardedAd?> _cargarRecompensadoConTimeout() {
    final completer = Completer<RewardedAd?>();
    var agotado = false;

    RewardedAd.load(
      adUnitId: adUnitIdRecompensado,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (agotado) {
            ad.dispose();
            return;
          }
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!agotado && !completer.isCompleted) completer.complete(null);
        },
      ),
    ).catchError((Object _) {
      if (!agotado && !completer.isCompleted) completer.complete(null);
    });

    return completer.future.timeout(
      timeoutCarga,
      onTimeout: () {
        agotado = true;
        return null;
      },
    );
  }

  Future<RewardedInterstitialAd?> _cargarConTimeout() {
    final completer = Completer<RewardedInterstitialAd?>();
    var agotado = false;

    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (agotado) {
            // Cargó tarde, después de que el timeout ya soltara al
            // jugador: se descarta en vez de dejarlo colgado en memoria o
            // mostrarlo fuera de contexto.
            ad.dispose();
            return;
          }
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!agotado && !completer.isCompleted) completer.complete(null);
        },
      ),
    ).catchError((Object _) {
      // `load()` puede fallar sin llegar a invocar ningún callback (p. ej.
      // `MissingPluginException` si el SDK nativo no está registrado, como
      // en el entorno de test): fail-open igual que un fallo de carga
      // reportado por el propio SDK.
      if (!agotado && !completer.isCompleted) completer.complete(null);
    });

    return completer.future.timeout(
      timeoutCarga,
      onTimeout: () {
        agotado = true;
        return null;
      },
    );
  }
}
