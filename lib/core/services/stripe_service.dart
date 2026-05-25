/// Servicio de pagos con Stripe.
///
/// Singleton que gestiona la integración con Stripe Payment Sheet.
/// Si la clave pública no está configurada en `.env`, el servicio
/// permanece inactivo y muestra mensajes informativos.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/config/env.dart';
import 'package:mploya/config/constants.dart';
import 'package:mploya/core/services/supabase_service.dart';

/// Servicio centralizado para procesar pagos con Stripe.
///
/// ```dart
/// await StripeService.instance.initialize();
/// await StripeService.instance.createPaymentSheet(amount: 999, userId: uid);
/// final success = await StripeService.instance.presentPaymentSheet();
/// ```
class StripeService {
  StripeService._();

  static StripeService? _instance;

  /// Instancia singleton del servicio.
  static StripeService get instance {
    _instance ??= StripeService._();
    return _instance!;
  }

  bool _initialized = false;

  /// `true` si la clave pública de Stripe está configurada.
  bool get isConfigured => Env.stripePublishableKey.isNotEmpty;

  // ─────────────────────────────────────────
  // Inicialización
  // ─────────────────────────────────────────

  /// Inicializa Stripe con la clave pública del `.env`.
  ///
  /// Si la clave no existe, el servicio queda desactivado sin lanzar errores.
  Future<void> initialize() async {
    if (_initialized) return;

    final key = Env.stripePublishableKey;
    if (key.isEmpty) {
      debugPrint('⚠️ StripeService: STRIPE_PUBLISHABLE_KEY no configurada.');
      debugPrint('   Los pagos estarán desactivados.');
      return;
    }

    try {
      Stripe.publishableKey = key;
      // Configuración del estilo del merchant (nombre visible en el sheet).
      Stripe.merchantIdentifier = kStripeMerchantIdentifier;
      await Stripe.instance.applySettings();
      _initialized = true;
      debugPrint('✅ StripeService inicializado correctamente.');
    } catch (e) {
      debugPrint('⚠️ StripeService: Error al inicializar Stripe: $e');
    }
  }

  // ─────────────────────────────────────────
  // Payment Sheet
  // ─────────────────────────────────────────

  /// Crea un PaymentIntent en el backend y configura el Payment Sheet.
  ///
  /// [amount] es el monto en centavos (ej: 999 = USD 9.99).
  /// [currency] por defecto `usd`.
  /// [userId] ID del usuario que realiza el pago.
  Future<void> createPaymentSheet({
    required int amount,
    String currency = 'usd',
    required String userId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Stripe no está configurado. Añade STRIPE_PUBLISHABLE_KEY en .env',
      );
    }

    try {
      // Llamar a la Edge Function de Supabase para crear el PaymentIntent.
      final response = await SupabaseService.instance.client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': amount,
          'currency': currency,
          'userId': userId,
        },
      );

      final rawData = response.data;
      if (rawData == null) {
        throw Exception(
          'Payment intent creation failed: empty response from server',
        );
      }
      final data = rawData as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String;

      // Inicializar el Payment Sheet con el clientSecret.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: kAppName,
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFF97316), // MployaColors.orange
            ),
          ),
        ),
      );

      debugPrint('✅ Payment Sheet creado correctamente.');
    } catch (e) {
      debugPrint('❌ Error creando Payment Sheet: $e');
      rethrow;
    }
  }

  /// Muestra el Payment Sheet al usuario.
  ///
  /// Devuelve `true` si el pago fue exitoso, `false` si el usuario canceló.
  /// Lanza una excepción si ocurre un error inesperado.
  Future<bool> presentPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      debugPrint('✅ Pago completado exitosamente.');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('ℹ️ El usuario canceló el pago.');
        return false;
      }
      debugPrint('❌ Error en Payment Sheet: ${e.error.localizedMessage}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error inesperado en Payment Sheet: $e');
      rethrow;
    }
  }
}
