import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

// Mismo patrón visual/de navegación que MiCuentaPage en Sofina Cliente
// (proyectocitas2/lib/pages/mi_cuenta_page.dart): tarjeta con datos +
// logout con confirmación, en vez del logout directo que tenía antes el
// AppBar acá.
//
// nombre/identificador/rol llegan ya resueltos desde AuthGate (vía
// HomePage), no se vuelven a calcular acá -- así lo que se muestra
// siempre coincide exactamente con lo que la app usa para decidir
// permisos, sin una segunda fuente de verdad que se pueda desincronizar.
class MiCuentaPage extends StatelessWidget {
  final String nombre;
  final String identificador;
  final String rol;

  const MiCuentaPage({
    super.key,
    required this.nombre,
    required this.identificador,
    required this.rol,
  });

  String etiquetaRol(String rol) {
    switch (rol) {
      case 'administrador':
        return 'Administrador';
      case 'especialista':
        return 'Especialista';
      default:
        return rol;
    }
  }

  Widget construirDato(
      BuildContext context, IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  valor.isEmpty ? 'Sin registrar' : valor,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Logout real: reutiliza AuthService().cerrarSesion() (mismo método que
  // usaba el ícono directo del AppBar). Tras signOut(), AuthGate cambia
  // por dentro a PublicHomePage, pero esta pantalla sigue apilada
  // (se abrió con Navigator.push desde HomePage) y lo taparía si no se
  // hace pop hasta la raíz.
  Future<void> confirmarCerrarSesion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Vas a salir por completo de tu cuenta. La próxima vez vas a '
          'tener que ingresar tus credenciales de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    await AuthService().cerrarSesion();

    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mi cuenta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tus datos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .extension<SofinaColors>()!
                            .primaryDark,
                      ),
                    ),
                    const Divider(height: 20),
                    construirDato(context, Icons.person, 'Nombre', nombre),
                    construirDato(
                      context,
                      Icons.alternate_email,
                      'Correo o celular',
                      identificador,
                    ),
                    construirDato(
                      context,
                      Icons.badge,
                      'Rol',
                      etiquetaRol(rol),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => confirmarCerrarSesion(context),
              style: TextButton.styleFrom(
                foregroundColor: sofinaColorPeligro,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
