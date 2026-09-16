import 'package:flutter/material.dart';

// Un día del horario base de una especialista, en memoria (mientras
// arma/edita el formulario) -- se serializa a
// {activo, horaInicio: "HH:mm", horaFin: "HH:mm"} recién al guardar.
class DiaHorario {
  bool activo;
  TimeOfDay horaInicio;
  TimeOfDay horaFin;

  DiaHorario({
    this.activo = false,
    this.horaInicio = const TimeOfDay(hour: 9, minute: 0),
    this.horaFin = const TimeOfDay(hour: 18, minute: 0),
  });
}

String formatoHoraHHmm(TimeOfDay hora) {
  final h = hora.hour.toString().padLeft(2, '0');
  final m = hora.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

TimeOfDay? parsearHoraHHmm(String? texto) {
  if (texto == null) return null;
  final partes = texto.split(':');
  if (partes.length != 2) return null;

  final horas = int.tryParse(partes[0]);
  final minutos = int.tryParse(partes[1]);
  if (horas == null || minutos == null) return null;

  return TimeOfDay(hour: horas, minute: minutos);
}

// Minutos desde medianoche -- para comparar rangos horarios sin lidiar
// con TimeOfDay directamente (no es comparable con < / > de por sí).
int minutosDesdeMedianoche(TimeOfDay hora) => hora.hour * 60 + hora.minute;

// Claves de los 7 días tal como se guardan en horarioBase, en orden
// Lun->Dom (coincide 1:1 con DateTime.weekday, que va de 1 a 7).
const List<String> clavesDiasSemana = [
  'lunes',
  'martes',
  'miercoles',
  'jueves',
  'viernes',
  'sabado',
  'domingo',
];

// "lunes".."domingo" a partir del weekday de DateTime.
String claveDiaSemana(DateTime fecha) => clavesDiasSemana[fecha.weekday - 1];

// "YYYY-MM-DD" tal como se guarda 'fecha' en excepcionesDisponibilidad
// (ver DisponibilidadService) -- cero a la izquierda para que la
// comparación lexicográfica (startAt/endAt de Realtime Database)
// coincida con el orden cronológico real.
String fechaIsoTexto(DateTime f) {
  final anio = f.year.toString().padLeft(4, '0');
  final mes = f.month.toString().padLeft(2, '0');
  final dia = f.day.toString().padLeft(2, '0');
  return '$anio-$mes-$dia';
}
