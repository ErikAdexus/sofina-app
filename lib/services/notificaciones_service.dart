import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_refs.dart';
import 'navegacion_pendiente_service.dart';

// Pide permiso de notificaciones al especialista/administrador, obtiene
// el token FCM de este dispositivo/instalación y lo guarda en Realtime
// Database bajo usuarios/{uid}/fcmToken -- mismo esquema que ya usa
// proyectocitas2 (Sofina Cliente, notificaciones_service.dart), que es
// donde el backend (notificarPorUid/notificarAdministradores en
// proyectocitas2/functions/index.js) ya lo busca. Sin este archivo, el
// backend intentaba enviar push a especialista/admin y siempre caía en
// el branch "sin token" -- silenciosamente, sin error.
Future<void> configurarNotificacionesPush(String uid) async {
  final messaging = FirebaseMessaging.instance;

  final permiso = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final permisoConcedido =
      permiso.authorizationStatus == AuthorizationStatus.authorized ||
      permiso.authorizationStatus == AuthorizationStatus.provisional;

  if (!permisoConcedido) {
    debugPrint('El usuario no concedió permiso de notificaciones.');
    return;
  }

  final token = await messaging.getToken();
  await _guardarTokenEnBaseDeDatos(uid, token);

  // Firebase puede asignarle un token nuevo al dispositivo en cualquier
  // momento (reinstalación, restauración de backup, limpieza de Google
  // Play Services, etc.). Sin este listener, el push volvería a dejar de
  // llegar silenciosamente después de un tiempo -- el mismo síntoma que
  // el bug que se acaba de arreglar, pero por otra causa.
  messaging.onTokenRefresh.listen((nuevoToken) {
    _guardarTokenEnBaseDeDatos(uid, nuevoToken);
  });
}

Future<void> _guardarTokenEnBaseDeDatos(String uid, String? token) async {
  if (token == null || token.isEmpty) return;
  await dbRef('usuarios/$uid').update({'fcmToken': token});
}

// Se dispara cuando especialista/admin toca la notificación y eso abre
// la app (estando previamente en segundo plano, no cerrada del todo).
void configurarAperturaDesdeNotificacion() {
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final citaId = message.data['citaId'];
    if (citaId != null && citaId.isNotEmpty) {
      citaPendienteDeNotificacion.value = CitaPendienteDeNotificacion(
        citaId: citaId,
        estado: message.data['estado'],
      );
    }
  });
}

// Cubre el caso "app completamente cerrada" (cold start) -- mismo
// patrón que proyectocitas2. Debe llamarse una sola vez, antes de
// runApp(), para que el citaId ya esté listo cuando HomePage monte por
// primera vez.
Future<void> revisarAperturaInicialDesdeNotificacion() async {
  final mensaje = await FirebaseMessaging.instance.getInitialMessage();
  final citaId = mensaje?.data['citaId'];
  if (citaId != null && citaId.isNotEmpty) {
    citaPendienteDeNotificacion.value = CitaPendienteDeNotificacion(
      citaId: citaId,
      estado: mensaje?.data['estado'],
    );
  }
}
