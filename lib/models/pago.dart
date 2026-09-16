class Pago {
  final String id;
  final String citaId;
  final String clienteId;
  final String clienteNombre;
  final String especialistaId;
  final String especialistaNombre;
  final String servicio;
  final double montoDeclarado;
  final String metodoPago;
  final String fechaHora;
  final int fechaHoraMillis;
  final String estado;
  final String estadoConciliacion;

  const Pago({
    required this.id,
    required this.citaId,
    required this.clienteId,
    required this.clienteNombre,
    required this.especialistaId,
    required this.especialistaNombre,
    required this.servicio,
    required this.montoDeclarado,
    required this.metodoPago,
    required this.fechaHora,
    required this.fechaHoraMillis,
    required this.estado,
    required this.estadoConciliacion,
  });

  factory Pago.fromMap(String id, Map<dynamic, dynamic> data) {
    return Pago(
      id: id,
      citaId: data['citaId']?.toString() ?? id,
      clienteId: data['clienteId']?.toString() ?? '',
      clienteNombre: data['clienteNombre']?.toString() ?? '',
      especialistaId: data['especialistaId']?.toString() ?? '',
      especialistaNombre: data['especialistaNombre']?.toString() ?? '',
      servicio: data['servicio']?.toString() ?? '',
      montoDeclarado: data['montoDeclarado'] is num
          ? (data['montoDeclarado'] as num).toDouble()
          : double.tryParse(data['montoDeclarado']?.toString() ?? '') ?? 0.0,
      metodoPago: data['metodoPago']?.toString() ?? '',
      fechaHora: data['fechaHora']?.toString() ?? '',
      fechaHoraMillis: data['fechaHoraMillis'] is int
          ? data['fechaHoraMillis']
          : int.tryParse(data['fechaHoraMillis']?.toString() ?? '') ?? 0,
      estado: data['estado']?.toString() ?? 'confirmado_por_especialista',
      estadoConciliacion:
          data['estadoConciliacion']?.toString() ?? 'pendiente_revision',
    );
  }
}
