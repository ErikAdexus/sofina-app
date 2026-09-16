import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import 'formatters.dart';

// Genera una credencial de tipo correo a partir de un número de celular,
// para poder crear la cuenta en Firebase Authentication (que solo trabaja
// con correo/contraseña) sin necesidad de verificación por SMS y sin
// generar ningún costo adicional.
String correoDesdeTelefono(String telefono) {
  final limpio = limpiarTelefono(telefono);
  return 'tel_$limpio@$dominioAccesoTelefono';
}

// Indica si un correo es una credencial interna generada a partir de un
// número de celular (y no un correo real ingresado por el usuario).
bool esCorreoInterno(String correo) {
  return correo.trim().toLowerCase().endsWith('@$dominioAccesoTelefono');
}

// Devuelve la credencial que se debe usar para iniciar sesión / registrarse
// en Firebase Authentication, según el método de acceso elegido.
String obtenerCredencialAcceso({
  required String metodoAcceso,
  required String correo,
  required String telefono,
}) {
  if (metodoAcceso == 'telefono') {
    return correoDesdeTelefono(telefono);
  }
  return correo.trim();
}

// Devuelve un texto amigable para mostrar al usuario (su correo real o su
// celular), evitando mostrar la credencial interna generada a partir del
// número de celular.
String identificadorParaMostrar({
  String? correo,
  String? celular,
  String? metodoAcceso,
  String? correoAuth,
}) {
  final correoTexto = normalizarTexto(correo);
  final celularTexto = normalizarTexto(celular);
  final metodo = normalizarTexto(metodoAcceso).toLowerCase();

  if (metodo == 'telefono' && celularTexto.isNotEmpty) {
    return celularTexto;
  }

  if (correoTexto.isNotEmpty) {
    return correoTexto;
  }

  if (celularTexto.isNotEmpty) {
    return celularTexto;
  }

  final correoAuthTexto = normalizarTexto(correoAuth);

  if (correoAuthTexto.isNotEmpty && !esCorreoInterno(correoAuthTexto)) {
    return correoAuthTexto;
  }

  return '';
}

String mensajeErrorAuth(FirebaseAuthException e, {String metodoAcceso = 'correo'}) {
  if (e.code == 'email-already-in-use') {
    return metodoAcceso == 'telefono'
        ? 'Ese número de celular ya está registrado'
        : 'El correo ya está registrado en Authentication';
  }

  if (e.code == 'invalid-email') {
    return metodoAcceso == 'telefono'
        ? 'El número de celular ingresado no es válido'
        : 'El correo ingresado no es válido';
  }

  if (e.code == 'weak-password') {
    return 'La contraseña es muy débil. Debe tener mínimo 6 caracteres';
  }

  if (e.code == 'network-request-failed') {
    return 'Sin conexión a internet';
  }

  return 'Error de autenticación: ${e.message ?? e.code}';
}
