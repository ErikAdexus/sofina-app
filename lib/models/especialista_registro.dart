import 'package:file_picker/file_picker.dart';

import 'datos_bancarios.dart';
import 'documento_identidad.dart';

// Agrupa todo lo que junta RegistroEspecialistaPublicoPage a lo largo de
// sus 4 pasos, antes de pasarlo a EspecialistasService.registrarPostulacion
// (que sigue siendo quien sube los archivos y arma el payload final de
// RTDB). Antes de este modelo, registrarPostulacion recibía 9 parámetros
// sueltos -- esto tipa ese mismo contrato, no cambia el patrón de
// escritura directa a RTDB que ya tenía.
class EspecialistaRegistro {
  // Paso 1 -- datos personales y acceso
  final String metodoAcceso;
  final String nombre;
  final String celular;
  final String correo;
  final String password;

  // Paso 2 -- perfil profesional
  final String direccion;
  final String experiencia;
  final String especialidad;
  final PlatformFile foto;
  final PlatformFile pdfCertificado;

  // Paso 3 -- documento de identidad (las fotos se suben en
  // EspecialistasService; acá solo viajan los PlatformFile seleccionados)
  final TipoDocumentoIdentidad tipoDocumento;
  final String numeroDocumento;
  final String? paisOrigen;
  final PlatformFile fotoDocumentoAnverso;
  final PlatformFile fotoDocumentoReverso;
  final ResultadoValidacionDni? validacionDni;

  // Paso 4 -- datos bancarios
  final BancoEspecialista banco;
  final String? bancoOtroNombre;
  final String numeroCuenta;
  final String cci;
  final bool declaracionTitularidad;

  const EspecialistaRegistro({
    required this.metodoAcceso,
    required this.nombre,
    required this.celular,
    required this.correo,
    required this.password,
    required this.direccion,
    required this.experiencia,
    required this.especialidad,
    required this.foto,
    required this.pdfCertificado,
    required this.tipoDocumento,
    required this.numeroDocumento,
    this.paisOrigen,
    required this.fotoDocumentoAnverso,
    required this.fotoDocumentoReverso,
    this.validacionDni,
    required this.banco,
    this.bancoOtroNombre,
    required this.numeroCuenta,
    required this.cci,
    required this.declaracionTitularidad,
  });
}
