import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SolicitudPendientePage extends StatelessWidget {
  final String nombre;
  final String correo;

  const SolicitudPendientePage({
    super.key,
    required this.nombre,
    required this.correo,
  });

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
                  const Icon(
                    Icons.pending_actions,
                    size: 72,
                    color: Color(0xFFF9A825),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Solicitud pendiente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primarioOscuro,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (correo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      correo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Tu postulación como especialista está pendiente de revisión. El administrador debe aprobar tu cuenta para que puedas ver citas asignadas.',
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
