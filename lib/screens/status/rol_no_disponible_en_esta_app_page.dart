import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

// Se muestra si un usuario con rol "cliente" intenta iniciar sesión en
// esta app (que es solo para administrador y especialista).
class RolNoDisponibleEnEstaAppPage extends StatelessWidget {
  const RolNoDisponibleEnEstaAppPage({super.key});

  Future<void> cerrarSesion() async {
    await AuthService().cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final primarioOscuro =
        Theme.of(context).extension<SofinaColors>()!.primaryDark;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 72,
                    color: primarioOscuro,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Esta app es para el equipo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primarioOscuro,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Esta aplicación es solo para especialistas y administradores. '
                    'Para reservar una cita, descarga la app de clientes de Sofina Nail Salon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: cerrarSesion,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
