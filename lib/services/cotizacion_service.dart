import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';

// Solicitudes de cotización de clientes (Sofina Cliente) para servicios
// sin precio fijo (requiereCotizacion en ServicioCatalogo). El cliente
// crea la solicitud directo por RTDB; acá solo se fija precioAcordado y
// se pasa a "cotizado" -- la Cloud Function crearCita (Sofina Cliente)
// vuelve a validar todo esto antes de dejar reservar con ese precio.
class CotizacionService {
  Stream<DatabaseEvent> streamSolicitudes() =>
      dbRef('solicitudesCotizacion').onValue;

  Future<void> cotizar({
    required String solicitudId,
    required double precioAcordado,
  }) {
    return dbRef('solicitudesCotizacion/$solicitudId').update({
      'estado': 'cotizado',
      'precioAcordado': precioAcordado,
      'fechaRespuesta': ServerValue.timestamp,
    });
  }
}
