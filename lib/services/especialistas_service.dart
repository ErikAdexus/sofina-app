import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/firebase_refs.dart';
import '../models/datos_bancarios.dart';
import '../models/documento_identidad.dart';
import '../models/especialista_registro.dart';
import '../utils/auth_helpers.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class EspecialistasService {
  EspecialistasService({
    AuthService? authService,
    StorageService? storageService,
  })  : _authService = authService ?? AuthService(),
        _storageService = storageService ?? StorageService();

  final AuthService _authService;
  final StorageService _storageService;

  Stream<DatabaseEvent> streamEspecialistas() => dbRef('especialistas').onValue;

  // Self-lookup vía query, no escaneo completo -- el .read de
  // /especialistas ya no es plano, exige orderByChild('authUid').equalTo(
  // auth.uid) para cualquiera que no sea admin.
  Stream<DatabaseEvent> streamEspecialistaPropio(String uid) =>
      dbRef('especialistas').orderByChild('authUid').equalTo(uid).onValue;

  // AdminGestionCitasPage.cargarEspecialistasActivos: especialistas con
  // estado Activo, para poblar el diálogo de asignación de citas.
  Future<List<Map<String, dynamic>>> obtenerEspecialistasActivos() async {
    final snapshot = await dbRef('especialistas').get();

    if (snapshot.value == null || snapshot.value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final especialistas = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final data = Map<dynamic, dynamic>.from(value);
        final estado = data['estado']?.toString() ?? 'Pendiente';

        if (estado == 'Activo') {
          final resumen = data['calificacionResumen'] is Map
              ? Map<dynamic, dynamic>.from(data['calificacionResumen'])
              : null;

          especialistas.add({
            'id': key.toString(),
            'authUid': data['authUid']?.toString() ?? '',
            'nombreCompleto': data['nombreCompleto']?.toString() ?? '',
            'celular': data['celular']?.toString() ?? '',
            'correo': data['correo']?.toString() ?? '',
            'especialidad': data['especialidad']?.toString() ?? '',
            'estado': estado,
            // Nullable a propósito: sin distrito configurado no es un
            // "sin nombre" ni un valor por defecto, es simplemente un
            // dato que la especialista/admin todavía no completó.
            'distrito': data['distrito']?.toString(),
            // Texto libre tal cual lo escribió la especialista al
            // registrarse (ej. "2 años") -- null si el registro es tan
            // viejo que no tiene el campo.
            'experiencia': data['experiencia']?.toString(),
            'urlFoto': data['urlFoto']?.toString() ?? '',
            // Ya calculado por la Cloud Function actualizarResumenCalificacion
            // (proyectocitas2/functions/index.js) cada vez que se crea/borra
            // una calificación -- se lee del mismo registro que ya se trae
            // acá, sin ninguna lectura adicional.
            'calificacionPromedio':
                resumen != null && resumen['promedio'] is num
                    ? (resumen['promedio'] as num).toDouble()
                    : 0.0,
            'calificacionTotal': resumen != null && resumen['total'] is num
                ? (resumen['total'] as num).toInt()
                : 0,
          });
        }
      }
    });

    especialistas.sort((a, b) {
      return a['nombreCompleto']
          .toString()
          .compareTo(b['nombreCompleto'].toString());
    });

    return especialistas;
  }

  // Flujo de postulación pública: crea la cuenta de acceso, sube foto,
  // certificado y las fotos del documento de identidad, y guarda el
  // registro en `especialistas` con estado Pendiente hasta que el
  // administrador lo apruebe. `usuarios/$uid` se escribe apenas se crea el
  // Auth para que, si algo revienta antes de llegar a esa escritura, no
  // quede un Auth totalmente sin rastro en RTDB -- pero de ahí en adelante
  // (subidas a Storage + alta en `especialistas`) todo corre dentro de un
  // try/catch que revierte `usuarios/$uid` y borra el Auth si algo falla.
  // Antes, un fallo de Storage a mitad de camino dejaba `usuarios/$uid` en
  // estado 'Pendiente' para siempre sin que existiera el nodo en
  // `especialistas`: la app mostraba "Solicitud pendiente" pero no había
  // nada que un admin pudiera aprobar -- limbo permanente en vez de un
  // error que el postulante pudiera reintentar.
  Future<void> registrarPostulacion(EspecialistaRegistro datos) async {
    final ahora = DateTime.now();
    final fechaRegistro = ahora.toIso8601String();
    final fechaRegistroMillis = ahora.millisecondsSinceEpoch;

    final credencial = obtenerCredencialAcceso(
      metodoAcceso: datos.metodoAcceso,
      correo: datos.correo,
      telefono: datos.celular,
    );

    final credential = await _authService.registrarUsuario(
      credencial: credencial,
      password: datos.password,
    );

    final uid = credential.user?.uid;

    if (uid == null) {
      throw Exception('No se pudo obtener el UID de la especialista');
    }

    await credential.user?.updateDisplayName(datos.nombre);

    await dbRef('usuarios/$uid').set({
      'correo': datos.correo,
      'metodoAcceso': datos.metodoAcceso,
      'rol': 'especialista',
      'nombreCompleto': datos.nombre,
      'celular': datos.celular,
      'direccion': datos.direccion,
      'estado': 'Pendiente',
      'fechaRegistro': fechaRegistro,
      'fechaRegistroMillis': fechaRegistroMillis,
    });

    try {
      String contentTypeImagen(PlatformFile archivo) =>
          archivo.extension?.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';

      final urlFoto = await _storageService.subirArchivoRegistroPublico(
        archivo: datos.foto,
        carpeta: 'especialistas/fotos',
        contentType: contentTypeImagen(datos.foto),
      );

      final urlPdf = await _storageService.subirArchivoRegistroPublico(
        archivo: datos.pdfCertificado,
        carpeta: 'especialistas/certificados',
        contentType: 'application/pdf',
      );

      // Fotos del documento de identidad: path propio, separado de la foto de
      // perfil y del certificado -- no se reemplazan ni se mezclan entre sí.
      final urlDocumentoAnverso = await _storageService.subirArchivoRegistroPublico(
        archivo: datos.fotoDocumentoAnverso,
        carpeta: 'especialistas/documentoIdentidad/anverso',
        contentType: contentTypeImagen(datos.fotoDocumentoAnverso),
      );

      final urlDocumentoReverso = await _storageService.subirArchivoRegistroPublico(
        archivo: datos.fotoDocumentoReverso,
        carpeta: 'especialistas/documentoIdentidad/reverso',
        contentType: contentTypeImagen(datos.fotoDocumentoReverso),
      );

      final documentoIdentidad = DocumentoIdentidad(
        tipo: datos.tipoDocumento,
        numero: datos.numeroDocumento,
        paisOrigen: datos.paisOrigen,
        urlAnverso: urlDocumentoAnverso,
        urlReverso: urlDocumentoReverso,
        validacion: datos.validacionDni,
      );

      final datosBancarios = DatosBancarios(
        banco: datos.banco,
        bancoOtroNombre: datos.bancoOtroNombre,
        numeroCuenta: datos.numeroCuenta,
        cci: datos.cci,
        declaracionTitularidad: datos.declaracionTitularidad,
      );

      final especialistaRef = dbRef('especialistas').push();

      await dbRef('').update({
        'usuarios/$uid': {
          'correo': datos.correo,
          'metodoAcceso': datos.metodoAcceso,
          'rol': 'especialista',
          'nombreCompleto': datos.nombre,
          'celular': datos.celular,
          'direccion': datos.direccion,
          'estado': 'Pendiente',
          'fechaRegistro': fechaRegistro,
          'fechaRegistroMillis': fechaRegistroMillis,
        },
        'especialistas/${especialistaRef.key}': {
          'id': especialistaRef.key,
          'authUid': uid,
          'nombreCompleto': datos.nombre,
          'celular': datos.celular,
          'correo': datos.correo,
          'metodoAcceso': datos.metodoAcceso,
          'direccion': datos.direccion,
          'experiencia': datos.experiencia,
          'especialidad': datos.especialidad,
          'estado': 'Pendiente',
          'urlFoto': urlFoto,
          'urlPdf': urlPdf,
          'nombreFoto': datos.foto.name,
          'nombrePdf': datos.pdfCertificado.name,
          'documentoIdentidad': documentoIdentidad.toMap(),
          'datosBancarios': datosBancarios.toMap(),
          'fechaRegistro': fechaRegistro,
          'fechaRegistroMillis': fechaRegistroMillis,
        },
      });
    } catch (_) {
      // Sin esto, un fallo de Storage a mitad de camino dejaba
      // `usuarios/$uid` en 'Pendiente' para siempre sin nodo en
      // `especialistas` -- limbo permanente. Revertimos para que el
      // postulante pueda reintentar el registro desde cero con el mismo
      // correo/celular en vez de quedar atascado en "Solicitud pendiente".
      await dbRef('usuarios/$uid').remove();
      try {
        await credential.user?.delete();
      } catch (_) {
        // Si no se puede borrar el Auth (ej. requiere reautenticación
        // reciente), al menos ya no queda como "Pendiente" en RTDB; toca
        // limpiar el Auth huérfano manualmente desde Firebase Console.
      }
      rethrow;
    }
  }

  // Edición desde el listado de especialistas (admin): actualiza el
  // registro en `especialistas` y, si tiene cuenta de acceso, también
  // sincroniza los campos espejo en `usuarios`.
  Future<void> actualizarEspecialista({
    required String idEspecialista,
    required String authUid,
    required String nombreCompleto,
    required String celular,
    required String correo,
    required String direccion,
    required String experiencia,
    required String especialidad,
    required String estado,
    // Distrito donde VIVE la especialista (uno de utils/distritos_lima.dart,
    // los 43 de Lima Metropolitana), null = sin definir. Ya no se usa para
    // comparar contra ninguna cita -- esa lógica se eliminó de
    // abrirAsignarEspecialista; es solo un dato informativo del perfil.
    String? distrito,
  }) async {
    await dbRef('especialistas/$idEspecialista').update({
      'nombreCompleto': nombreCompleto,
      'celular': celular,
      'correo': correo,
      'direccion': direccion,
      'experiencia': experiencia,
      'especialidad': especialidad,
      'estado': estado,
      'distrito': distrito,
      'fechaActualizacion': DateTime.now().toIso8601String(),
    });

    if (authUid.isNotEmpty) {
      await dbRef('usuarios/$authUid').update({
        'nombreCompleto': nombreCompleto,
        'correo': correo,
        'estado': estado,
        'fechaActualizacion': DateTime.now().toIso8601String(),
      });
    }
  }
}
