import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class CuentaRechazadaPage extends StatelessWidget {
  final String nombre;
  final String correo;

  const CuentaRechazadaPage({
    super.key,
    required this.nombre,
    required this.correo,
  });

  Future<void> cerrarSesion() async {
    await AuthService().cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
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
                    Icons.cancel,
                    size: 72,
                    color: sofinaColorPeligro,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Solicitud rechazada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: sofinaColorPeligro,
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
                    'Tu solicitud no fue aprobada. Puedes comunicarte con administración para más información.',
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
