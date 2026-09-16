import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/firebase_refs.dart';

class CitasService {
  // Solo la usa el admin (AdminGestionCitasPage): database.rules.json le
  // permite leer /citas completo sin query. Para especialista, usar
  // streamCitasDeEspecialista -- un listen sin filtrar como este da
  // PERMISSION_DENIED para cualquier rol que no sea administrador.
  Stream<DatabaseEvent> streamCitas() => dbRef('citas').onValue;

  // Para especialista: solo sus propias citas asignadas -- el .read de
  // /citas ya no es un permiso plano para no-admins, exige que la query
  // coincida con orderByChild('especialistaUid').equalTo(auth.uid) (ver
  // database.rules.json).
  Stream<DatabaseEvent> streamCitasDeEspecialista(String authUid) =>
      dbRef('citas').orderByChild('especialistaUid').equalTo(authUid).onValue;

  // Usado por AdminGestionCitasPage.abrirEditarEstadoCita: actualiza
  // estado + observación.
  Future<void> actualizarEstadoCita({
    required String idCita,
    required String estado,
    required String observacion,
  }) async {
    await dbRef('citas/$idCita').update({
      'estado': estado,
      'observacion': observacion,
      'fechaActualizacion': DateTime.now().toIso8601String(),
      // Único llamador: abrirEditarEstadoCita (admin_gestion_citas_page.dart)
      // -- este método SIEMPRE lo ejecuta un administrador.
      'actualizadoPorRol': 'administrador',
    });
  }

  // AdminGestionCitasPage.abrirAsignarEspecialista: asigna especialista y
  // pasa la cita a Confirmada.
  Future<void> asignarEspecialista({
    required String idCita,
    required Map<String, dynamic> especialista,
  }) async {
    final ahora = DateTime.now().toIso8601String();

    await dbRef('citas/$idCita').update({
      'especialistaId': especialista['id'] ?? '',
      'especialistaUid': especialista['authUid'] ?? '',
      'especialistaNombre': especialista['nombreCompleto'] ?? '',
      'especialistaCelular': especialista['celular'] ?? '',
      'especialistaCorreo': especialista['correo'] ?? '',
      'especialistaEspecialidad': especialista['especialidad'] ?? '',
      'estado': 'Confirmada',
      'fechaAsignacion': ahora,
      'fechaActualizacion': ahora,
    });
  }

  Future<void> eliminarCita(String idCita) async {
    await dbRef('citas/$idCita').remove();
  }

  // CitasEspecialistaPage.cambiarEstado: marca el nuevo estado y, cuando
  // corresponde (salida de casa / llegada al cliente), guarda la posición
  // GPS registrada en ese momento.
  Future<void> actualizarEstadoConUbicacion({
    required String idCita,
    required String nuevoEstado,
    Position? posicion,
    String tipoUbicacion = '',
  }) async {
    final ahora = DateTime.now();
    final Map<String, dynamic> datosActualizar = {
      'estado': nuevoEstado,
      'fechaActualizacion': ahora.toIso8601String(),
      // Único llamador: cambiarEstado (citas_especialista_page.dart) --
      // este método SIEMPRE lo ejecuta la especialista asignada.
      'actualizadoPorRol': 'especialista',
    };

    if (posicion != null) {
      final datosUbicacion = {
        'latitud': posicion.latitude,
        'longitud': posicion.longitude,
        'fechaHora': ahora.toIso8601String(),
        'fechaMillis': ahora.millisecondsSinceEpoch,
      };

      datosActualizar.addAll({
        'especialistaLatitud': posicion.latitude,
        'especialistaLongitud': posicion.longitude,
        'fechaUbicacionEspecialista': ahora.toIso8601String(),
      });

      if (tipoUbicacion == 'salida') {
        datosActualizar.addAll({
          'salidaEspecialista': datosUbicacion,
          'fechaSalidaEspecialista': ahora.toIso8601String(),
          'fechaSalidaEspecialistaMillis': ahora.millisecondsSinceEpoch,
        });
      }

      if (tipoUbicacion == 'llegada') {
        datosActualizar.addAll({
          'llegadaEspecialista': datosUbicacion,
          'fechaLlegadaEspecialista': ahora.toIso8601String(),
          'fechaLlegadaEspecialistaMillis': ahora.millisecondsSinceEpoch,
        });
      }
    }

    try {
      await dbRef('citas/$idCita').update(datosActualizar);
    } catch (e) {
      debugPrint('[DEBUG-FIN] ERROR: $e');
      rethrow;
    }
  }
}
