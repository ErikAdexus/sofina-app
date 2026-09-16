import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';
import '../models/servicio_catalogo.dart';

class CatalogoService {
  Stream<DatabaseEvent> streamCategorias() => dbRef('categoriasServicios').onValue;

  Stream<DatabaseEvent> streamServicios() => dbRef('servicios').onValue;

  // Si `id` es null crea una categoría nueva (push); si no, actualiza la
  // existente en `categoriasServicios/$id`.
  Future<void> guardarCategoria({
    String? id,
    required String nombre,
    required String estado,
    required int orden,
  }) async {
    final esNueva = id == null;
    final ref = esNueva
        ? dbRef('categoriasServicios').push()
        : dbRef('categoriasServicios/$id');

    await ref.update({
      'id': ref.key,
      'nombre': nombre,
      'estado': estado,
      'orden': orden,
      (esNueva ? 'fechaRegistro' : 'fechaActualizacion'):
          DateTime.now().toIso8601String(),
    });
  }

  // Si `id` es null crea un servicio nuevo (push); si no, actualiza el
  // existente en `servicios/$id`.
  Future<void> guardarServicio({
    String? id,
    required String categoriaId,
    required String categoriaNombre,
    required String nombre,
    required String descripcion,
    required double precio,
    required int duracionMinutos,
    required String estado,
    required int orden,
    required bool mostrarEnPublicidad,
    String imagenAsset = '',
    bool requiereCotizacion = false,
  }) async {
    final esNuevo = id == null;
    final ref = esNuevo ? dbRef('servicios').push() : dbRef('servicios/$id');

    await ref.update({
      'id': ref.key,
      'categoriaId': categoriaId,
      'categoriaNombre': categoriaNombre,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'duracionMinutos': duracionMinutos,
      'estado': estado,
      'orden': orden,
      'mostrarEnPublicidad': mostrarEnPublicidad,
      'imagenAsset': imagenAsset,
      'requiereCotizacion': requiereCotizacion,
      (esNuevo ? 'fechaRegistro' : 'fechaActualizacion'):
          DateTime.now().toIso8601String(),
    });
  }

  // Alterna Activo/Inactivo y devuelve el nuevo estado.
  Future<String> cambiarEstadoServicio(ServicioCatalogo servicio) async {
    final nuevoEstado = servicio.activo ? 'Inactivo' : 'Activo';

    await dbRef('servicios/${servicio.id}').update({
      'estado': nuevoEstado,
      'fechaActualizacion': DateTime.now().toIso8601String(),
    });

    return nuevoEstado;
  }
}
