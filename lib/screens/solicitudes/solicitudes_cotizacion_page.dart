import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/solicitud_cotizacion.dart';
import '../../services/cotizacion_service.dart';
import '../../theme/app_theme.dart';

class SolicitudesCotizacionPage extends StatelessWidget {
  const SolicitudesCotizacionPage({super.key});

  List<SolicitudCotizacion> _convertir(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final solicitudes = <SolicitudCotizacion>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        solicitudes.add(
          SolicitudCotizacion.fromMap(
            key.toString(),
            Map<dynamic, dynamic>.from(value),
          ),
        );
      }
    });

    solicitudes.sort((a, b) {
      final fechaA = a.fechaSolicitud ?? 0;
      final fechaB = b.fechaSolicitud ?? 0;
      return fechaB.compareTo(fechaA);
    });

    return solicitudes;
  }

  void abrirFormularioCotizar(
      BuildContext context, SolicitudCotizacion solicitud) {
    final precioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cotizar servicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                solicitud.servicioNombre,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                  'Cliente: ${solicitud.clienteNombre.isEmpty ? 'Sin nombre' : solicitud.clienteNombre}'),
              const SizedBox(height: 12),
              TextField(
                controller: precioController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Precio acordado S/',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final precio = double.tryParse(precioController.text.trim());

                if (precio == null || precio <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingrese un precio válido')),
                  );
                  return;
                }

                try {
                  await CotizacionService().cotizar(
                    solicitudId: solicitud.id,
                    precioAcordado: precio,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cotizar: $e')),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjetaSolicitud(
    BuildContext context,
    SolicitudCotizacion solicitud, {
    required bool accionable,
  }) {
    final subtitulo = solicitud.cotizado
        ? 'Cliente: ${solicitud.clienteNombre.isEmpty ? 'Sin nombre' : solicitud.clienteNombre} · '
            'S/ ${(solicitud.precioAcordado ?? 0).toStringAsFixed(0)}'
        : 'Cliente: ${solicitud.clienteNombre.isEmpty ? 'Sin nombre' : solicitud.clienteNombre}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: solicitud.pendiente
              ? const Color(0xFFEF6C00)
              : (solicitud.cotizado ? const Color(0xFF2E7D32) : Colors.grey),
          child: const Icon(Icons.request_quote, color: Colors.white),
        ),
        title: Text(
          solicitud.servicioNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitulo),
        trailing: accionable
            ? ElevatedButton(
                onPressed: () => abrirFormularioCotizar(context, solicitud),
                child: const Text('Cotizar'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8EDEE),
      child: StreamBuilder<DatabaseEvent>(
        stream: CotizacionService().streamSolicitudes(),
        builder: (context, snapshot) {
          final solicitudes = _convertir(snapshot.data?.snapshot.value);
          final pendientes = solicitudes.where((s) => s.pendiente).toList();
          final cotizadas = solicitudes.where((s) => s.cotizado).toList();
          final cerradas =
              solicitudes.where((s) => s.estado == 'cerrado').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitudes de cotización',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .extension<SofinaColors>()!
                              .primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Clientes que quieren reservar un servicio sin precio fijo. '
                        'Cotiza cada solicitud para que puedan reservar en la app.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (pendientes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No hay solicitudes pendientes de cotizar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...pendientes.map(
                  (s) => _tarjetaSolicitud(context, s, accionable: true),
                ),
              if (cotizadas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  child: ExpansionTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('Cotizadas (${cotizadas.length})'),
                    children: cotizadas
                        .map((s) =>
                            _tarjetaSolicitud(context, s, accionable: false))
                        .toList(),
                  ),
                ),
              ],
              if (cerradas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  child: ExpansionTile(
                    leading: const Icon(Icons.history),
                    title: Text('Cerradas (${cerradas.length})'),
                    children: cerradas
                        .map((s) =>
                            _tarjetaSolicitud(context, s, accionable: false))
                        .toList(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
