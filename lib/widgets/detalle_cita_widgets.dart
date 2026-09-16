import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/firebase_refs.dart';
import '../theme/app_theme.dart';

// Piezas reutilizables del diseño "detalle de cita" (chips de colores +
// avatar + secciones), compartidas entre admin_gestion_citas_page.dart
// (rol administrador) y citas_especialista_page.dart (rol especialista) --
// ambas pantallas muestran el mismo tipo de detalle, con distinta
// selección de secciones según quién lo ve.

// Color/ícono por estado de cita -- antes triplicado, idéntico, en
// admin_gestion_citas_page.dart, citas_especialista_page.dart y
// historial_especialista_page.dart; ahora centralizado acá. NO es color
// de marca: identifica el estado (Confirmada, Cancelada, etc.), igual que
// en Sofina Cliente (estado_cita.dart), donde tampoco se usa vinotinto
// para esto. Cancelada usa sofinaColorPeligro (mismo rojo de error del
// tema) en vez de repetir el hex suelto.
Color colorEstadoCita(String estado) {
  switch (estado) {
    case 'Confirmada':
      return const Color(0xFF1565C0);
    case 'En camino':
      return const Color(0xFFEF6C00);
    case 'En sitio':
      return const Color(0xFF00897B);
    case 'Atendida':
      return const Color(0xFF2E7D32);
    case 'Cancelada':
      return sofinaColorPeligro;
    case 'Pendiente':
      return const Color(0xFFF9A825);
    default:
      return Colors.grey;
  }
}

IconData iconoEstadoCita(String estado) {
  switch (estado) {
    case 'Confirmada':
      return Icons.check_circle;
    case 'En camino':
      return Icons.directions_car;
    case 'En sitio':
      return Icons.location_on;
    case 'Atendida':
      return Icons.check_circle;
    case 'Cancelada':
      return Icons.cancel;
    case 'Pendiente':
      return Icons.schedule;
    default:
      return Icons.info;
  }
}

// Píldora compacta de estado para filas de listado (Card > ListTile) --
// mismo criterio de contraste que BadgeEstadoCita (fondo al 14% de
// opacidad + texto/ícono en el color sólido), pero de ancho automático en
// vez de ocupar todo el ancho, para convivir en línea con la fecha/hora
// en vez de una línea de texto plano "Estado: X" suelta.
class PildoraEstadoCita extends StatelessWidget {
  final String estado;

  const PildoraEstadoCita({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoCita(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstadoCita(estado), color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            estado,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Avatar del cliente: solo iniciales -- el cliente no tiene campo urlFoto
// en RTDB (a diferencia de especialistas, ver listado_especialistas_page.dart),
// así que acá nunca se intenta cargar una imagen ni hay FutureBuilder de
// por medio.
class ClienteAvatar extends StatelessWidget {
  final String nombre;
  final double radio;

  const ClienteAvatar({super.key, required this.nombre, this.radio = 20});

  String get _iniciales {
    final partes =
        nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();

    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        _iniciales,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Avatar de la especialista: foto real (campo urlFoto en
// especialistas/{id}) con fallback a iniciales si está vacío o falla la
// carga -- mismo patrón que EspecialistaAvatar en Sofina Cliente
// (proyectocitas2/lib/widgets/especialista_avatar.dart). Future puntual
// (.get()), no stream: vive dentro de un diálogo modal transitorio, no
// justifica una suscripción en vivo.
class EspecialistaAvatar extends StatelessWidget {
  final String especialistaId;
  final String nombre;
  final double radio;

  const EspecialistaAvatar({
    super.key,
    required this.especialistaId,
    required this.nombre,
    this.radio = 20,
  });

  String get _iniciales {
    final partes =
        nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();

    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _placeholderIniciales(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        _iniciales,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (especialistaId.isEmpty) {
      return _placeholderIniciales(context);
    }

    return FutureBuilder<DataSnapshot>(
      future: dbRef('especialistas/$especialistaId/urlFoto').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholderIniciales(context);
        }

        final url = snapshot.data?.value?.toString() ?? '';

        if (url.isEmpty) {
          return _placeholderIniciales(context);
        }

        return ClipOval(
          child: Image.network(
            url,
            width: radio * 2,
            height: radio * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _placeholderIniciales(context);
            },
            errorBuilder: (context, error, stackTrace) {
              return _placeholderIniciales(context);
            },
          ),
        );
      },
    );
  }
}

// Bloque de información con ícono + título + contenido, reutilizado para
// dirección del servicio, contacto del cliente, observación y datos del
// especialista asignado en el detalle de cita -- mismo patrón visual para
// todas las secciones, en vez de líneas de texto plano sueltas.
class SeccionInfoCita extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Widget child;

  const SeccionInfoCita({
    super.key,
    required this.icono,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EDEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context)
                        .extension<SofinaColors>()!
                        .primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Badge de estado: recibe el color/ícono ya resueltos (ver
// colorEstadoCita/iconoEstadoCita arriba) -- NO usa la paleta vinotinto,
// el color acá identifica el estado de la cita, igual que en Sofina
// Cliente, donde tampoco se usa el color de marca para esto.
class BadgeEstadoCita extends StatelessWidget {
  final String estado;
  final Color color;
  final IconData icono;

  const BadgeEstadoCita({
    super.key,
    required this.estado,
    required this.color,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            estado,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Fila con punto de color + texto, usada en la sección "Tu registro"
// (salida/llegada de la especialista) -- antes era una copia privada
// (_FilaRegistroConPunto) solo en citas_especialista_page.dart; ahora
// también la usa historial_especialista_page.dart.
class FilaRegistroConPunto extends StatelessWidget {
  final Color color;
  final String texto;

  const FilaRegistroConPunto({
    super.key,
    required this.color,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
