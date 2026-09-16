import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';
import '../utils/disponibilidad_calculo.dart';

// Disponibilidad de especialistas: horario recurrente semanal +
// excepciones puntuales. horarioBase/{authUid} y
// excepcionesDisponibilidad/{id}.especialistaId guardan el uid de
// Firebase Auth (no el id de especialistas/{id}, son ids distintos en
// este proyecto) -- ver database.rules.json para el porqué.
class DisponibilidadService {
  // Solo la propia especialista puede leer/escribir su horarioBase (ver
  // reglas) -- se usa tanto desde su propia pantalla como, con el uid de
  // cada especialista, desde la pantalla de franja horaria del admin.
  Future<Map<String, dynamic>?> cargarHorarioBase(String authUid) async {
    final snapshot = await dbRef('horarioBase/$authUid').get();

    if (snapshot.value == null || snapshot.value is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  // Reemplaza el horario completo de una sola vez (los 7 días juntos) --
  // mismo patrón "leer, editar en memoria, guardar todo junto" que
  // ConfiguracionService.guardarPrecioRetiro.
  Future<void> guardarHorarioBase(
    String authUid,
    Map<String, dynamic> horario,
  ) {
    return dbRef('horarioBase/$authUid').set(horario);
  }

  Stream<DatabaseEvent> streamExcepciones(String authUid) {
    return dbRef('excepcionesDisponibilidad')
        .orderByChild('especialistaId')
        .equalTo(authUid)
        .onValue;
  }

  Future<String> crearExcepcion({
    required String authUid,
    required String fecha,
    required String tipo,
    String? horaInicio,
    String? horaFin,
    String? motivo,
  }) async {
    final ref = dbRef('excepcionesDisponibilidad').push();

    await ref.set({
      'especialistaId': authUid,
      'fecha': fecha,
      'tipo': tipo,
      if (horaInicio != null && horaInicio.isNotEmpty) 'horaInicio': horaInicio,
      if (horaFin != null && horaFin.isNotEmpty) 'horaFin': horaFin,
      if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      'fechaRegistro': ServerValue.timestamp,
    });

    return ref.key!;
  }

  Future<void> eliminarExcepcion(String excepcionId) {
    return dbRef('excepcionesDisponibilidad/$excepcionId').remove();
  }

  // Usado desde la pantalla de franja horaria del admin (Prioridad 3) y
  // el warning de asignarEspecialista (Prioridad 6): trae TODAS las
  // excepciones de TODAS las especialistas para una fecha puntual, en vez
  // de consultar especialista por especialista.
  Future<List<Map<String, dynamic>>> cargarExcepcionesDeFecha(
    String fecha,
  ) async {
    final snapshot = await dbRef('excepcionesDisponibilidad')
        .orderByChild('fecha')
        .equalTo(fecha)
        .get();

    if (snapshot.value == null || snapshot.value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final excepciones = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        excepciones.add({
          'id': key.toString(),
          ...Map<String, dynamic>.from(value),
        });
      }
    });

    return excepciones;
  }

  // Igual que cargarExcepcionesDeFecha pero para un rango [desde, hasta]
  // (ambas "YYYY-MM-DD", inclusive) -- usado por la vista de rango del
  // admin. Trae TODAS las especialistas, se filtra por especialistaId en
  // el llamador (mismo patrón que cargarExcepcionesDeFecha).
  Future<List<Map<String, dynamic>>> cargarExcepcionesDeRango(
    String desde,
    String hasta,
  ) async {
    final snapshot = await dbRef('excepcionesDisponibilidad')
        .orderByChild('fecha')
        .startAt(desde)
        .endAt(hasta)
        .get();

    if (snapshot.value == null || snapshot.value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final excepciones = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        excepciones.add({
          'id': key.toString(),
          ...Map<String, dynamic>.from(value),
        });
      }
    });

    return excepciones;
  }

  // Trae el horarioBase de varias especialistas de una (pantalla de
  // franja horaria): una sola lectura de todo el nodo en vez de N
  // lecturas individuales -- el admin ya tiene permiso de leer el nodo
  // completo (ver database.rules.json).
  Future<Map<String, Map<String, dynamic>>> cargarHorarioBaseDeTodas() async {
    final snapshot = await dbRef('horarioBase').get();

    if (snapshot.value == null || snapshot.value is! Map) {
      return {};
    }

    final mapa = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final resultado = <String, Map<String, dynamic>>{};

    mapa.forEach((authUid, value) {
      if (value is Map) {
        resultado[authUid.toString()] = Map<String, dynamic>.from(value);
      }
    });

    return resultado;
  }

  // Usada por el warning no-bloqueante de asignarEspecialista (Prioridad
  // 6, ver abrirAsignarEspecialista en admin_gestion_citas_page.dart):
  // resuelve la disponibilidad de UNA especialista para la fecha/hora
  // puntual de una cita, cruzando su horarioBase + sus excepciones de esa
  // fecha. Nunca se usa para bloquear nada, solo para decidir si hace
  // falta mostrarle al admin una advertencia antes de confirmar.
  Future<EstadoDisponibilidad> consultarDisponibilidadPuntual({
    required String authUid,
    required DateTime fecha,
    required TimeOfDay hora,
  }) async {
    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    final fechaTexto = '$anio-$mes-$dia';

    final resultados = await Future.wait([
      cargarHorarioBase(authUid),
      cargarExcepcionesDeFecha(fechaTexto),
    ]);

    final horarioBase = resultados[0] as Map<String, dynamic>?;
    final todasExcepciones = resultados[1] as List<Map<String, dynamic>>;

    final excepcionesDeEsta = todasExcepciones
        .where((e) => e['especialistaId']?.toString() == authUid)
        .toList();

    return calcularDisponibilidad(
      horarioBase: horarioBase,
      excepciones: excepcionesDeEsta,
      fecha: fecha,
      hora: hora,
    );
  }
}
