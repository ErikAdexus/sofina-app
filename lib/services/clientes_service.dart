import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';

class ClientesService {
  Stream<DatabaseEvent> streamClientes() => dbRef('clientes').onValue;

  // Edición desde el listado de clientes (admin): actualiza el registro en
  // `clientes` y, si tiene cuenta de acceso, sincroniza los campos espejo
  // en `usuarios`.
  Future<void> actualizarCliente({
    required String idCliente,
    required String authUid,
    required String nombreCompleto,
    required String celular,
    required String direccion,
    required String correo,
    required String estado,
  }) async {
    await dbRef('clientes/$idCliente').update({
      'nombreCompleto': nombreCompleto,
      'celular': celular,
      'direccion': direccion,
      'correo': correo,
      'estado': estado,
      'fechaActualizacion': DateTime.now().toIso8601String(),
    });

    if (authUid.isNotEmpty) {
      await dbRef('usuarios/$authUid').update({
        'nombreCompleto': nombreCompleto,
        'correo': correo,
        'direccion': direccion,
        'estado': estado,
        'fechaActualizacion': DateTime.now().toIso8601String(),
      });
    }
  }
}
