// Meses/días abreviados en español, copiados 1:1 de formato_fecha.dart en
// proyectocitas2 (Sofina Cliente) -- formateo manual, sin paquete intl, a
// propósito, para mantener el mismo enfoque en toda la familia de apps.
const _diasAbrev = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _mesesAbrev = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

// Encabezado del detalle de cita: "Lun 31 ago" (agrega el año al final
// si es distinto al actual, ej. "Lun 31 ago 2027").
String formatearFechaCorta(DateTime fecha) {
  final diaSemana = _diasAbrev[fecha.weekday - 1];
  final mes = _mesesAbrev[fecha.month - 1];
  final sufijoAnio = fecha.year != DateTime.now().year ? ' ${fecha.year}' : '';

  return '$diaSemana ${fecha.day} $mes$sufijoAnio';
}

// Hora en formato 12h con "a. m."/"p. m." (ej. "04:55 p. m."), mismo
// cálculo manual que formatoHora12h en proyectocitas2.
String formatearHora12h(DateTime fecha) {
  final periodo = fecha.hour >= 12 ? 'p. m.' : 'a. m.';
  var horas12 = fecha.hour % 12;
  if (horas12 == 0) horas12 = 12;
  final horasTexto = horas12.toString().padLeft(2, '0');
  final minutosTexto = fecha.minute.toString().padLeft(2, '0');
  return '$horasTexto:$minutosTexto $periodo';
}

// horaCita ya viene guardada como "HH:mm" (24h); esto solo la reformatea
// a 12h con "a. m."/"p. m." sin tocar la fecha -- mismo patrón que
// formatoHora12h en proyectocitas2. Si el string no tiene el formato
// esperado (dato corrupto/viejo), se devuelve tal cual.
String formatearHoraCitaTexto(String horaCita) {
  final partes = horaCita.split(':');
  if (partes.length != 2) return horaCita;

  final horas = int.tryParse(partes[0]);
  final minutos = int.tryParse(partes[1]);
  if (horas == null || minutos == null) return horaCita;

  final periodo = horas >= 12 ? 'p. m.' : 'a. m.';
  var horas12 = horas % 12;
  if (horas12 == 0) horas12 = 12;

  final horasTexto = horas12.toString().padLeft(2, '0');
  final minutosTexto = minutos.toString().padLeft(2, '0');
  return '$horasTexto:$minutosTexto $periodo';
}

// Hora compacta para los títulos de card en los listados de citas (Citas,
// Historial, Gestión de citas): "4:55 PM", sin cero a la izquierda, sin
// puntos, en mayúsculas -- garantiza una sola línea en el título en
// negrita del card, a diferencia de formatearHoraCitaTexto (formato
// completo "04:55 p. m."), que se sigue usando en los modales de detalle
// porque ahí hay espacio de sobra y no hay riesgo de wrap.
String formatearHoraCitaCompacta(String horaCita) {
  final partes = horaCita.split(':');
  if (partes.length != 2) return horaCita;

  final horas = int.tryParse(partes[0]);
  final minutos = int.tryParse(partes[1]);
  if (horas == null || minutos == null) return horaCita;

  final periodo = horas >= 12 ? 'PM' : 'AM';
  var horas12 = horas % 12;
  if (horas12 == 0) horas12 = 12;

  final minutosTexto = minutos.toString().padLeft(2, '0');
  return '$horas12:$minutosTexto $periodo';
}

// "Tu registro" (salida/llegada del especialista): "18 ago, 9:56 pm".
String formatearFechaHora(DateTime fecha) {
  final mes = _mesesAbrev[fecha.month - 1];
  return '${fecha.day} $mes, ${formatearHora12h(fecha)}';
}

// Fecha de una calificación: "Lun 31 ago", a partir del string ISO que
// RTDB guarda en calificaciones/{citaId}/fecha -- si no se puede
// parsear, cae al string crudo tal cual vino. Antes era
// formatoFecha/formatoFechaCalificacion, dos copias idénticas
// (mis_calificaciones_page.dart y admin_calificaciones_page.dart) que
// además daban un formato distinto ("31/08/2026") al resto de la app.
String formatearFechaCalificacion(String fechaIso) {
  final fecha = DateTime.tryParse(fechaIso);
  if (fecha == null) return fechaIso;
  return formatearFechaCorta(fecha);
}

// Tiempo entre que la especialista sale de casa y llega al cliente --
// usado en la sección "Tu registro" de CitasEspecialistaPage e
// HistorialEspecialistaPage (antes estaba solo en la primera, calculado
// inline). null si falta alguna fecha o si el resultado sale negativo
// (datos desordenados/corruptos): nunca un tiempo negativo.
Duration? calcularTiempoTraslado(DateTime? salida, DateTime? llegada) {
  if (salida == null || llegada == null) return null;
  final diferencia = llegada.difference(salida);
  return diferencia.isNegative ? null : diferencia;
}

double? leerDouble(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}

String normalizarTexto(dynamic value) {
  return value?.toString().trim() ?? '';
}

// Deja solo dígitos en el número de celular (quita espacios, guiones,
// paréntesis y el signo +).
String limpiarTelefono(String telefono) {
  return telefono.replaceAll(RegExp(r'[^0-9]'), '');
}
