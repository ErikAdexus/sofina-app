import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../services/auth_service.dart';
import '../../services/calificaciones_service.dart';
import '../../services/especialistas_service.dart';
import '../../utils/formatters.dart';

// Las calificaciones y calificacionResumen se indexan por especialistaId
// (la clave del registro en /especialistas), no por el uid de Firebase
// Auth del especialista logueado -- son identificadores distintos. Por
// eso primero hay que resolver el propio registro en /especialistas
// (buscando authUid == uid actual, mismo patrón que
// CitasEspecialistaPage) antes de poder leer el resumen o filtrar la
// lista de calificaciones.
class MisCalificacionesPage extends StatelessWidget {
  const MisCalificacionesPage({super.key});

  Map<String, dynamic>? resolverMiEspecialista(dynamic value) {
    final user = AuthService().currentUser;

    if (user == null || value == null || value is! Map) {
      return null;
    }

    final uidActual = user.uid;
    final correoActual = user.email ?? '';

    final mapa = Map<dynamic, dynamic>.from(value);
    Map<String, dynamic>? encontrado;

    mapa.forEach((key, value) {
      if (encontrado != null || value is! Map) return;

      final data = Map<dynamic, dynamic>.from(value);
      final authUid = data['authUid']?.toString() ?? '';
      final correo = data['correo']?.toString() ?? '';

      final esMiPerfil = authUid == uidActual ||
          (correoActual.isNotEmpty && correo == correoActual);

      if (!esMiPerfil) return;

      final resumen = data['calificacionResumen'] is Map
          ? Map<dynamic, dynamic>.from(data['calificacionResumen'])
          : null;

      final promedio = resumen != null && resumen['promedio'] is num
          ? (resumen['promedio'] as num).toDouble()
          : 0.0;

      final total = resumen != null && resumen['total'] is num
          ? (resumen['total'] as num).toInt()
          : 0;

      encontrado = {
        'especialistaId': key.toString(),
        'promedio': promedio,
        'total': total,
      };
    });

    return encontrado;
  }

  List<Map<String, dynamic>> filtrarMisCalificaciones(
    dynamic value,
    String especialistaId,
  ) {
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

  // formatoFecha ahora vive centralizada como formatearFechaCalificacion
  // en utils/formatters.dart (antes era una copia idéntica a la de
  // admin_calificaciones_page.dart, con un formato distinto -- "31/08/2026"
  // -- al del resto de la app).

  Widget construirEstrellas(int puntuacion, {double size = 20}) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: StreamBuilder<DatabaseEvent>(
        stream: EspecialistasService().streamEspecialistaPropio(
          AuthService().currentUser?.uid ?? '',
        ),
        builder: (context, especialistasSnapshot) {
          if (especialistasSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final miPerfil = resolverMiEspecialista(
            especialistasSnapshot.data?.snapshot.value,
          );

          if (miPerfil == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se encontró tu perfil de especialista.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          final especialistaId = miPerfil['especialistaId'] as String;
          final promedio = miPerfil['promedio'] as double;
          final total = miPerfil['total'] as int;

          return StreamBuilder<DatabaseEvent>(
            stream: CalificacionesService()
                .streamCalificacionesDeEspecialista(especialistaId),
            builder: (context, calificacionesSnapshot) {
              if (calificacionesSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final calificaciones = filtrarMisCalificaciones(
                calificacionesSnapshot.data?.snapshot.value,
                especialistaId,
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              total > 0 ? promedio.toStringAsFixed(1) : '--',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            construirEstrellas(promedio.round(), size: 24),
                            const SizedBox(height: 8),
                            Text(
                              total == 1
                                  ? '1 calificación'
                                  : '$total calificaciones',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: calificaciones.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Todavía no tienes calificaciones.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: calificaciones.length,
                            itemBuilder: (context, index) {
                              final calificacion = calificaciones[index];
                              final comentario =
                                  calificacion['comentario'] as String;
                              final servicio =
                                  calificacion['servicio'] as String;

                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          construirEstrellas(
                                            calificacion['puntuacion']
                                                as int,
                                          ),
                                          Text(
                                            formatearFechaCalificacion(
                                              calificacion['fecha']
                                                  as String,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (servicio.isNotEmpty) ...[
                                        const SizedBox(height: 8),
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
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
