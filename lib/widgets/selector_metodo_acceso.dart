import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Selector reutilizable para elegir el método de acceso a la cuenta:
// correo electrónico o número de celular. Se usa en el login y en los
// formularios de registro (postulación de especialista y del administrador).
class SelectorMetodoAcceso extends StatelessWidget {
  final String metodoSeleccionado;
  final ValueChanged<String> onChanged;

  const SelectorMetodoAcceso({
    super.key,
    required this.metodoSeleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primarioOscuro =
        Theme.of(context).extension<SofinaColors>()!.primaryDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acceder con',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChanged('correo'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: metodoSeleccionado == 'correo'
                      ? colorScheme.primary
                      : Colors.white,
                  foregroundColor: metodoSeleccionado == 'correo'
                      ? colorScheme.onPrimary
                      : primarioOscuro,
                  side: BorderSide(color: colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.email),
                label: const Text('Correo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChanged('telefono'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: metodoSeleccionado == 'telefono'
                      ? colorScheme.primary
                      : Colors.white,
                  foregroundColor: metodoSeleccionado == 'telefono'
                      ? colorScheme.onPrimary
                      : primarioOscuro,
                  side: BorderSide(color: colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.phone_android),
                label: const Text('Celular'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
