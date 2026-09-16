class CategoriaServicio {
  final String id;
  final String nombre;
  final String estado;
  final int orden;

  const CategoriaServicio({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.orden,
  });

  bool get activo => estado.toLowerCase() == 'activo';

  factory CategoriaServicio.fromMap(String id, Map<dynamic, dynamic> data) {
    return CategoriaServicio(
      id: id,
      nombre: data['nombre']?.toString() ?? '',
      estado: data['estado']?.toString() ?? 'Activo',
      orden: data['orden'] is int
          ? data['orden']
          : int.tryParse(data['orden']?.toString() ?? '') ?? 0,
    );
  }
}
