import 'package:flutter/material.dart';

import '../../models/dia_horario.dart';
import '../../services/disponibilidad_service.dart';
import '../../services/especialistas_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/disponibilidad_calculo.dart';
import '../../utils/formatters.dart';

// "¿Quién está libre?" para el admin, en dos vistas dentro de la misma
// pantalla: por horario puntual (fecha+hora → quién está libre justo
// ahí, útil al momento de asignar una cita) y semanal (resumen del
// horario base de todas juntas, para tener una foto general).
class FranjaHorariaPage extends StatelessWidget {
  const FranjaHorariaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Disponibilidad de especialistas'),
          bottom: const TabBar(
            isScrollable: false, // ambas pestañas mismo ancho, siempre visibles
            tabs: [
              Tab(icon: Icon(Icons.date_range), text: 'Por horario'),
              Tab(icon: Icon(Icons.calendar_view_week), text: 'Semanal'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _VistaPorHorario(),
            _VistaSemanal(),
          ],
        ),
      ),
    );
  }
}

const _etiquetasDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

// Evita mostrar 7 filas de "-" cuando la especialista simplemente no
// configuró nada todavía: en ese caso el dato útil es "falta
// configurar", no la lista completa de días vacíos. Compartida entre
// _VistaSemanal y _VistaPorHorario.
bool _horarioSinConfigurar(Map<String, dynamic>? horario) {
  if (horario == null) return true;
  return clavesDiasSemana.every((clave) {
    final diaData = horario[clave];
    return diaData is! Map || diaData['activo'] != true;
  });
}

// "¿Quién puede trabajar este rango?" para el admin: elige un rango de
// fechas (y opcionalmente una hora puntual) y ve, por especialista activa,
// qué días de la semana caen dentro de su horario recurrente -- agrupado
// por día de semana (Lun..Dom), no por fecha calendario, porque
// horarioBase es semanal recurrente y no cambia entre semanas del rango.
// Las excepciones puntuales (excepcionesDisponibilidad) del rango se
// cruzan solo para AVISAR (marca "⚠" en el día afectado): no cambian el
// estado calculado, porque una excepción es de una fecha calendario
// específica y agruparla dentro de un día de semana genérico perdería el
// detalle -- si el admin ve el aviso, revisa esa fecha puntual aparte
// (alcance decidido explícitamente así, ver conversación de diseño).
class _VistaPorHorario extends StatefulWidget {
  const _VistaPorHorario();

  @override
  State<_VistaPorHorario> createState() => _VistaPorHorarioState();
}

class _VistaPorHorarioState extends State<_VistaPorHorario> {
  DateTimeRange? rango;
  TimeOfDay? hora;

  bool cargando = true;
  bool consultando = false;
  String? error;
  List<Map<String, dynamic>> especialistas = [];
  Map<String, Map<String, dynamic>> horariosBase = {};
  List<Map<String, dynamic>> excepcionesDelRango = [];

  @override
  void initState() {
    super.initState();
    _cargarBase();
  }

  Future<void> _cargarBase() async {
    try {
      final resultados = await Future.wait([
        EspecialistasService().obtenerEspecialistasActivos(),
        DisponibilidadService().cargarHorarioBaseDeTodas(),
      ]);

      if (!mounted) return;
      setState(() {
        especialistas = resultados[0] as List<Map<String, dynamic>>;
        horariosBase = resultados[1] as Map<String, Map<String, dynamic>>;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Error al cargar especialistas: $e';
        cargando = false;
      });
    }
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final elegido = await showDateRangePicker(
      context: context,
      firstDate: hoy.subtract(const Duration(days: 1)),
      lastDate: DateTime(hoy.year + 2),
      initialDateRange: rango,
    );

    if (elegido == null) return;
    setState(() {
      rango = elegido;
      excepcionesDelRango = [];
    });
    await _consultarExcepciones();
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: hora ?? TimeOfDay.now(),
    );

    if (elegida == null) return;
    setState(() => hora = elegida);
  }

  Future<void> _consultarExcepciones() async {
    final rangoElegido = rango;
    if (rangoElegido == null) return;

    setState(() {
      consultando = true;
      error = null;
    });

    try {
      final excepciones = await DisponibilidadService().cargarExcepcionesDeRango(
        fechaIsoTexto(rangoElegido.start),
        fechaIsoTexto(rangoElegido.end),
      );

      if (!mounted) return;
      setState(() {
        excepcionesDelRango = excepciones;
        consultando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Error al consultar excepciones: $e';
        consultando = false;
      });
    }
  }

  String _rangoTexto(DateTimeRange r) =>
      '${formatearFechaCorta(r.start)} - ${formatearFechaCorta(r.end)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Quién puede trabajar?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elige un rango de fechas para ver qué especialistas '
                    'activas trabajan cada día. La hora es opcional: si la '
                    'indicas, se resalta si cae dentro del horario.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _elegirRango,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      rango == null
                          ? 'Elegir rango de fechas'
                          : _rangoTexto(rango!),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _elegirHora,
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            hora == null
                                ? 'Elegir hora (opcional)'
                                : formatearHora12h(
                                    DateTime(2000, 1, 1, hora!.hour, hora!.minute),
                                  ),
                          ),
                        ),
                      ),
                      if (hora != null)
                        IconButton(
                          onPressed: () => setState(() => hora = null),
                          icon: const Icon(Icons.close),
                          tooltip: 'Quitar hora',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (cargando || consultando)
            const Center(child: CircularProgressIndicator()),
          if (error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: sofinaColorPeligro),
                ),
              ),
            ),
          if (!cargando && !consultando && error == null && rango != null)
            if (especialistas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay especialistas activas.'),
                ),
              )
            else
              ...especialistas.map((especialista) {
                final authUid = especialista['authUid']?.toString() ?? '';
                return _TarjetaResumenRango(
                  especialista: especialista,
                  horarioBase: horariosBase[authUid],
                  excepciones: excepcionesDelRango
                      .where((e) => e['especialistaId']?.toString() == authUid)
                      .toList(),
                  rango: rango!,
                  hora: hora,
                );
              }),
        ],
      ),
    );
  }
}

class _TarjetaResumenRango extends StatelessWidget {
  final Map<String, dynamic> especialista;
  final Map<String, dynamic>? horarioBase;
  final List<Map<String, dynamic>> excepciones;
  final DateTimeRange rango;
  final TimeOfDay? hora;

  const _TarjetaResumenRango({
    required this.especialista,
    required this.horarioBase,
    required this.excepciones,
    required this.rango,
    required this.hora,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (especialista['nombreCompleto'] ?? '').toString();
    final especialidad = (especialista['especialidad'] ?? '').toString();
    final titulo = especialidad.isEmpty ? nombre : '$nombre — $especialidad';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_horarioSinConfigurar(horarioBase))
              const Text(
                'Aún no configuró su horario',
                style: TextStyle(color: Colors.black54),
              )
            else
              ..._construirLineas(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _construirLineas(BuildContext context) {
    final resumen = calcularResumenRango(
      horarioBase: horarioBase,
      excepciones: excepciones,
      rango: rango,
    );

    final horaElegida = hora;
    final disponibles = <ResumenDiaSemana>[];
    final fueraDeHora = <ResumenDiaSemana>[];
    final noDisponibles = <ResumenDiaSemana>[];

    for (final dia in resumen) {
      if (!dia.activo) {
        noDisponibles.add(dia);
        continue;
      }
      if (horaElegida == null) {
        disponibles.add(dia);
        continue;
      }
      final minutosHora = minutosDesdeMedianoche(horaElegida);
      final dentro = minutosHora >= minutosDesdeMedianoche(dia.horaInicio!) &&
          minutosHora < minutosDesdeMedianoche(dia.horaFin!);
      (dentro ? disponibles : fueraDeHora).add(dia);
    }

    return [
      if (disponibles.isNotEmpty)
        ..._lineasAgrupadas(
          etiqueta: horaElegida == null ? 'Disponible' : 'Disponible a esa hora',
          color: const Color(0xFF2E7D32),
          dias: disponibles,
        ),
      if (fueraDeHora.isNotEmpty)
        ..._lineasAgrupadas(
          etiqueta: 'Trabaja, pero no a esa hora',
          color: Colors.deepOrange,
          dias: fueraDeHora,
        ),
      if (noDisponibles.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'No disponible: ${noDisponibles.map(_etiquetaDia).join(', ')}',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
      ..._lineasExcepciones(),
    ];
  }

  String _etiquetaDia(ResumenDiaSemana dia) {
    final base = _etiquetasDias[clavesDiasSemana.indexOf(dia.clave)];
    return dia.tieneExcepcion ? '$base ⚠' : base;
  }

  // Una línea por excepción exacta (no por día de semana): agrupar acá
  // perdería justo el detalle que el marcador "⚠" de _etiquetaDia no
  // puede dar por sí solo (ver conversación de diseño -- el aviso
  // genérico "revisar caso a caso" no alcanzaba, hacía falta la fecha,
  // el tipo y la hora exactos de cada excepción).
  List<Widget> _lineasExcepciones() {
    final ordenadas = excepciones
        .where((e) => DateTime.tryParse(e['fecha']?.toString() ?? '') != null)
        .toList()
      ..sort((a, b) {
        final claveA = '${a['fecha']}${a['horaInicio'] ?? ''}';
        final claveB = '${b['fecha']}${b['horaInicio'] ?? ''}';
        return claveA.compareTo(claveB);
      });

    return ordenadas.map((excepcion) {
      final fecha = DateTime.parse(excepcion['fecha'].toString());

      final tipo = switch (excepcion['tipo']?.toString()) {
        'bloqueo' => 'Bloqueo',
        'extra' => 'Extra',
        final otro? => otro,
        null => 'Excepción',
      };

      final horaInicio = excepcion['horaInicio']?.toString();
      final horaFin = excepcion['horaFin']?.toString();
      final horaTexto = (horaInicio != null &&
              horaInicio.isNotEmpty &&
              horaFin != null &&
              horaFin.isNotEmpty)
          ? ' $horaInicio–$horaFin'
          : ' (todo el día)';

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '⚠ Excepción el ${_fechaConDiaTexto(fecha)}: $tipo$horaTexto',
          style: TextStyle(color: Colors.amber.shade900),
        ),
      );
    }).toList();
  }

  String _fechaConDiaTexto(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    final etiquetaDia = _etiquetasDias[f.weekday - 1];
    return '$dia/$mes ($etiquetaDia)';
  }

  List<Widget> _lineasAgrupadas({
    required String etiqueta,
    required Color color,
    required List<ResumenDiaSemana> dias,
  }) {
    final grupos = <String, List<ResumenDiaSemana>>{};
    for (final dia in dias) {
      final clave =
          '${formatoHoraHHmm(dia.horaInicio!)}-${formatoHoraHHmm(dia.horaFin!)}';
      grupos.putIfAbsent(clave, () => []).add(dia);
    }

    return grupos.entries.map((entrada) {
      final horario = entrada.key.replaceAll('-', '–');
      final nombresDias = entrada.value.map(_etiquetaDia).join(', ');
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '$etiqueta: $nombresDias ($horario)',
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }).toList();
  }
}

// Resumen del horario base de todas las especialistas activas a la vez:
// filas = especialistas, columnas = Lun..Dom. Horizontal-scrollable
// porque 7 columnas + nombre no entran en un celular angosto.
class _VistaSemanal extends StatefulWidget {
  const _VistaSemanal();

  @override
  State<_VistaSemanal> createState() => _VistaSemanalState();
}

class _VistaSemanalState extends State<_VistaSemanal> {
  bool cargando = true;
  String? error;
  List<Map<String, dynamic>> especialistas = [];
  Map<String, Map<String, dynamic>> horariosBase = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final resultados = await Future.wait([
        EspecialistasService().obtenerEspecialistasActivos(),
        DisponibilidadService().cargarHorarioBaseDeTodas(),
      ]);

      if (!mounted) return;
      setState(() {
        especialistas = resultados[0] as List<Map<String, dynamic>>;
        horariosBase = resultados[1] as Map<String, Map<String, dynamic>>;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Error al cargar el horario: $e';
        cargando = false;
      });
    }
  }

  Widget _celdaDia(Map<String, dynamic>? horario, String clave) {
    final diaData = horario?[clave];

    if (diaData is! Map || diaData['activo'] != true) {
      return const Text('-', style: TextStyle(color: Colors.black26));
    }

    final inicio = diaData['horaInicio']?.toString() ?? '';
    final fin = diaData['horaFin']?.toString() ?? '';

    return Text(
      '$inicio\n$fin',
      style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
      textAlign: TextAlign.center,
    );
  }

  Widget _celdaDiaEnLinea(Map<String, dynamic>? horario, String clave) {
    final diaData = horario?[clave];

    if (diaData is! Map || diaData['activo'] != true) {
      return const Text('-', style: TextStyle(color: Colors.black26));
    }

    final inicio = diaData['horaInicio']?.toString() ?? '';
    final fin = diaData['horaFin']?.toString() ?? '';

    return Text(
      '$inicio - $fin',
      style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: sofinaColorPeligro),
          ),
        ),
      );
    }

    if (especialistas.isEmpty) {
      return const Center(child: Text('No hay especialistas activas.'));
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 600dp: mismo umbral que usa Material para el corte
          // compacto/mediano; por debajo, la tabla de 7 columnas ya no
          // entra sin cortarse.
          if (constraints.maxWidth < 600) {
            return _listaDeTarjetas(context);
          }
          return _tablaCompleta(context);
        },
      ),
    );
  }

  Widget _tablaCompleta(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Especialista')),
            for (final etiqueta in _etiquetasDias)
              DataColumn(label: Text(etiqueta)),
          ],
          rows: especialistas.map((especialista) {
            final authUid = especialista['authUid']?.toString() ?? '';
            final horario = horariosBase[authUid];

            return DataRow(
              cells: [
                DataCell(
                  Text((especialista['nombreCompleto'] ?? '').toString()),
                ),
                for (final clave in clavesDiasSemana)
                  DataCell(_celdaDia(horario, clave)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _listaDeTarjetas(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: especialistas.length,
      itemBuilder: (context, index) {
        final especialista = especialistas[index];
        final authUid = especialista['authUid']?.toString() ?? '';
        final horario = horariosBase[authUid];
        final sinConfigurar = _horarioSinConfigurar(horario);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ExpansionTile(
            // Sin initiallyExpanded: arrancan colapsadas por defecto.
            iconColor: Theme.of(context).colorScheme.primary,
            collapsedIconColor: Theme.of(context).colorScheme.primary,
            title: Text(
              (especialista['nombreCompleto'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              if (sinConfigurar)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Aún no configuró su horario',
                    style: TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                for (var i = 0; i < clavesDiasSemana.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            _etiquetasDias[i],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        _celdaDiaEnLinea(horario, clavesDiasSemana[i]),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}
