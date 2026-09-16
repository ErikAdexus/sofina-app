import 'package:flutter/material.dart';

import '../../models/dia_horario.dart';
import '../../services/auth_service.dart';
import '../../services/disponibilidad_service.dart';
import 'excepciones_page.dart';

const List<({String clave, String etiqueta})> _diasSemana = [
  (clave: 'lunes', etiqueta: 'Lunes'),
  (clave: 'martes', etiqueta: 'Martes'),
  (clave: 'miercoles', etiqueta: 'Miércoles'),
  (clave: 'jueves', etiqueta: 'Jueves'),
  (clave: 'viernes', etiqueta: 'Viernes'),
  (clave: 'sabado', etiqueta: 'Sábado'),
  (clave: 'domingo', etiqueta: 'Domingo'),
];

// Horario recurrente semanal de la especialista logueada: 7 días con
// toggle activo/inactivo + hora inicio/fin cuando está activo. Mismo
// patrón "leer, editar en memoria, guardar todo junto" que
// _TarjetaPrecioRetiro en catalogo_servicios_page.dart, pero como
// pantalla completa (no una tarjeta embebida) porque acá hay 7 filas, no
// un solo campo.
class HorarioBasePage extends StatefulWidget {
  const HorarioBasePage({super.key});

  @override
  State<HorarioBasePage> createState() => _HorarioBasePageState();
}

class _HorarioBasePageState extends State<HorarioBasePage> {
  bool cargando = true;
  bool guardando = false;
  String? errorCarga;

  final Map<String, DiaHorario> dias = {
    for (final d in _diasSemana) d.clave: DiaHorario(),
  };

  @override
  void initState() {
    super.initState();
    _cargarHorario();
  }

  Future<void> _cargarHorario() async {
    final uid = AuthService().currentUser?.uid;

    if (uid == null) {
      setState(() {
        errorCarga = 'No se pudo identificar tu cuenta.';
        cargando = false;
      });
      return;
    }

    try {
      final datos = await DisponibilidadService().cargarHorarioBase(uid);

      // Sin datos guardados todavía: se queda con el default (todo
      // inactivo) que ya trae el Map de arriba, no es un error.
      if (datos != null) {
        for (final d in _diasSemana) {
          final diaData = datos[d.clave];
          if (diaData is! Map) continue;

          dias[d.clave] = DiaHorario(
            activo: diaData['activo'] == true,
            horaInicio: parsearHoraHHmm(diaData['horaInicio']?.toString()) ??
                const TimeOfDay(hour: 9, minute: 0),
            horaFin: parsearHoraHHmm(diaData['horaFin']?.toString()) ??
                const TimeOfDay(hour: 18, minute: 0),
          );
        }
      }

      if (!mounted) return;
      setState(() => cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorCarga = 'No se pudo cargar tu horario: $e';
        cargando = false;
      });
    }
  }

  Future<void> _elegirHora(String clave, {required bool esInicio}) async {
    final dia = dias[clave]!;

    final hora = await showTimePicker(
      context: context,
      initialTime: esInicio ? dia.horaInicio : dia.horaFin,
    );

    if (hora == null) return;

    setState(() {
      if (esInicio) {
        dia.horaInicio = hora;
      } else {
        dia.horaFin = hora;
      }
    });
  }

  Future<void> _guardar() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    setState(() => guardando = true);

    try {
      final horario = {
        for (final d in _diasSemana)
          d.clave: {
            'activo': dias[d.clave]!.activo,
            'horaInicio': formatoHoraHHmm(dias[d.clave]!.horaInicio),
            'horaFin': formatoHoraHHmm(dias[d.clave]!.horaFin),
          },
      };

      await DisponibilidadService().guardarHorarioBase(uid, horario);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario guardado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorCarga!, textAlign: TextAlign.center),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mi horario',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Activa los días que trabajas y elige tu horario habitual. '
                    'Esto le sirve al administrador para saber cuándo estás '
                    'disponible al asignarte citas.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExcepcionesPage()),
                );
              },
              icon: const Icon(Icons.event_busy),
              label: const Text('Ver excepciones (bloqueos y días extra)'),
            ),
          ),
          const SizedBox(height: 12),
          for (final d in _diasSemana)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        d.etiqueta,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: dias[d.clave]!.activo,
                      onChanged: (valor) {
                        setState(() => dias[d.clave]!.activo = valor);
                      },
                    ),
                    if (dias[d.clave]!.activo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _elegirHora(d.clave, esInicio: true),
                                icon: const Icon(Icons.access_time, size: 18),
                                label: Text(
                                  formatoHoraHHmm(dias[d.clave]!.horaInicio),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('a'),
                            ),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _elegirHora(d.clave, esInicio: false),
                                icon: const Icon(Icons.access_time, size: 18),
                                label: Text(
                                  formatoHoraHHmm(dias[d.clave]!.horaFin),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(guardando ? 'Guardando...' : 'Guardar horario'),
            ),
          ),
        ],
      ),
    );
  }
}
