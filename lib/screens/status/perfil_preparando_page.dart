import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class PerfilPreparandoPage extends StatelessWidget {
  final String correo;

  const PerfilPreparandoPage({
    super.key,
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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Preparando tu perfil',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primarioOscuro,
                    ),
                  ),
                  if (correo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      correo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: cerrarSesion,
                    icon: const Icon(Icons.logout),
                    label: const Text('Salir'),
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
