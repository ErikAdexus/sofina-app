import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/firebase_refs.dart';
import '../../utils/formatters.dart';
import '../../utils/auth_helpers.dart';
import '../home/public_home_page.dart';
import '../home/home_page.dart';
import '../status/perfil_preparando_page.dart';
import '../status/solicitud_pendiente_page.dart';
import '../status/cuenta_rechazada_page.dart';
import '../status/cuenta_inactiva_page.dart';
import '../status/rol_no_disponible_en_esta_app_page.dart';
import '../status/no_autorizado_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const PublicHomePage();
        }

        return StreamBuilder<DatabaseEvent>(
          stream: dbRef('usuarios/${user.uid}').onValue,
          builder: (context, usuarioSnapshot) {
            if (usuarioSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (usuarioSnapshot.hasError) {
              return const NoAutorizadoPage();
            }

            final value = usuarioSnapshot.data?.snapshot.value;

            if (value == null) {
              return PerfilPreparandoPage(
                correo: identificadorParaMostrar(correoAuth: user.email),
              );
            }

            if (value is! Map) {
              return const NoAutorizadoPage();
            }

            final data = Map<dynamic, dynamic>.from(value);
            final rol = normalizarTexto(data['rol']).toLowerCase();
            final estadoOriginal = normalizarTexto(data['estado']);
            final estado = estadoOriginal.toLowerCase();
            final nombre = normalizarTexto(data['nombreCompleto']).isEmpty
                ? user.email ?? 'Usuario'
                : normalizarTexto(data['nombreCompleto']);
            final identificador = identificadorParaMostrar(
              correo: data['correo'],
              celular: data['celular'],
              metodoAcceso: data['metodoAcceso'],
              correoAuth: user.email,
            );

            // Esta app es solo para administrador y especialista.
            // Un cliente que intente entrar ve un aviso y no accede.
            if (rol == 'cliente') {
              return const RolNoDisponibleEnEstaAppPage();
            }

            final rolValido = rol == 'administrador' || rol == 'especialista';

            if (!rolValido) {
              return const NoAutorizadoPage();
            }

            if (rol == 'especialista') {
              if (estado == 'pendiente' || estado.isEmpty) {
                return SolicitudPendientePage(
                  nombre: nombre,
                  correo: identificador,
                );
              }

              if (estado == 'rechazado' || estado == 'rechazada') {
                return CuentaRechazadaPage(
                  nombre: nombre,
                  correo: identificador,
                );
              }

              if (estado != 'activo') {
                return CuentaInactivaPage(
                  nombre: nombre,
                  correo: identificador,
                );
              }
            }

            if (rol == 'administrador') {
              if (estado == 'inactivo' || estado == 'bloqueado') {
                return CuentaInactivaPage(
                  nombre: nombre,
                  correo: identificador,
                );
              }
            }

            return HomePage(
              rol: rol,
              identificador: identificador,
              nombre: nombre,
            );
          },
        );
      },
    );
  }
}
