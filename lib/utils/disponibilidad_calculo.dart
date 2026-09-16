import 'package:flutter/material.dart';

import '../models/dia_horario.dart';

// Resultado de cruzar horarioBase + excepcionesDisponibilidad para una
// especialista, fecha y hora puntuales. sinConfigurar es un estado
// aparte (no un "no disponible" más) porque una especialista que nunca
// llenó su horario no debería verse como "ocupada" -- simplemente no hay
// dato, y así lo tienen que tratar tanto la pantalla de franja horaria
// del admin como el warning de asignarEspecialista (Prioridad 6: "si no
// hay horarioBase configurado, no mostrar advertencia").
enum EstadoDisponibilidad { disponible, noDisponible, sinConfigurar }

// [excepciones] debe venir YA filtrada a esta especialista y a la fecha
// consultada (ver DisponibilidadService.cargarExcepcionesDeFecha +
// filtro por especialistaId) -- esta función no filtra, solo cruza.
EstadoDisponibilidad calcularDisponibilidad({
  required Map<String, dynamic>? horarioBase,
  required List<Map<String, dynamic>> excepciones,
  required DateTime fecha,
  required TimeOfDay hora,
}) {
  final horaConsultaMin = minutosDesdeMedianoche(hora);

  // Un bloqueo puntual gana sobre cualquier otra cosa (incluso sobre un
  // "extra" que se hubiera cargado por error para la misma franja).
  for (final excepcion in excepciones) {
    if (excepcion['tipo'] != 'bloqueo') continue;
    if (_horaDentroDeExcepcion(excepcion, horaConsultaMin)) {
      return EstadoDisponibilidad.noDisponible;
    }
  }

  // Una disponibilidad "extra" habilita aunque el horario base esté
  // inactivo (o ni siquiera configurado) ese día.
  for (final excepcion in excepciones) {
    if (excepcion['tipo'] != 'extra') continue;
    if (_horaDentroDeExcepcion(excepcion, horaConsultaMin)) {
      return EstadoDisponibilidad.disponible;
    }
  }

  if (horarioBase == null) {
    return EstadoDisponibilidad.sinConfigurar;
  }

  final diaData = horarioBase[claveDiaSemana(fecha)];
  if (diaData is! Map || diaData['activo'] != true) {
    return EstadoDisponibilidad.noDisponible;
  }

  final inicio = parsearHoraHHmm(diaData['horaInicio']?.toString());
  final fin = parsearHoraHHmm(diaData['horaFin']?.toString());
  if (inicio == null || fin == null) {
    return EstadoDisponibilidad.noDisponible;
  }

  final dentro = horaConsultaMin >= minutosDesdeMedianoche(inicio) &&
      horaConsultaMin < minutosDesdeMedianoche(fin);

  return dentro
      ? EstadoDisponibilidad.disponible
      : EstadoDisponibilidad.noDisponible;
}

// Ventana total configurada para trabajar en [fecha] (en minutos),
// cruzando horarioBase + excepciones -- a diferencia de
// calcularDisponibilidad (que solo responde sí/no para una hora
// puntual), esto suma cuánto tiempo hay disponible en todo el día.
//
// Devuelve null si no hay NINGÚN dato que permita calcular una ventana
// (sin horarioBase activo ese día y sin ninguna excepción "extra"): eso
// es "sin configurar", no "cero horas" -- mostrar 0h ahí sería engañoso
// (ver EstadoDisponibilidad.sinConfigurar, mismo criterio).
int? calcularVentanaLibreMinutos({
  required Map<String, dynamic>? horarioBase,
  required List<Map<String, dynamic>> excepciones,
  required DateTime fecha,
}) {
  int? inicioMin;
  int? finMin;

  // Una excepción "extra" reemplaza la ventana del horarioBase ese día
  // (habilita aunque el horario base esté inactivo o no configurado). Si
  // hay más de una, se toma la envolvente (la más temprana a la más
  // tardía).
  for (final excepcion in excepciones) {
    if (excepcion['tipo'] != 'extra') continue;

    final inicio = parsearHoraHHmm(excepcion['horaInicio']?.toString());
    final fin = parsearHoraHHmm(excepcion['horaFin']?.toString());
    if (inicio == null || fin == null) continue;

    final ini = minutosDesdeMedianoche(inicio);
    final fn = minutosDesdeMedianoche(fin);
    inicioMin = inicioMin == null || ini < inicioMin ? ini : inicioMin;
    finMin = finMin == null || fn > finMin ? fn : finMin;
  }

  // Sin "extra" con horas: usar el horarioBase de ese día si está activo.
  if (inicioMin == null || finMin == null) {
    final diaData = horarioBase?[claveDiaSemana(fecha)];

    if (diaData is Map && diaData['activo'] == true) {
      final inicio = parsearHoraHHmm(diaData['horaInicio']?.toString());
      final fin = parsearHoraHHmm(diaData['horaFin']?.toString());

      if (inicio != null && fin != null) {
        inicioMin = minutosDesdeMedianoche(inicio);
        finMin = minutosDesdeMedianoche(fin);
      }
    }
  }

  if (inicioMin == null || finMin == null || finMin <= inicioMin) {
    return null;
  }

  var ventanaMin = finMin - inicioMin;

  // Recortar cualquier bloqueo PARCIAL (con horas) que se solape con la
  // ventana. Un bloqueo sin horas (todo el día) ya excluye a esta
  // especialista por completo en el filtro obligatorio si cubre la hora
  // exacta de la cita -- si llegó hasta acá con un bloqueo así, es porque
  // no cubre esa hora puntual, así que no se resta (no hay rango que
  // recortar).
  for (final excepcion in excepciones) {
    if (excepcion['tipo'] != 'bloqueo') continue;

    final inicio = parsearHoraHHmm(excepcion['horaInicio']?.toString());
    final fin = parsearHoraHHmm(excepcion['horaFin']?.toString());
    if (inicio == null || fin == null) continue;

    final bloqueoInicio = minutosDesdeMedianoche(inicio);
    final bloqueoFin = minutosDesdeMedianoche(fin);

    final solapeInicio = bloqueoInicio > inicioMin ? bloqueoInicio : inicioMin;
    final solapeFin = bloqueoFin < finMin ? bloqueoFin : finMin;

    if (solapeFin > solapeInicio) {
      ventanaMin -= (solapeFin - solapeInicio);
    }
  }

  return ventanaMin < 0 ? 0 : ventanaMin;
}

// true si [horaConsultaMin] cae dentro del rango horaInicio/horaFin de la
// excepción -- si la excepción no trae horas (aplica todo el día) o
// vienen corruptas, se asume que aplica (más seguro para un bloqueo, y
// para un extra el peor caso es solo mostrar disponible de más, que el
// admin igual puede ignorar).
bool _horaDentroDeExcepcion(
  Map<String, dynamic> excepcion,
  int horaConsultaMin,
) {
  final horaInicioTexto = excepcion['horaInicio']?.toString();
  final horaFinTexto = excepcion['horaFin']?.toString();

  if (horaInicioTexto == null || horaFinTexto == null) return true;

  final inicio = parsearHoraHHmm(horaInicioTexto);
  final fin = parsearHoraHHmm(horaFinTexto);
  if (inicio == null || fin == null) return true;

  return horaConsultaMin >= minutosDesdeMedianoche(inicio) &&
      horaConsultaMin < minutosDesdeMedianoche(fin);
}

// Resultado de evaluar el horarioBase recurrente de UN día de semana
// contra un rango de fechas: si está activo, sus horas, y si alguna
// fecha calendario exacta de ese día de semana (dentro del rango) tiene
// una excepción registrada. tieneExcepcion es solo un AVISO -- no
// recalcula el estado como bloqueo/extra (ver calcularResumenRango).
class ResumenDiaSemana {
  final String clave;
  final bool activo;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFin;
  final bool tieneExcepcion;

  const ResumenDiaSemana({
    required this.clave,
    required this.activo,
    this.horaInicio,
    this.horaFin,
    required this.tieneExcepcion,
  });
}

// Evalúa horarioBase contra un rango de fechas, agrupado por día de
// semana (no por fecha calendario): horarioBase es recurrente y no
// cambia entre semanas, así que un rango de varias semanas no repite
// "lunes" una vez por cada semana -- basta con saber si ese día de
// semana OCURRE dentro del rango. [excepciones] debe venir ya filtrada a
// esta especialista (cualquier fecha) -- se cruza acá contra las fechas
// exactas del rango solo para marcar tieneExcepcion (alcance
// deliberadamente limitado a avisar, no a resolver bloqueo/extra: una
// excepción es de una fecha puntual y agruparla en un día de semana
// genérico perdería el detalle -- ver conversación de diseño).
List<ResumenDiaSemana> calcularResumenRango({
  required Map<String, dynamic>? horarioBase,
  required List<Map<String, dynamic>> excepciones,
  required DateTimeRange rango,
}) {
  final fechasPorDia = <String, List<String>>{};
  var cursor = DateTime(rango.start.year, rango.start.month, rango.start.day);
  final fin = DateTime(rango.end.year, rango.end.month, rango.end.day);

  while (!cursor.isAfter(fin)) {
    fechasPorDia
        .putIfAbsent(claveDiaSemana(cursor), () => [])
        .add(fechaIsoTexto(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }

  final resultado = <ResumenDiaSemana>[];

  for (final clave in clavesDiasSemana) {
    final fechasDeEsteDia = fechasPorDia[clave];
    if (fechasDeEsteDia == null) continue; // ese día no cae en el rango

    final diaData = horarioBase?[clave];
    final activo = diaData is Map && diaData['activo'] == true;
    final horaInicio =
        activo ? parsearHoraHHmm(diaData['horaInicio']?.toString()) : null;
    final horaFin =
        activo ? parsearHoraHHmm(diaData['horaFin']?.toString()) : null;

    final tieneExcepcion = excepciones.any(
      (e) => fechasDeEsteDia.contains(e['fecha']?.toString()),
    );

    resultado.add(ResumenDiaSemana(
      clave: clave,
      activo: activo && horaInicio != null && horaFin != null,
      horaInicio: horaInicio,
      horaFin: horaFin,
      tieneExcepcion: tieneExcepcion,
    ));
  }

  return resultado;
}
