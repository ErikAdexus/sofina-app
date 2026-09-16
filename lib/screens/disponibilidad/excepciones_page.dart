import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/dia_horario.dart';
import '../../services/auth_service.dart';
import '../../services/disponibilidad_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

// Excepciones puntuales sobre el horario base: bloquear un día/rango
// específico, o agregar disponibilidad extra fuera del horario habitual.
// Mismo patrón que solicitudes_cotizacion_page.dart -- lista (acá vía
// stream, filtrada a la propia especialista por el query de
// DisponibilidadService.streamExcepciones) + diálogo de alta + tarjeta
// con botón de eliminar.
class ExcepcionesPage extends StatelessWidget {
  const ExcepcionesPage({super.key});

  List<Map<String, dynamic>> _convertir(dynamic value) {
    if (value == null || value is! Map) return [];

    final mapa = Map<dynamic, dynamic>.from(value);
    final excepciones = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        excepciones.add({
          'id': key.toString(),
          ...Map<String, dynamic>.from(value),
        });
      }
    });

    excepciones.sort((a, b) {
      final fechaA = a['fecha']?.toString() ?? '';
      final fechaB = b['fecha']?.toString() ?? '';
      return fechaA.compareTo(fechaB);
    });

    return excepciones;
  }

  void _abrirFormularioAgregar(BuildContext context, String authUid) {
    DateTime? fechaElegida;
    String tipo = 'bloqueo';
    TimeOfDay? horaInicio;
    TimeOfDay? horaFin;
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nueva excepción'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final elegida = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 2),
                        );
                        if (elegida != null) {
                          setStateDialog(() => fechaElegida = elegida);
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        fechaElegida == null
                            ? 'Elegir fecha'
                            : formatearFechaCorta(fechaElegida!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'bloqueo',
                          label: Text('Bloqueo'),
                          icon: Icon(Icons.block),
                        ),
                        ButtonSegment(
                          value: 'extra',
                          label: Text('Extra'),
                          icon: Icon(Icons.add_circle_outline),
                        ),
                      ],
                      selected: {tipo},
                      onSelectionChanged: (seleccion) {
                        setStateDialog(() => tipo = seleccion.first);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tipo == 'bloqueo'
                          ? 'No vas a trabajar ese día (o esa franja horaria).'
                          : 'Vas a trabajar aunque normalmente no te toque.',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hora (opcional -- si no eliges, aplica todo el día)',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final elegida = await showTimePicker(
                                context: context,
                                initialTime: horaInicio ??
                                    const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (elegida != null) {
                                setStateDialog(() => horaInicio = elegida);
                              }
                            },
                            child: Text(
                              horaInicio == null
                                  ? 'Inicio'
                                  : formatoHoraHHmm(horaInicio!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final elegida = await showTimePicker(
                                context: context,
                                initialTime: horaFin ??
                                    const TimeOfDay(hour: 18, minute: 0),
                              );
                              if (elegida != null) {
                                setStateDialog(() => horaFin = elegida);
                              }
                            },
                            child: Text(
                              horaFin == null
                                  ? 'Fin'
                                  : formatoHoraHHmm(horaFin!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: motivoController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (fechaElegida == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Elige una fecha')),
                      );
                      return;
                    }

                    if ((horaInicio == null) != (horaFin == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Elige ambas horas, o ninguna (todo el día)'),
                        ),
                      );
                      return;
                    }

                    final anio = fechaElegida!.year.toString().padLeft(4, '0');
                    final mes = fechaElegida!.month.toString().padLeft(2, '0');
                    final dia = fechaElegida!.day.toString().padLeft(2, '0');

                    try {
                      await DisponibilidadService().crearExcepcion(
                        authUid: authUid,
                        fecha: '$anio-$mes-$dia',
                        tipo: tipo,
                        horaInicio: horaInicio == null
                            ? null
                            : formatoHoraHHmm(horaInicio!),
                        horaFin:
                            horaFin == null ? null : formatoHoraHHmm(horaFin!),
                        motivo: motivoController.text.trim(),
                      );

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al guardar: $e')),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _eliminar(BuildContext context, String excepcionId) async {
    try {
      await DisponibilidadService().eliminarExcepcion(excepcionId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  Widget _tarjetaExcepcion(
      BuildContext context, Map<String, dynamic> excepcion) {
    final esBloqueo = excepcion['tipo'] == 'bloqueo';
    final horaInicio = excepcion['horaInicio']?.toString();
    final horaFin = excepcion['horaFin']?.toString();
    final motivo = excepcion['motivo']?.toString() ?? '';

    final horaTexto = (horaInicio != null && horaFin != null)
        ? '$horaInicio - $horaFin'
        : 'Todo el día';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              esBloqueo ? sofinaColorPeligro : const Color(0xFF2E7D32),
          child: Icon(
            esBloqueo ? Icons.block : Icons.add_circle_outline,
            color: Colors.white,
          ),
        ),
        title: Text(
          excepcion['fecha']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${esBloqueo ? 'Bloqueo' : 'Extra'} · $horaTexto'
          '${motivo.isEmpty ? '' : '\n$motivo'}',
        ),
        isThreeLine: motivo.isNotEmpty,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: sofinaColorPeligro,
          onPressed: () => _eliminar(context, excepcion['id'].toString()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUid = AuthService().currentUser?.uid;

    if (authUid == null) {
      return const Center(child: Text('No se pudo identificar tu cuenta.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excepciones'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormularioAgregar(context, authUid),
        child: const Icon(Icons.add),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: StreamBuilder<DatabaseEvent>(
          stream: DisponibilidadService().streamExcepciones(authUid),
          builder: (context, snapshot) {
            final excepciones = _convertir(snapshot.data?.snapshot.value);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Días puntuales donde no vas a trabajar, o donde vas '
                          'a trabajar aunque no te toque según tu horario base.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (excepciones.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No tienes excepciones registradas. Toca "+" para agregar una.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...excepciones.map((e) => _tarjetaExcepcion(context, e)),
              ],
            );
          },
        ),
      ),
    );
  }
}
