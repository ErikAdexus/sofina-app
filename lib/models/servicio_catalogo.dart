class ServicioCatalogo {
  final String id;
  final String categoriaId;
  final String categoriaNombre;
  final String nombre;
  final String descripcion;
  final double precio;
  final int duracionMinutos;
  final String estado;
  final int orden;
  final bool mostrarEnPublicidad;
  final String imagenAsset;
  // Servicio sin precio fijo (ej. "Paquete completo"): el precio se
  // acuerda directo con Sofía por WhatsApp. Campo separado de `precio` a
  // propósito -- ver Sofina Cliente para el detalle completo del flujo.
  final bool requiereCotizacion;

  const ServicioCatalogo({
    required this.id,
    required this.categoriaId,
    required this.categoriaNombre,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.duracionMinutos,
    required this.estado,
    required this.orden,
    required this.mostrarEnPublicidad,
    this.imagenAsset = '',
    this.requiereCotizacion = false,
  });

  bool get activo => estado.toLowerCase() == 'activo';

  factory ServicioCatalogo.fromMap(String id, Map<dynamic, dynamic> data) {
    final precioValor = data['precio'] is num
        ? (data['precio'] as num).toDouble()
        : double.tryParse(data['precio']?.toString() ?? '') ?? 0.0;

    final mostrarPublicidadValor = data.containsKey('mostrarEnPublicidad')
        ? data['mostrarEnPublicidad']
        : true;

    return ServicioCatalogo(
      id: id,
      categoriaId: data['categoriaId']?.toString() ?? '',
      categoriaNombre: data['categoriaNombre']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      precio: precioValor,
      duracionMinutos: data['duracionMinutos'] is int
          ? data['duracionMinutos']
          : int.tryParse(data['duracionMinutos']?.toString() ?? '') ?? 0,
      estado: data['estado']?.toString() ?? 'Activo',
      orden: data['orden'] is int
          ? data['orden']
          : int.tryParse(data['orden']?.toString() ?? '') ?? 0,
      mostrarEnPublicidad: mostrarPublicidadValor == true ||
          mostrarPublicidadValor.toString().toLowerCase() == 'true' ||
          mostrarPublicidadValor.toString().toLowerCase() == 'si' ||
          mostrarPublicidadValor.toString().toLowerCase() == 'sí',
      imagenAsset: data['imagenAsset']?.toString() ?? '',
      requiereCotizacion: data['requiereCotizacion'] == true,
    );
  }
}
