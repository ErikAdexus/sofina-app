import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/firebase_refs.dart';
import '../theme/app_theme.dart';

// Fondo de la píldora de servicio: rosa pálido fijo (estándar visual
// aprobado por Sofía, mockup "Detalle de mi cita" -- mismo valor que
// proyectocitas2/lib/widgets/servicio_chip.dart). Antes rotaba por hash
// de servicioId entre 6 colores por categoría; se retiró esa rotación a
// favor de un único tono de marca en toda la app.
const Color _colorFondoPildora = Color(0xFFFCEBEB);

// Fondo del círculo de ServicioAvatar cuando no hay foto (ícono de
// fallback) o mientras carga: durazno fijo (mismo mockup). Antes usaba
// SofinaColors.softTint, pero ese tono lo comparten otros usos (chips
// seleccionados, miniatura de categoría) que deben seguir pálidos --
// cambiarlo ahí habría afectado esas otras pantallas sin pedirlo.
const Color _colorAvatarServicio = Color(0xFFF0997B);

// Foto real del servicio (campo imagenAsset en servicios/{id}, un asset
// local ya declarado en pubspec.yaml -- comparte los mismos archivos que
// proyectocitas2/assets/images/servicios/), con fallback obligatorio a un
// ícono si no hay imagenAsset o falla la carga. Mismo lenguaje visual que
// EspecialistaAvatar (círculo, FutureBuilder de una sola vez -- vive
// dentro de un diálogo modal transitorio, no justifica un stream en vivo),
// con un borde sutil adicional.
class ServicioAvatar extends StatelessWidget {
  final String servicioId;
  final double radio;

  const ServicioAvatar({super.key, required this.servicioId, this.radio = 18});

  Widget _placeholder(BuildContext context) {
    return Container(
      width: radio * 2,
      height: radio * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colorAvatarServicio,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Icon(
        Icons.spa,
        size: radio,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (servicioId.isEmpty) {
      return _placeholder(context);
    }

    return FutureBuilder<DataSnapshot>(
      future: dbRef('servicios/$servicioId/imagenAsset').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholder(context);
        }

        final imagenAsset = snapshot.data?.value?.toString() ?? '';

        if (imagenAsset.isEmpty) {
          return _placeholder(context);
        }

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/servicios/$imagenAsset',
              width: radio * 2,
              height: radio * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            ),
          ),
        );
      },
    );
  }
}

// Avatar de una fila de listado de citas: foto de UNO de los servicios de
// la cita (ServicioAvatar) + punto de color de estado superpuesto en la
// esquina inferior derecha -- reemplaza el CircleAvatar genérico (ícono
// fijo sobre el color de estado como fondo completo) que usaban antes
// CitasEspecialistaPage/HistorialEspecialistaPage/AdminGestionCitasPage.
//
// Una cita puede tener varios servicios; recibe la lista completa de
// servicioId en el mismo orden del array servicios[] y prueba cada uno
// en secuencia (1 lectura RTDB por candidato, hasta encontrar el primero
// con imagenAsset no vacío) -- antes se usaba directo el primero del
// array sin verificar si tenía foto, así que una cita con el primer
// servicio sin foto (o con servicioId vacío, ej. datos migrados con
// esquema viejo) mostraba el ícono default aunque otro servicio de la
// misma cita sí tuviera foto disponible. Si ninguno tiene foto, cae al
// ícono default de ServicioAvatar como antes.
class AvatarCitaConEstado extends StatefulWidget {
  final List<String> serviciosIds;
  final Color colorEstado;
  final double radio;

  const AvatarCitaConEstado({
    super.key,
    required this.serviciosIds,
    required this.colorEstado,
    this.radio = 20,
  });

  @override
  State<AvatarCitaConEstado> createState() => _AvatarCitaConEstadoState();
}

class _AvatarCitaConEstadoState extends State<AvatarCitaConEstado> {
  late final Future<String> _servicioIdConFoto = _resolverServicioConFoto(
    widget.serviciosIds,
  );

  static Future<String> _resolverServicioConFoto(List<String> ids) async {
    for (final id in ids) {
      if (id.isEmpty) continue;

      final snapshot = await dbRef('servicios/$id/imagenAsset').get();
      final imagenAsset = snapshot.value?.toString() ?? '';

      if (imagenAsset.isNotEmpty) return id;
    }

    // Ninguno tiene foto: se devuelve el primero (o vacío si no hay
    // ninguno) para que ServicioAvatar caiga a su ícono default, igual
    // que antes.
    return ids.isNotEmpty ? ids.first : '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _servicioIdConFoto,
      builder: (context, snapshot) {
        final servicioId = snapshot.data ??
            (widget.serviciosIds.isNotEmpty ? widget.serviciosIds.first : '');

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ServicioAvatar(servicioId: servicioId, radio: widget.radio),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.colorEstado,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Fila de un servicio dentro del detalle de una cita: chip tipo pill
// (fondo rosa pálido fijo + texto en el tono oscuro derivado del primario +
// avatar) con el nombre a la izquierda, y el precio en una columna de
// ancho fijo a la derecha (mismo ancho que la fila "Total", para quedar
// alineados verticalmente).
class ServicioChip extends StatelessWidget {
  final String nombre;
  final double precio;
  final bool retiroUnas;

  // Id real del servicio para buscar su foto (servicios/{id}/imagenAsset).
  // Vacío en citas viejas sin servicios[] estructurado -- ServicioAvatar
  // cae solo al ícono de fallback en ese caso.
  final String servicioId;

  const ServicioChip({
    super.key,
    required this.nombre,
    required this.precio,
    this.servicioId = '',
    this.retiroUnas = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = Theme.of(context).extension<SofinaColors>()!.primaryDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _colorFondoPildora,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  ServicioAvatar(servicioId: servicioId, radio: 14),
                  const SizedBox(width: 8),
                  // Sin maxLines/ellipsis a propósito: el nombre del
                  // servicio nunca debe truncarse.
                  Expanded(
                    child: Text(
                      retiroUnas ? '$nombre (con retiro)' : nombre,
                      style: TextStyle(
                        color: colorTexto,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              'S/ ${precio.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Badge pequeño con la cantidad de servicios, junto al título "Servicios".
// Usa el color de marca del tema (lib/theme/app_theme.dart), ya
// centralizado en el proyecto -- antes tenía el vinotinto hardcodeado acá
// por asumir sin verificar que proyectocitas1 no tenía el ColorScheme
// vinotinto centralizado; sí lo tiene.
class BadgeContadorServicios extends StatelessWidget {
  final int cantidad;

  const BadgeContadorServicios({super.key, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$cantidad',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
