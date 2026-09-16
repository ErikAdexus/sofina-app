import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';

class PagosService {
  // El nodo `pagos` usa el id de la cita como clave (relación 1 a 1),
  // así queda garantizado que no se puede duplicar un pago por cita.
  Stream<DatabaseEvent> streamPagos() => dbRef('pagos').onValue;

  Stream<DatabaseEvent> streamPago(String citaId) => dbRef('pagos/$citaId').onValue;

  // Chequeo puntual (no stream) para validar antes de dejar finalizar una
  // cita -- ver "Finalizar atención" en citas_especialista_page.dart y
  // abrirEditarEstadoCita en admin_gestion_citas_page.dart. La regla real
  // vive en database.rules.json (estado.validate exige lo mismo del lado
  // servidor); este chequeo es solo para poder avisarle al usuario ANTES
  // de que el write falle, con un mensaje claro en vez del error crudo de
  // permiso denegado que tiraría Firebase.
  Future<bool> existePago(String citaId) async {
    final snapshot = await dbRef('pagos/$citaId').get();
    return snapshot.value != null;
  }

  // Fase 1: la especialista certifica haber recibido el pago. Si ya existe
  // un registro para esta cita, no se sobrescribe.
  Future<void> confirmarPago({
    required String citaId,
    required String clienteId,
    required String clienteNombre,
    required String especialistaId,
    required String especialistaNombre,
    required String servicio,
    required double montoDeclarado,
    required String metodoPago,
  }) async {
    final existente = await dbRef('pagos/$citaId').get();

    if (existente.value != null) {
      throw Exception('Ya existe un pago confirmado para esta cita');
    }

    final ahora = DateTime.now();

    await dbRef('pagos/$citaId').set({
      'id': citaId,
      'citaId': citaId,
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'especialistaId': especialistaId,
      'especialistaNombre': especialistaNombre,
      'servicio': servicio,
      'montoDeclarado': montoDeclarado,
      'metodoPago': metodoPago,
      'fechaHora': ahora.toIso8601String(),
      'fechaHoraMillis': ahora.millisecondsSinceEpoch,
      'estado': 'confirmado_por_especialista',
      'estadoConciliacion': 'pendiente_revision',
    });
  }

  // Fase 2: el admin marca si el monto declarado coincide con lo visto en
  // su app bancaria. Solo actualiza estadoConciliacion, nada más.
  Future<void> actualizarEstadoConciliacion({
    required String citaId,
    required String estadoConciliacion,
  }) async {
    await dbRef('pagos/$citaId').update({
      'estadoConciliacion': estadoConciliacion,
    });
  }
}
