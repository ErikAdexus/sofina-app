import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../services/calificaciones_service.dart';
import '../../services/especialistas_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

Widget construirEstrellasCalificacion(int puntuacion, {double size = 18}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      return Icon(
        i < puntuacion ? Icons.star : Icons.star_border,
        color: const Color(0xFFF9A825),
        size: size,
      );
    }),
  );
}

// formatoFechaCalificacion ahora vive centralizada como
// formatearFechaCalificacion en utils/formatters.dart (antes era una
// copia idéntica a la de mis_calificaciones_page.dart, con un formato
// distinto -- "31/08/2026" -- al del resto de la app).

// Vista principal: un especialista por fila con su calificacionResumen
// (promedio + total, ya calculado por la Cloud Function
// actualizarResumenCalificacion, nunca recalculado acá). Ordenado de
// menor a mayor promedio para detectar problemas primero; los que
// todavía no tienen ninguna calificación (total 0) van al final para no
// confundirlos con un promedio malo real.
class AdminCalificacionesPage extends StatelessWidget {
  const AdminCalificacionesPage({super.key});

  List<Map<String, dynamic>> convertirResumenes(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final especialistas = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is! Map) return;

      final data = Map<dynamic, dynamic>.from(value);
      final resumen = data['calificacionResumen'] is Map
          ? Map<dynamic, dynamic>.from(data['calificacionResumen'])
          : null;

      especialistas.add({
        'id': key.toString(),
        'nombreCompleto':
            data['nombreCompleto']?.toString() ?? 'Sin nombre',
        'promedio': resumen != null && resumen['promedio'] is num
            ? (resumen['promedio'] as num).toDouble()
            : 0.0,
        'total': resumen != null && resumen['total'] is num
            ? (resumen['total'] as num).toInt()
            : 0,
      });
    });

    especialistas.sort((a, b) {
      final totalA = a['total'] as int;
      final totalB = b['total'] as int;

      if (totalA == 0 && totalB == 0) {
        return (a['nombreCompleto'] as String)
            .compareTo(b['nombreCompleto'] as String);
      }

      if (totalA == 0) return 1;
      if (totalB == 0) return -1;

      return (a['promedio'] as double).compareTo(b['promedio'] as double);
    });

    return especialistas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calificaciones')),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: StreamBuilder<DatabaseEvent>(
          stream: EspecialistasService().streamEspecialistas(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Error al cargar especialistas'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final especialistas = convertirResumenes(
              snapshot.data?.snapshot.value,
            );

            if (especialistas.isEmpty) {
              return const Center(
                child: Text(
                  'No hay especialistas registrados',
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: especialistas.length,
              itemBuilder: (context, index) {
                final data = especialistas[index];
                final total = data['total'] as int;
                final promedio = data['promedio'] as double;
                final nombre = data['nombreCompleto'] as String;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: total == 0
                          ? Colors.grey
                          : const Color(0xFFF9A825),
                      child: Text(
                        total > 0 ? promedio.toStringAsFixed(1) : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        construirEstrellasCalificacion(promedio.round()),
                        const SizedBox(width: 8),
                        Text(
                          total == 0
                              ? 'Sin calificaciones'
                              : total == 1
                                  ? '1 calificación'
                                  : '$total calificaciones',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DetalleCalificacionesEspecialistaPage(
                            especialistaId: data['id'] as String,
                            nombreEspecialista: nombre,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Detalle: todas las calificaciones individuales de un especialista, con
// opción de eliminar cada una (moderación de comentarios inapropiados).
// Al eliminar solo se hace remove() en calificaciones/{citaId}; el
// recalculo del resumen lo hace la Cloud Function, nunca este cliente.
class DetalleCalificacionesEspecialistaPage extends StatelessWidget {
  final String especialistaId;
  final String nombreEspecialista;

  const DetalleCalificacionesEspecialistaPage({
    super.key,
    required this.especialistaId,
    required this.nombreEspecialista,
  });

  List<Map<String, dynamic>> filtrarCalificaciones(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final calificaciones = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is! Map) return;

      final data = Map<dynamic, dynamic>.from(value);

      if ((data['especialistaId']?.toString() ?? '') != especialistaId) {
        return;
      }

      calificaciones.add({
        'id': key.toString(),
        'puntuacion': data['puntuacion'] is num
            ? (data['puntuacion'] as num).toInt()
            : int.tryParse(data['puntuacion']?.toString() ?? '') ?? 0,
        'comentario': data['comentario']?.toString() ?? '',
        'servicio': data['servicio']?.toString() ?? '',
        'fecha': data['fecha']?.toString() ?? '',
        'fechaMillis':
            data['fechaMillis'] is int ? data['fechaMillis'] as int : 0,
      });
    });

    calificaciones.sort(
      (a, b) =>
          (b['fechaMillis'] as int).compareTo(a['fechaMillis'] as int),
    );

    return calificaciones;
  }

  Future<void> confirmarEliminar(BuildContext context, String citaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar calificación'),
          content: const Text(
            '¿Eliminar esta calificación permanentemente?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: sofinaColorPeligro,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await CalificacionesService().eliminarCalificacion(citaId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calificación eliminada')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(nombreEspecialista)),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: StreamBuilder<DatabaseEvent>(
          stream: CalificacionesService().streamCalificaciones(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Error al cargar calificaciones'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final calificaciones = filtrarCalificaciones(
              snapshot.data?.snapshot.value,
            );

            if (calificaciones.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Esta especialista todavía no tiene calificaciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: calificaciones.length,
              itemBuilder: (context, index) {
                final calificacion = calificaciones[index];
                final comentario = calificacion['comentario'] as String;
                final servicio = calificacion['servicio'] as String;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            construirEstrellasCalificacion(
                              calificacion['puntuacion'] as int,
                            ),
                            Row(
                              children: [
                                Text(
                                  formatearFechaCalificacion(
                                    calificacion['fecha'] as String,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: sofinaColorPeligro,
                                  tooltip: 'Eliminar calificación',
                                  onPressed: () => confirmarEliminar(
                                    context,
                                    calificacion['id'] as String,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (servicio.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            servicio,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (comentario.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(comentario),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
