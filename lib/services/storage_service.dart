import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  Future<String> subirArchivoRegistroPublico({
    required PlatformFile archivo,
    required String carpeta,
    required String contentType,
  }) async {
    if (archivo.bytes == null) {
      throw Exception('No se pudo leer el archivo seleccionado');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nombreLimpio = archivo.name.replaceAll(' ', '_');

    final referencia = FirebaseStorage.instance
        .ref()
        .child(carpeta)
        .child('${timestamp}_$nombreLimpio');

    final metadata = SettableMetadata(
      contentType: contentType,
    );

    await referencia.putData(archivo.bytes!, metadata);

    return await referencia.getDownloadURL();
  }

  // A diferencia de subirArchivoRegistroPublico (que crea un archivo nuevo
  // por cada subida), esto sube siempre a la misma ruta fija para que cada
  // reemplazo sobrescriba el QR anterior en vez de acumular archivos.
  Future<String> subirQrPago({
    required PlatformFile archivo,
    required String contentType,
  }) async {
    if (archivo.bytes == null) {
      throw Exception('No se pudo leer el archivo seleccionado');
    }

    final referencia =
        FirebaseStorage.instance.ref().child('configuracion/qr_pago.png');

    final metadata = SettableMetadata(
      contentType: contentType,
    );

    await referencia.putData(archivo.bytes!, metadata);

    return await referencia.getDownloadURL();
  }
}
