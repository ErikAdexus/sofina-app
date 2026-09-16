// Representa una unidad de servicio ya guardada dentro de una cita (el
// bloque "servicios" que arma la Cloud Function crearCita en Sofina
// Cliente). Copia 1:1 del modelo equivalente en proyectocitas2 -- son
// apps Flutter separadas, no hay paquete compartido entre ambas.
class ItemCitaGuardado {
  final String servicioId;
  final String nombre;
  final double precio;
  final int duracionMinutos;
  final bool retiroUnas;
  final double montoRetiro;

  const ItemCitaGuardado({
    this.servicioId = '',
    required this.nombre,
    required this.precio,
    required this.duracionMinutos,
    required this.retiroUnas,
    required this.montoRetiro,
  });

  double get subtotal => precio + (retiroUnas ? montoRetiro : 0);
}

// Parsea el campo "servicios" (List) de una cita guardada en Firebase.
List<ItemCitaGuardado> parseServiciosDeCita(dynamic value) {
  if (value == null || value is! List) {
    return [];
  }

  return value.whereType<Map>().map((raw) {
    final data = Map<dynamic, dynamic>.from(raw);

    final precio = data['precio'] is num
        ? (data['precio'] as num).toDouble()
        : double.tryParse(data['precio']?.toString() ?? '') ?? 0.0;

    final duracion = data['duracionMinutos'] is int
        ? data['duracionMinutos'] as int
        : int.tryParse(data['duracionMinutos']?.toString() ?? '') ?? 0;

    final montoRetiro = data['montoRetiro'] is num
        ? (data['montoRetiro'] as num).toDouble()
        : double.tryParse(data['montoRetiro']?.toString() ?? '') ?? 0.0;

    return ItemCitaGuardado(
      servicioId: data['servicioId']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? 'Servicio',
      precio: precio,
      duracionMinutos: duracion,
      retiroUnas: data['retiroUnas'] == true,
      montoRetiro: montoRetiro,
    );
  }).toList();
}
