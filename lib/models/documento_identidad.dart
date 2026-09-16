// Documento de identidad capturado en el Paso 3 del registro público de
// especialistas (RegistroEspecialistaPublicoPage) -- separado del resto del
// perfil porque tiene su propio par de fotos (anverso/reverso) y, si es
// DNI, una validación best-effort contra una API externa (ver
// DniValidacionService).
enum TipoDocumentoIdentidad {
  dni,
  carnetExtranjeria;

  String get valorRtdb =>
      this == TipoDocumentoIdentidad.dni ? 'dni' : 'carnet_extranjeria';

  String get etiqueta =>
      this == TipoDocumentoIdentidad.dni ? 'DNI' : 'Carné de Extranjería';
}

final RegExp formatoDni = RegExp(r'^\d{8}$');

// Largo alfanumérico de 6 a 15 caracteres: supuesto propio, no vino
// especificado un formato exacto de Carné de Extranjería. Ajustar acá si
// se define uno distinto.
final RegExp formatoCarnetExtranjeria = RegExp(r'^[A-Za-z0-9]{6,15}$');

// Resultado de intentar validar un DNI contra una API externa de terceros
// (best-effort, nunca bloquea el registro -- ver DniValidacionService).
// Se dispara automáticamente en el Paso 1 (documento), antes de que exista
// el nombre completo -- por eso ya no compara nombres, solo ofrece
// `nombreSugerido` para autocompletar el campo del Paso 2.
class ResultadoValidacionDni {
  final bool disponible;
  final String? nombreSugerido;
  final String mensaje;

  const ResultadoValidacionDni({
    required this.disponible,
    required this.nombreSugerido,
    required this.mensaje,
  });

  const ResultadoValidacionDni.noDisponible(this.mensaje)
      : disponible = false,
        nombreSugerido = null;

  Map<String, dynamic> toMap() {
    return {
      'disponible': disponible,
      if (nombreSugerido != null) 'nombreSugerido': nombreSugerido,
      'mensaje': mensaje,
    };
  }
}

class DocumentoIdentidad {
  final TipoDocumentoIdentidad tipo;
  final String numero;
  // Solo aplica (y se exige) si tipo == carnetExtranjeria.
  final String? paisOrigen;
  final String urlAnverso;
  final String urlReverso;
  // null si tipo == carnetExtranjeria (no se valida automático) o si el
  // registro se completó sin que la validación llegara a responder.
  final ResultadoValidacionDni? validacion;

  const DocumentoIdentidad({
    required this.tipo,
    required this.numero,
    this.paisOrigen,
    required this.urlAnverso,
    required this.urlReverso,
    this.validacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.valorRtdb,
      'numero': numero,
      if (tipo == TipoDocumentoIdentidad.carnetExtranjeria)
        'paisOrigen': paisOrigen,
      'urlAnverso': urlAnverso,
      'urlReverso': urlReverso,
      if (validacion != null) 'validacionApi': validacion!.toMap(),
    };
  }
}
