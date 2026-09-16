// Una solicitud de cotización de un cliente para UNA unidad de un
// servicio con requiereCotizacion (ver ServicioCatalogo). El admin fija
// precioAcordado y pasa el estado a "cotizado"; la Cloud Function
// crearCita (Sofina Cliente) valida esto mismo del lado servidor antes
// de dejar reservar con ese precio.
class SolicitudCotizacion {
  final String id;
  final String clienteUid;
  final String clienteNombre;
  final String servicioId;
  final String servicioNombre;
  final String estado; // pendiente | cotizado | cerrado
  final double? precioAcordado;
  final int? fechaSolicitud;
  final int? fechaRespuesta;

  const SolicitudCotizacion({
    required this.id,
    required this.clienteUid,
    required this.clienteNombre,
    required this.servicioId,
    required this.servicioNombre,
    required this.estado,
    this.precioAcordado,
    this.fechaSolicitud,
    this.fechaRespuesta,
  });

  bool get pendiente => estado == 'pendiente';
  bool get cotizado => estado == 'cotizado';

  factory SolicitudCotizacion.fromMap(String id, Map<dynamic, dynamic> data) {
    final precioValor = data['precioAcordado'];

    return SolicitudCotizacion(
      id: id,
      clienteUid: data['clienteUid']?.toString() ?? '',
      clienteNombre: data['clienteNombre']?.toString() ?? '',
      servicioId: data['servicioId']?.toString() ?? '',
      servicioNombre: data['servicioNombre']?.toString() ?? '',
      estado: data['estado']?.toString() ?? 'pendiente',
      precioAcordado: precioValor is num ? precioValor.toDouble() : null,
      fechaSolicitud: data['fechaSolicitud'] is int
          ? data['fechaSolicitud'] as int
          : null,
      fechaRespuesta: data['fechaRespuesta'] is int
          ? data['fechaRespuesta'] as int
          : null,
    );
  }
}
