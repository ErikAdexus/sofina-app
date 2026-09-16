import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';

class CalificacionesService {
  Stream<DatabaseEvent> streamCalificaciones() =>
      dbRef('calificaciones').onValue;

  // El .read de /calificaciones ya no es plano -- una especialista solo
  // puede leerlas vía esta query, cruzada del lado servidor contra
  // /especialistas/{especialistaId}/authUid (ver database.rules.json).
  Stream<DatabaseEvent> streamCalificacionesDeEspecialista(
    String especialistaId,
  ) =>
      dbRef('calificaciones')
          .orderByChild('especialistaId')
          .equalTo(especialistaId)
          .onValue;

  // Dispara actualizarResumenCalificacion (Cloud Function, functions/index.js
  // en proyectocitas2) que recalcula especialistas/{id}/calificacionResumen
  // -- nunca recalcular el promedio a mano en el cliente.
  Future<void> eliminarCalificacion(String citaId) {
    return dbRef('calificaciones/$citaId').remove();
  }
}
