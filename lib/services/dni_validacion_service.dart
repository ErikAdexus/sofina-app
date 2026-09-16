import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/documento_identidad.dart';

// Token del plan gratuito de apiperu.dev (100 consultas/mes) -- NUNCA
// hardcodear acá ni commitear un valor real. Se pasa como variable de
// compilación:
//   flutter run --dart-define=DNI_API_TOKEN=xxxxx
//   flutter build apk --dart-define=DNI_API_TOKEN=xxxxx
// Sin el --dart-define, queda vacío y validar() se comporta como "no
// configurado" -- caso más importante: quien clone el repo público sin
// conocer apiperu.dev debe poder registrar especialistas sin problema, el
// Paso 1 nunca asume que el token existe.
const String _dniApiToken = String.fromEnvironment('DNI_API_TOKEN');

const String _dniApiUrl = 'https://api.apiperu.dev/dni';

// Autocompletado best-effort del nombre a partir del DNI -- se dispara
// desde el Paso 1 de RegistroEspecialistaPublicoPage apenas el número
// tiene 8 dígitos válidos, antes de que exista el campo de nombre (vive en
// el Paso 2). Es puramente una ayuda: nunca bloquea el registro ni
// reintenta sola (para no gastar la cuota del plan gratuito). Si la API no
// responde, no encuentra el DNI, el token no está configurado, o es un
// Carné de Extranjería (nunca se consulta), el resultado es simplemente
// "no disponible" -- la especialista siempre puede escribir su nombre a
// mano sin ningún mensaje de error.
class DniValidacionService {
  Future<ResultadoValidacionDni> validar({required String numero}) async {
    if (_dniApiToken.isEmpty) {
      return const ResultadoValidacionDni.noDisponible(
        'Verificación automática de DNI aún no configurada. Puedes completar tu nombre manualmente en el siguiente paso.',
      );
    }

    try {
      final respuesta = await http
          .post(
            Uri.parse(_dniApiUrl),
            headers: {
              'Authorization': 'Bearer $_dniApiToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'dni': numero}),
          )
          .timeout(const Duration(seconds: 8));

      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

      if (cuerpo['success'] != true) {
        final codigo = cuerpo['code']?.toString();

        if (codigo == 'document_not_found') {
          return const ResultadoValidacionDni.noDisponible(
            'No encontramos ese documento. Puedes completar tu nombre manualmente en el siguiente paso.',
          );
        }

        // upstream_unavailable u otro código de error -- mismo trato,
        // sin reintento automático.
        return const ResultadoValidacionDni.noDisponible(
          'No se pudo verificar el DNI en este momento. Puedes completar tu nombre manualmente en el siguiente paso.',
        );
      }

      final datos = cuerpo['data'] as Map<String, dynamic>? ?? {};
      final nombreApi = [
        datos['nombres'],
        datos['apellido_paterno'],
        datos['apellido_materno'],
      ].whereType<String>().join(' ').trim();

      if (nombreApi.isEmpty) {
        return const ResultadoValidacionDni.noDisponible(
          'No se pudo obtener el nombre desde el DNI. Puedes completar tu nombre manualmente en el siguiente paso.',
        );
      }

      return ResultadoValidacionDni(
        disponible: true,
        nombreSugerido: _capitalizarNombre(nombreApi),
        mensaje: 'Nombre completado automáticamente desde tu DNI. Podrás corregirlo en el siguiente paso si hace falta.',
      );
    } catch (_) {
      // Timeout, sin conexión, JSON inesperado, etc. -- best-effort, nunca
      // bloquea el registro ni reintenta sola.
      return const ResultadoValidacionDni.noDisponible(
        'No se pudo verificar el DNI en este momento. Puedes completar tu nombre manualmente en el siguiente paso.',
      );
    }
  }
}

// La API devuelve el nombre en MAYÚSCULAS (ej. "MARÍA JOSÉ"); esto lo deja
// en formato título ("María José") para que se vea como un nombre
// tipeado normalmente al autocompletar el campo del Paso 2.
String _capitalizarNombre(String texto) {
  return texto
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((palabra) => palabra.isNotEmpty)
      .map((palabra) => palabra[0].toUpperCase() + palabra.substring(1))
      .join(' ');
}
