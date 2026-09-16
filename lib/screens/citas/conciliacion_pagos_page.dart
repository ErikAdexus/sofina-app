import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/pago.dart';
import '../../services/pagos_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

// Fase 2 del cobro de servicios: el admin revisa los pagos que las
// especialistas confirmaron y los marca contra su app bancaria. Esta
// pantalla solo lista y marca estado, no calcula totales ni reportes.
class ConciliacionPagosPage extends StatefulWidget {
  const ConciliacionPagosPage({super.key});

  @override
  State<ConciliacionPagosPage> createState() => _ConciliacionPagosPageState();
}

class _ConciliacionPagosPageState extends State<ConciliacionPagosPage> {
  String filtro = 'pendiente_revision';

  // Cacheado: PagosService().streamPagos() crea un Stream nuevo en cada
  // llamada. Si se llamara directo en build(), cada setState() (ej. tocar
  // un filtro) le pasaría a StreamBuilder una instancia distinta y lo
  // forzaría a desuscribirse/resuscribirse, mostrando el spinner de carga
  // en cada interacción aunque los datos ya estén en memoria.
  late final Stream<DatabaseEvent> _pagosStream = PagosService().streamPagos();

  List<Pago> convertirPagos(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final pagos = <Pago>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        pagos.add(Pago.fromMap(key.toString(), Map<dynamic, dynamic>.from(value)));
      }
    });

    pagos.sort((a, b) => b.fechaHoraMillis.compareTo(a.fechaHoraMillis));

    return pagos;
  }

  Future<void> marcarConciliacion(
    BuildContext context,
    Pago pago,
    String nuevoEstado,
  ) async {
    try {
      await PagosService().actualizarEstadoConciliacion(
        citaId: pago.citaId,
        estadoConciliacion: nuevoEstado,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'conciliado'
                ? 'Pago marcado como conciliado'
                : 'Pago marcado como no coincide',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar conciliación: $e'),
        ),
      );
    }
  }

  Color colorEstadoConciliacion(String estado) {
    switch (estado) {
      case 'conciliado':
        return const Color(0xFF2E7D32);
      case 'no_coincide':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFF9A825);
    }
  }

  String etiquetaEstadoConciliacion(String estado) {
    switch (estado) {
      case 'conciliado':
        return 'Conciliado';
      case 'no_coincide':
        return 'No coincide';
      default:
        return 'Pendiente de revisión';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: StreamBuilder<DatabaseEvent>(
        stream: _pagosStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al cargar pagos'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final todosLosPagos = convertirPagos(snapshot.data?.snapshot.value);
          final pagos = filtro == 'todos'
              ? todosLosPagos
              : todosLosPagos.where((p) => p.estadoConciliacion == filtro).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Pendientes'),
                        selected: filtro == 'pendiente_revision',
                        onSelected: (_) {
                          setState(() => filtro = 'pendiente_revision');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Conciliados'),
                        selected: filtro == 'conciliado',
                        onSelected: (_) {
                          setState(() => filtro = 'conciliado');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('No coincide'),
                        selected: filtro == 'no_coincide',
                        onSelected: (_) {
                          setState(() => filtro = 'no_coincide');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: filtro == 'todos',
                        onSelected: (_) {
                          setState(() => filtro = 'todos');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: pagos.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay pagos en este filtro',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: pagos.length,
                        itemBuilder: (context, index) {
                          final pago = pagos[index];

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
                                      Expanded(
                                        child: Text(
                                          formatearFechaHora(
                                            DateTime.fromMillisecondsSinceEpoch(
                                              pago.fechaHoraMillis,
                                            ),
                                          ),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorEstadoConciliacion(
                                            pago.estadoConciliacion,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          etiquetaEstadoConciliacion(
                                            pago.estadoConciliacion,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Monto: S/ ${pago.montoDeclarado.toStringAsFixed(0)} · ${pago.metodoPago}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cliente: ${pago.clienteNombre.isEmpty ? 'Sin nombre' : pago.clienteNombre}',
                                  ),
                                  Text(
                                    'Especialista: ${pago.especialistaNombre.isEmpty ? 'Sin nombre' : pago.especialistaNombre}',
                                  ),
                                  Text(
                                    'Servicio: ${pago.servicio.isEmpty ? 'Sin servicio' : pago.servicio}',
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => marcarConciliacion(
                                            context,
                                            pago,
                                            'conciliado',
                                          ),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Coincide'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF2E7D32),
                                            side: const BorderSide(
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => marcarConciliacion(
                                            context,
                                            pago,
                                            'no_coincide',
                                          ),
                                          icon: const Icon(Icons.close, size: 18),
                                          label: const Text('No coincide'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: sofinaColorPeligro,
                                            side: const BorderSide(
                                              color: sofinaColorPeligro,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
      ),
    );
  }
}
