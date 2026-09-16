import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';

// Respaldo si configuracion/distritosCobertura todavía no existe en
// Firebase. Mismo valor que distritosCoberturaPorDefecto en
// cobertura_service.dart (Sofina Cliente) -- son apps Flutter separadas
// sin paquete compartido, así que no se puede importar la constante
// directamente, pero ambas leen el MISMO nodo de RTDB como fuente real de
// verdad (ver cargarDistritosCobertura abajo); esto es solo el fallback
// si esa lectura falla.
const List<String> distritosCoberturaPorDefecto = [
  'La Molina',
  'Surco',
  'San Borja',
  'Barranco',
];

// Config global editable por admin sin redeployar (ver
// database.rules.json en proyectocitas2: solo rol administrador puede
// escribir configuracion/precios). Si se agregan más valores
// configurables, van acá.
class ConfiguracionService {
  // Misma fuente que usa Sofina Cliente para el distrito de la dirección
  // del servicio (configuracion/distritosCobertura) -- se reutiliza acá
  // para que el distrito de una especialista sea comparable 1:1 contra
  // citas/{id}.direccionServicio.distrito.
  Future<List<String>> cargarDistritosCobertura() async {
    try {
      final snapshot = await dbRef('configuracion/distritosCobertura').get();

      if (snapshot.value == null || snapshot.value is! Map) {
        return distritosCoberturaPorDefecto;
      }

      final mapa = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final distritos = mapa.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .where((distrito) => distrito.trim().isNotEmpty)
          .toList();

      return distritos.isEmpty ? distritosCoberturaPorDefecto : distritos;
    } catch (e) {
      debugPrint(
        'No se pudo leer configuracion/distritosCobertura, usando la lista '
        'por defecto: $e',
      );
      return distritosCoberturaPorDefecto;
    }
  }

  Stream<DatabaseEvent> streamPrecioRetiro() =>
      dbRef('configuracion/precios/retiro').onValue;

  Future<void> guardarPrecioRetiro(double monto) {
    return dbRef('configuracion/precios/retiro').set(monto);
  }

  // Número de WhatsApp del negocio, en formato listo para armar
  // https://wa.me/<numero> (solo dígitos, con código de país, sin "+" ni
  // espacios). Vive en "contactoPublico" (no en "configuracion") a
  // propósito: ese nodo tiene lectura pública en las reglas de RTDB para
  // que el botón de WhatsApp funcione también para invitados sin sesión
  // en el chat de Sofina Cliente.
  Stream<DatabaseEvent> streamWhatsapp() =>
      dbRef('contactoPublico/whatsapp').onValue;

  Future<void> guardarWhatsapp(String numero) {
    return dbRef('contactoPublico/whatsapp').set(numero);
  }

  // URL de descarga del QR de pago (Yape) que la especialista muestra al
  // cobrar. Vive en Storage; acá solo se guarda la referencia. Escritura
  // ya protegida por la regla de "configuracion" (solo administrador).
  Stream<DatabaseEvent> streamQrPago() =>
      dbRef('configuracion/pago/qrUrl').onValue;

  Future<void> guardarQrPagoUrl(String url) {
    return dbRef('configuracion/pago/qrUrl').set(url);
  }
}
