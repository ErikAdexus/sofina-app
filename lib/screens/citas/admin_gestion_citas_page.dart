import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/item_cita_guardado.dart';
import '../../theme/app_theme.dart';
import '../../utils/disponibilidad_calculo.dart';
import '../../utils/formatters.dart';
import '../../utils/location_helpers.dart';
import '../../utils/transiciones_cita.dart';
import '../../services/disponibilidad_service.dart';
import '../../services/especialistas_service.dart';
import '../../services/citas_service.dart';
import '../../services/pagos_service.dart';
import '../../widgets/buscador_estandar.dart';
import '../../widgets/detalle_cita_widgets.dart';
import '../../widgets/servicio_chip.dart';

// Salida/llegada de la especialista guardan su fecha como ISO
// (DateTime.toIso8601String) en fechaHora dentro del mapa, con respaldo
// en el campo plano fechaSalidaEspecialista/fechaLlegadaEspecialista --
// mismo patrón que ya usan citas_especialista_page.dart e
// historial_especialista_page.dart en su sección "Tu registro": parsear
// y formatear si se puede, si no mostrar el string crudo tal cual.
String _formatearFechaHoraIso(dynamic isoPrincipal, dynamic isoRespaldo) {
  final iso = (isoPrincipal ?? isoRespaldo ?? '').toString();
  final fecha = DateTime.tryParse(iso);
  return fecha != null ? formatearFechaHora(fecha) : iso;
}

class AdminGestionCitasPage extends StatefulWidget {
  final String? citaIdInicial;

  const AdminGestionCitasPage({super.key, this.citaIdInicial});

  @override
  State<AdminGestionCitasPage> createState() => _AdminGestionCitasPageState();
}

class _AdminGestionCitasPageState extends State<AdminGestionCitasPage> {
  // Cacheados: si se llamaran directo en build(), el setState() del
  // buscador dispararía un future/stream nuevo en cada tecla (spinner de
  // carga en cada interacción) -- mismo bug ya corregido antes en
  // Pagos/Historial.
  late final Future<List<Map<String, dynamic>>> _especialistasFuture =
      cargarEspecialistasActivos();
  late final Stream<DatabaseEvent> _citasStream = CitasService().streamCitas();
  String busqueda = '';
  bool _citaInicialAtendida = false;

  // colorEstadoCita/iconoEstadoCita ahora viven centralizadas en
  // widgets/detalle_cita_widgets.dart (antes estaban triplicadas de forma
  // idéntica en esta pantalla, citas_especialista_page.dart y
  // historial_especialista_page.dart).

  String formatoPrecioServicio(dynamic precio) {
    final valor = num.tryParse(precio?.toString() ?? '');

    if (valor == null || valor <= 0) {
      return '';
    }

    return 'S/ ${valor.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> convertirCitas(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final citas = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final data = Map<dynamic, dynamic>.from(value);

        citas.add({
          'id': key.toString(),
          'clienteId': data['clienteId']?.toString() ?? '',
          'clienteUid': data['clienteUid']?.toString() ?? '',
          'clienteNombre': data['clienteNombre']?.toString() ?? '',
          'clienteCelular': data['clienteCelular']?.toString() ?? '',
          'clienteCorreo': data['clienteCorreo']?.toString() ?? '',
          'especialistaId': data['especialistaId']?.toString() ?? '',
          'especialistaUid': data['especialistaUid']?.toString() ?? '',
          'especialistaNombre':
              data['especialistaNombre']?.toString() ?? 'Sin asignar',
          'especialistaCelular': data['especialistaCelular']?.toString() ?? '',
          'especialistaCorreo': data['especialistaCorreo']?.toString() ?? '',
          'especialistaEspecialidad':
              data['especialistaEspecialidad']?.toString() ?? '',
          'especialistaLatitud': data['especialistaLatitud'],
          'especialistaLongitud': data['especialistaLongitud'],
          'fechaUbicacionEspecialista':
              data['fechaUbicacionEspecialista']?.toString() ?? '',
          'salidaEspecialista': data['salidaEspecialista'] is Map
              ? Map<dynamic, dynamic>.from(data['salidaEspecialista'])
              : null,
          'llegadaEspecialista': data['llegadaEspecialista'] is Map
              ? Map<dynamic, dynamic>.from(data['llegadaEspecialista'])
              : null,
          'fechaSalidaEspecialista':
              data['fechaSalidaEspecialista']?.toString() ?? '',
          'fechaLlegadaEspecialista':
              data['fechaLlegadaEspecialista']?.toString() ?? '',
          'servicio': data['servicio']?.toString() ?? '',
          // Array por unidad (servicioId, nombre, precio, duracionMinutos,
          // retiroUnas, montoRetiro) que arma crearCita en Sofina Cliente
          // -- antes no se leía acá, así que el detalle de cita solo podía
          // mostrar el nombre/precio ya combinados de arriba, sin desglose
          // por servicio.
          'servicios': data['servicios'] is List ? data['servicios'] : const [],
          // Dirección real donde se hace ESTA cita, independiente de la
          // dirección de perfil del cliente (clienteDireccion): el salón
          // atiende a domicilio y puede ser en otro lugar.
          'direccionServicio': data['direccionServicio'] is Map
              ? Map<dynamic, dynamic>.from(data['direccionServicio'])
              : null,
          'precioServicio': data['precioServicio'] is num
              ? data['precioServicio']
              : num.tryParse(data['precioServicio']?.toString() ?? '') ?? 0,
          'observacion': data['observacion']?.toString() ?? '',
          'fechaCita': data['fechaCita']?.toString() ?? '',
          'horaCita': data['horaCita']?.toString() ?? '',
          'fechaHoraCita': data['fechaHoraCita']?.toString() ?? '',
          'fechaHoraCitaMillis': data['fechaHoraCitaMillis'] is int
              ? data['fechaHoraCitaMillis']
              : 0,
          'estado': data['estado']?.toString() ?? 'Pendiente',
          'fechaRegistro': data['fechaRegistro']?.toString() ?? '',
          'fechaRegistroMillis': data['fechaRegistroMillis'] is int
              ? data['fechaRegistroMillis']
              : 0,
        });
      }
    });

    citas.sort((a, b) {
      final fechaA = a['fechaHoraCitaMillis'] as int;
      final fechaB = b['fechaHoraCitaMillis'] as int;

      if (fechaA == 0 && fechaB == 0) {
        final registroA = a['fechaRegistroMillis'] as int;
        final registroB = b['fechaRegistroMillis'] as int;
        return registroB.compareTo(registroA);
      }

      if (fechaA == 0) return 1;
      if (fechaB == 0) return -1;

      return fechaA.compareTo(fechaB);
    });

    return citas;
  }

  List<Map<String, dynamic>> filtrarPorBusqueda(
    List<Map<String, dynamic>> citas,
  ) {
    final termino = busqueda.trim().toLowerCase();
    if (termino.isEmpty) return citas;

    return citas.where((data) {
      final texto =
          '${data['clienteNombre']} ${data['especialistaNombre']} ${data['servicio']}'
              .toLowerCase();
      return texto.contains(termino);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> cargarEspecialistasActivos() {
    return EspecialistasService().obtenerEspecialistasActivos();
  }

  void abrirDetalleCita(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final precioServicio = formatoPrecioServicio(data['precioServicio']);
        final lat = leerDouble(data['especialistaLatitud']);
        final lng = leerDouble(data['especialistaLongitud']);
        final tieneUbicacion = lat != null && lng != null;
        final estado = (data['estado'] ?? 'Pendiente').toString();

        final clienteNombre = (data['clienteNombre'] ?? '').toString();
        final clienteCelular = (data['clienteCelular'] ?? '').toString();
        final clienteCorreo = (data['clienteCorreo'] ?? '').toString();
        final fechaCita = (data['fechaCita'] ?? '').toString();
        final horaCita = formatearHoraCitaTexto(
          (data['horaCita'] ?? '').toString(),
        );

        final direccionServicio = data['direccionServicio'] as Map?;
        final distrito = direccionServicio?['distrito']?.toString() ?? '';
        final direccionExacta =
            direccionServicio?['direccionExacta']?.toString() ?? '';

        // Desglose por servicio (con retiro incluido si aplica); si la
        // cita no trajera servicios[] estructurado, cae a un único chip
        // con el nombre/precio ya combinados -- mismo respaldo que usa
        // Sofina Cliente en DetalleCitaDialog.
        final items = parseServiciosDeCita(data['servicios']);
        final chips = items.isNotEmpty
            ? items
                .map(
                  (item) => ServicioChip(
                    nombre: item.nombre,
                    precio: item.subtotal,
                    retiroUnas: item.retiroUnas,
                    servicioId: item.servicioId,
                  ),
                )
                .toList()
            : [
                ServicioChip(
                  nombre: (data['servicio'] ?? '').toString(),
                  precio: (data['precioServicio'] as num?)?.toDouble() ?? 0,
                ),
              ];

        final colorTextoSecundario =
            Theme.of(context).extension<SofinaColors>()!.primaryDark;

        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalle de cita',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClienteAvatar(nombre: clienteNombre, radio: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clienteNombre.isEmpty
                                        ? 'Cliente sin nombre'
                                        : clienteNombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (clienteCelular.isNotEmpty)
                                    Text(
                                      clienteCelular,
                                      style: TextStyle(
                                        color: colorTextoSecundario,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (fechaCita.isNotEmpty || horaCita.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    fechaCita,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    horaCita,
                                    style: TextStyle(
                                      color: colorTextoSecundario,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'SERVICIOS',
                              style: TextStyle(
                                color: colorTextoSecundario,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            BadgeContadorServicios(cantidad: chips.length),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...chips,
                        if (precioServicio.isNotEmpty) ...[
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                precioServicio,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        SeccionInfoCita(
                          icono: Icons.location_on,
                          titulo: 'Dirección del servicio',
                          child: Text(
                            distrito.isEmpty && direccionExacta.isEmpty
                                ? 'Sin dirección registrada'
                                : '$distrito\n$direccionExacta',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SeccionInfoCita(
                          icono: Icons.contact_phone,
                          titulo: 'Contacto del cliente',
                          child: Text(
                            'Celular: ${clienteCelular.isEmpty ? 'Sin celular' : clienteCelular}\n'
                            'Correo: ${clienteCorreo.isEmpty ? 'Sin correo' : clienteCorreo}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SeccionInfoCita(
                          icono: Icons.note_alt_outlined,
                          titulo: 'Observación del cliente',
                          child: Text(
                            (data['observacion'] ?? '').toString().isEmpty
                                ? 'Sin observación'
                                : data['observacion'].toString(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SeccionInfoCita(
                          icono: Icons.badge_outlined,
                          titulo: 'Especialista asignado',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (data['especialistaNombre'] ?? 'Sin asignar')
                                    .toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              if ((data['especialistaCelular'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text('Celular: ${data['especialistaCelular']}'),
                              if ((data['especialistaEspecialidad'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  'Especialidad: ${data['especialistaEspecialidad']}',
                                ),
                              if (data['salidaEspecialista'] is Map) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => abrirMapaEspecialista(
                                    context,
                                    (data['salidaEspecialista']
                                        as Map)['latitud'],
                                    (data['salidaEspecialista']
                                        as Map)['longitud'],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Salida de la especialista:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${(data['salidaEspecialista'] as Map)['latitud']}, ${(data['salidaEspecialista'] as Map)['longitud']}',
                                            ),
                                            Text(
                                              'Hora salida: ${_formatearFechaHoraIso((data['salidaEspecialista'] as Map)['fechaHora'], data['fechaSalidaEspecialista'])}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.map,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (data['llegadaEspecialista'] is Map) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => abrirMapaEspecialista(
                                    context,
                                    (data['llegadaEspecialista']
                                        as Map)['latitud'],
                                    (data['llegadaEspecialista']
                                        as Map)['longitud'],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Llegada al cliente:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${(data['llegadaEspecialista'] as Map)['latitud']}, ${(data['llegadaEspecialista'] as Map)['longitud']}',
                                            ),
                                            Text(
                                              'Hora llegada: ${_formatearFechaHoraIso((data['llegadaEspecialista'] as Map)['fechaHora'], data['fechaLlegadaEspecialista'])}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.map,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        BadgeEstadoCita(
                          estado: estado,
                          color: colorEstadoCita(estado),
                          icono: iconoEstadoCita(estado),
                        ),
                        if (tieneUbicacion) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                abrirMapaEspecialista(
                                  context,
                                  data['especialistaLatitud'],
                                  data['especialistaLongitud'],
                                );
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Ver mapa'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _intentarAbrirCitaInicial(List<Map<String, dynamic>> citas) {
    final citaId = widget.citaIdInicial;
    if (citaId == null || citaId.isEmpty || _citaInicialAtendida) return;

    _citaInicialAtendida = true;
    final data = _buscarCitaPorId(citas, citaId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (data != null) {
        abrirDetalleCita(context, data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esa cita ya no está disponible.')),
        );
      }
    });
  }

  void abrirEditarEstadoCita(
    BuildContext context,
    String idCita,
    Map<String, dynamic> data,
  ) {
    final estadoActual = (data['estado'] ?? 'Pendiente').toString();
    String estadoSeleccionado = estadoActual;

    final observacionController = TextEditingController(
      text: data['observacion'] ?? '',
    );

    // Solo los estados a los que realmente se puede pasar desde el
    // actual (ver utils/transiciones_cita.dart); si el actual es final
    // (Atendida/Cancelada), esta lista queda con un único elemento (el
    // mismo) y el dropdown se reemplaza por texto de solo lectura.
    const todosLosEstados = [
      'Pendiente',
      'Confirmada',
      'En camino',
      'En sitio',
      'Atendida',
      'Cancelada',
    ];
    final estadosDisponibles = todosLosEstados
        .where((estado) => puedeCambiarEstado(estadoActual, estado))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar estado'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cliente: ${data['clienteNombre'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Especialista: ${data['especialistaNombre'] ?? 'Sin asignar'}',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fecha: ${data['fechaCita'] ?? ''} - '
                        '${formatearHoraCitaTexto((data['horaCita'] ?? '').toString())}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (estadosDisponibles.length <= 1)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado de la cita',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$estadoActual (estado final, no se puede cambiar)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: estadoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Estado de la cita',
                          border: OutlineInputBorder(),
                        ),
                        items: estadosDisponibles
                            .map(
                              (estado) => DropdownMenuItem(
                                value: estado,
                                child: Text(estado),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            estadoSeleccionado = value!;
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: observacionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observación',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!puedeCambiarEstado(
                      estadoActual,
                      estadoSeleccionado,
                    )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Esa transición de estado ya no es válida.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Mismo criterio que "Finalizar atención" del lado
                    // especialista (citas_especialista_page.dart): no
                    // dejar pasar a Atendida sin un pago registrado. Acá
                    // no se navega a CobrarServicioPage -- esa pantalla
                    // está redactada para quien recibe el efectivo ("tú,
                    // la especialista"), no tiene sentido abrirla desde
                    // la cuenta del admin.
                    if (estadoSeleccionado == 'Atendida') {
                      final tienePago =
                          await PagosService().existePago(idCita);

                      if (!context.mounted) return;

                      if (!tienePago) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Esta cita no tiene un pago registrado. '
                              'Pídele a la especialista que lo registre en '
                              '"Cobrar servicio" antes de marcarla como Atendida.',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    try {
                      await CitasService().actualizarEstadoCita(
                        idCita: idCita,
                        estado: estadoSeleccionado,
                        observacion: observacionController.text.trim(),
                      );

                      if (!context.mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Estado actualizado correctamente'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar estado: $e'),
                        ),
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

  Future<void> abrirAsignarEspecialista(
    BuildContext context,
    Map<String, dynamic> cita,
    List<Map<String, dynamic>> especialistas,
    List<Map<String, dynamic>> citas,
  ) async {
    final idsAgregados = <String>{};
    final especialistasValidas = <Map<String, dynamic>>[];

    for (final item in especialistas) {
      final id = item['id']?.toString().trim() ?? '';

      if (id.isEmpty) {
        continue;
      }

      if (idsAgregados.contains(id)) {
        continue;
      }

      idsAgregados.add(id);
      // Copia, no la referencia: acá abajo se le agregan campos
      // (citasEsteDia/horasLibresEsteDia) puntuales de ESTA cita -- si se
      // reutilizara la misma instancia que vive en el cache de
      // `especialistas` de la página, esos campos calculados para una
      // cita/fecha podrían filtrarse a otra apertura del diálogo.
      especialistasValidas.add(Map<String, dynamic>.from(item));
    }

    // Filtro obligatorio de disponibilidad: se excluyen las especialistas
    // con un bloqueo explícito (día inactivo en horarioBase, fuera de
    // rango horario, o excepción tipo bloqueo) para la fecha/hora exacta
    // de esta cita. Las que nunca configuraron disponibilidad
    // (EstadoDisponibilidad.sinConfigurar) NO se excluyen -- solo se
    // filtra lo explícitamente bloqueado, nunca la ausencia de datos.
    //
    // Se usan los métodos bulk de DisponibilidadService (mismo patrón que
    // la pantalla de franja horaria) en vez de una consulta por
    // especialista: 2 lecturas totales sin importar cuántas activas haya,
    // y calcularDisponibilidad() corre localmente sobre esos datos.
    //
    // Si la cita no tiene fechaHoraCitaMillis (citas viejas sin ese
    // campo), no hay fecha/hora que evaluar -- se muestran todas sin
    // filtrar, igual que el comportamiento anterior a este cambio.
    final fechaHoraMillis = cita['fechaHoraCitaMillis'] is int
        ? cita['fechaHoraCitaMillis'] as int
        : 0;
    final fechaCitaTexto = (cita['fechaCita'] ?? '').toString();

    DateTime? fechaHoraCita;
    Map<String, Map<String, dynamic>> horarioBaseDeTodas = {};
    List<Map<String, dynamic>> excepcionesDeFecha = [];

    if (fechaHoraMillis > 0 && especialistasValidas.isNotEmpty) {
      fechaHoraCita = DateTime.fromMillisecondsSinceEpoch(fechaHoraMillis);
      final horaCita = TimeOfDay(
        hour: fechaHoraCita.hour,
        minute: fechaHoraCita.minute,
      );

      // Loading transitorio: sin esto, el tap en "Asignar especialista"
      // se sentiría muerto durante las lecturas bulk hasta que abra el
      // diálogo real.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final anio = fechaHoraCita.year.toString().padLeft(4, '0');
      final mes = fechaHoraCita.month.toString().padLeft(2, '0');
      final dia = fechaHoraCita.day.toString().padLeft(2, '0');
      final fechaTexto = '$anio-$mes-$dia';

      final resultados = await Future.wait([
        DisponibilidadService().cargarHorarioBaseDeTodas(),
        DisponibilidadService().cargarExcepcionesDeFecha(fechaTexto),
      ]);

      if (!context.mounted) return;
      Navigator.pop(context); // cierra el loading transitorio

      horarioBaseDeTodas = resultados[0] as Map<String, Map<String, dynamic>>;
      excepcionesDeFecha = resultados[1] as List<Map<String, dynamic>>;

      especialistasValidas.removeWhere((especialista) {
        final authUid = especialista['authUid']?.toString() ?? '';

        // Sin authUid no se puede evaluar disponibilidad -- no se
        // excluye (fail-open, no fail-closed).
        if (authUid.isEmpty) return false;

        final horarioBase = horarioBaseDeTodas[authUid];
        final excepcionesDeEsta = excepcionesDeFecha
            .where((e) => e['especialistaId']?.toString() == authUid)
            .toList();

        final estado = calcularDisponibilidad(
          horarioBase: horarioBase,
          excepciones: excepcionesDeEsta,
          fecha: fechaHoraCita!,
          hora: horaCita,
        );

        return estado == EstadoDisponibilidad.noDisponible;
      });
    }

    // Enriquece cada especialista restante con carga de trabajo (DATO 2)
    // y horas libres (DATO 3) ese día -- ninguno agrega lecturas nuevas a
    // RTDB: `citas` ya está cargada en memoria por el StreamBuilder de la
    // página, y horarioBaseDeTodas/excepcionesDeFecha son las mismas que
    // acaba de usar el filtro obligatorio de arriba.
    for (final especialista in especialistasValidas) {
      final idEspecialista = especialista['id']?.toString() ?? '';
      final authUid = especialista['authUid']?.toString() ?? '';

      final citasEseDia = citas.where((c) {
        if (c['especialistaId']?.toString() != idEspecialista) return false;
        if ((c['estado'] ?? '').toString() == 'Cancelada') return false;

        final cMillis = c['fechaHoraCitaMillis'] is int
            ? c['fechaHoraCitaMillis'] as int
            : 0;

        if (fechaHoraCita != null && cMillis > 0) {
          final cFecha = DateTime.fromMillisecondsSinceEpoch(cMillis);
          return cFecha.year == fechaHoraCita.year &&
              cFecha.month == fechaHoraCita.month &&
              cFecha.day == fechaHoraCita.day;
        }

        // Sin millis (cita vieja): se compara por el texto de fecha ya
        // formateado, mismo respaldo que usa el resto de la app.
        return fechaCitaTexto.isNotEmpty &&
            (c['fechaCita'] ?? '').toString() == fechaCitaTexto;
      }).toList();

      especialista['citasEsteDia'] = citasEseDia.length;

      if (fechaHoraCita != null && authUid.isNotEmpty) {
        final excepcionesDeEsta = excepcionesDeFecha
            .where((e) => e['especialistaId']?.toString() == authUid)
            .toList();

        final ventanaMin = calcularVentanaLibreMinutos(
          horarioBase: horarioBaseDeTodas[authUid],
          excepciones: excepcionesDeEsta,
          fecha: fechaHoraCita,
        );

        if (ventanaMin != null) {
          final minutosOcupados = citasEseDia.fold<int>(0, (suma, c) {
            final items = parseServiciosDeCita(c['servicios']);
            final duracion = items.isNotEmpty
                ? items.fold<int>(0, (s, i) => s + i.duracionMinutos)
                : 60; // respaldo: cita sin servicios[] estructurado
            return suma + duracion;
          });

          final minutosLibres =
              (ventanaMin - minutosOcupados).clamp(0, ventanaMin);
          especialista['horasLibresEsteDia'] = minutosLibres / 60.0;
        }
      }
    }

    // Sugerencia por distrito (no bloqueante, solo orden + indicador
    // visual): ahora que el distrito de la especialista es de elección
    // libre entre los 43 de Lima (ya no limitado a los 4 de cobertura),
    // vuelve a ser una señal real de proximidad. Las del mismo distrito
    // que la cita van primero; el resto (distrito distinto O sin
    // definir) queda después -- partición estable, conserva el orden
    // relativo original dentro de cada grupo. Nunca excluye a nadie, a
    // diferencia del filtro de disponibilidad de arriba.
    final distritoCita =
        (cita['direccionServicio'] as Map?)?['distrito']?.toString();

    if (distritoCita != null && distritoCita.isNotEmpty) {
      final mismoDistrito = especialistasValidas
          .where((item) => item['distrito']?.toString() == distritoCita)
          .toList();
      final resto = especialistasValidas
          .where((item) => item['distrito']?.toString() != distritoCita)
          .toList();

      especialistasValidas
        ..clear()
        ..addAll(mismoDistrito)
        ..addAll(resto);
    }

    String? especialistaSeleccionada =
        cita['especialistaId']?.toString().trim();

    if (especialistaSeleccionada == null || especialistaSeleccionada.isEmpty) {
      especialistaSeleccionada = null;
    } else {
      final cantidadCoincidencias = especialistasValidas
          .where((item) =>
              item['id']?.toString().trim() == especialistaSeleccionada)
          .length;

      if (cantidadCoincidencias != 1) {
        especialistaSeleccionada = null;
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Asignar especialista',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SeccionInfoCita(
                        icono: Icons.event_note,
                        titulo: 'Cita a asignar',
                        child: Text(
                          '${cita['clienteNombre'] ?? ''}\n'
                          '${cita['fechaCita'] ?? ''} - '
                          '${formatearHoraCitaTexto((cita['horaCita'] ?? '').toString())}\n'
                          '${cita['servicio'] ?? ''}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SELECCIONAR ESPECIALISTA',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (especialistasValidas.isEmpty)
                        const Text(
                          'No hay especialistas activas disponibles para asignar.',
                          style: TextStyle(color: sofinaColorPeligro),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: SingleChildScrollView(
                            child: Column(
                              children:
                                  especialistasValidas.map((especialista) {
                                final id =
                                    especialista['id']?.toString().trim() ?? '';
                                final coincideDistrito = distritoCita != null &&
                                    distritoCita.isNotEmpty &&
                                    especialista['distrito']?.toString() ==
                                        distritoCita;
                                final calificacionTotal =
                                    especialista['calificacionTotal'] as int? ??
                                        0;

                                return _CardEspecialistaSeleccionable(
                                  especialistaId: id,
                                  nombre: especialista['nombreCompleto']
                                          ?.toString() ??
                                      '',
                                  especialidad: especialista['especialidad']
                                          ?.toString() ??
                                      '',
                                  seleccionada: especialistaSeleccionada == id,
                                  coincideDistrito: coincideDistrito,
                                  distrito:
                                      especialista['distrito']?.toString(),
                                  calificacionPromedio: calificacionTotal > 0
                                      ? especialista['calificacionPromedio']
                                          as double?
                                      : null,
                                  calificacionTotal: calificacionTotal,
                                  citasEsteDia:
                                      especialista['citasEsteDia'] as int? ?? 0,
                                  horasLibres:
                                      especialista['horasLibresEsteDia']
                                          as double?,
                                  experiencia:
                                      especialista['experiencia']?.toString(),
                                  onTap: () {
                                    setStateDialog(() {
                                      especialistaSeleccionada = id;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Al asignar una especialista, la cita pasará a Confirmada.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: especialistasValidas.isEmpty
                                ? null
                                : () async {
                                    if (especialistaSeleccionada == null ||
                                        especialistaSeleccionada!.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Seleccione una especialista'),
                                        ),
                                      );
                                      return;
                                    }

                                    final especialista =
                                        especialistasValidas.firstWhere(
                                      (item) =>
                                          item['id']?.toString().trim() ==
                                          especialistaSeleccionada,
                                    );

                                    // Warning no-bloqueante (Prioridad 6): si la
                                    // especialista SÍ tiene horarioBase configurado
                                    // pero este horario cae fuera (o hay un
                                    // bloqueo puntual), se le avisa al admin antes
                                    // de confirmar -- nunca se impide la
                                    // asignación, es su criterio. Si nunca
                                    // configuró disponibilidad, no se opina nada
                                    // (mismo comportamiento que había antes).
                                    final authUid =
                                        especialista['authUid']?.toString() ??
                                            '';
                                    final fechaHoraMillis =
                                        cita['fechaHoraCitaMillis'] is int
                                            ? cita['fechaHoraCitaMillis'] as int
                                            : 0;

                                    if (authUid.isNotEmpty &&
                                        fechaHoraMillis > 0) {
                                      final fechaHoraCita =
                                          DateTime.fromMillisecondsSinceEpoch(
                                        fechaHoraMillis,
                                      );

                                      final estado =
                                          await DisponibilidadService()
                                              .consultarDisponibilidadPuntual(
                                        authUid: authUid,
                                        fecha: fechaHoraCita,
                                        hora: TimeOfDay(
                                          hour: fechaHoraCita.hour,
                                          minute: fechaHoraCita.minute,
                                        ),
                                      );

                                      if (estado ==
                                          EstadoDisponibilidad.noDisponible) {
                                        if (!context.mounted) return;

                                        final continuar =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Sin disponibilidad configurada',
                                            ),
                                            content: const Text(
                                              'Este especialista no tiene '
                                              'disponibilidad configurada para este '
                                              'horario. ¿Deseas asignarlo de todas '
                                              'formas?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child:
                                                    const Text('Asignar igual'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (continuar != true) return;
                                      }
                                    }

                                    if (!context.mounted) return;

                                    if (!puedeCambiarEstado(
                                      (cita['estado'] ?? 'Pendiente')
                                          .toString(),
                                      'Confirmada',
                                    )) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Esta cita ya no admite asignar/reasignar especialista en su estado actual.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      await CitasService().asignarEspecialista(
                                        idCita: cita['id'] ?? '',
                                        especialista: especialista,
                                      );

                                      if (!context.mounted) return;

                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Especialista asignada correctamente',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error al asignar especialista: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Asignar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> confirmarEliminarCita(
    BuildContext context,
    String idCita,
    String clienteNombre,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cita'),
          content: Text(
            '¿Deseas eliminar la cita de $clienteNombre?',
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
      await CitasService().eliminarCita(idCita);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita eliminada correctamente'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar cita: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          BuscadorEstandar(
            hintText: 'Buscar por cliente, especialista o servicio...',
            onChanged: (texto) {
              setState(() {
                busqueda = texto;
              });
            },
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _especialistasFuture,
              builder: (context, especialistasSnapshot) {
                if (especialistasSnapshot.hasError) {
                  return const Center(
                    child: Text('Error al cargar especialistas activos'),
                  );
                }

                if (especialistasSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final especialistas = especialistasSnapshot.data ?? [];

                return StreamBuilder<DatabaseEvent>(
                  stream: _citasStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error al cargar citas'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final todasLasCitas = convertirCitas(
                      snapshot.data?.snapshot.value,
                    );

                    _intentarAbrirCitaInicial(todasLasCitas);

                    if (todasLasCitas.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay citas registradas',
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }

                    final citas = filtrarPorBusqueda(todasLasCitas);

                    if (citas.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Ninguna cita coincide con tu búsqueda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: citas.length,
                      itemBuilder: (context, index) {
                        final data = citas[index];

                        final idCita = data['id'] ?? '';
                        final clienteNombre =
                            data['clienteNombre'] ?? 'Sin cliente';
                        final especialistaNombre =
                            data['especialistaNombre'] ?? 'Sin asignar';
                        final servicio = data['servicio'] ?? '';
                        final precioServicio =
                            formatoPrecioServicio(data['precioServicio']);
                        final fechaCita = data['fechaCita'] ?? '';
                        final horaCita = data['horaCita'] ?? '';
                        final estado = data['estado'] ?? 'Pendiente';
                        final tieneEspecialista =
                            (data['especialistaUid'] ?? '')
                                    .toString()
                                    .isNotEmpty ||
                                (data['especialistaId'] ?? '')
                                    .toString()
                                    .isNotEmpty;
                        final serviciosCita =
                            parseServiciosDeCita(data['servicios']);
                        final serviciosIds = serviciosCita
                            .map((item) => item.servicioId)
                            .toList();

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => abrirDetalleCita(context, data),
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              leading: AvatarCitaConEstado(
                                serviciosIds: serviciosIds,
                                colorEstado: colorEstadoCita(estado),
                              ),
                              title: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '$fechaCita - ${formatearHoraCitaCompacta(horaCita)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Cliente: $clienteNombre\n'
                                    'Especialista: $especialistaNombre\n'
                                    'Servicio: $servicio${precioServicio.isNotEmpty ? ' - $precioServicio' : ''}',
                                  ),
                                  const SizedBox(height: 4),
                                  PildoraEstadoCita(estado: estado),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Ver mapa de especialista',
                                    icon: const Icon(Icons.map),
                                    onPressed: () {
                                      abrirMapaEspecialista(
                                        context,
                                        data['especialistaLatitud'],
                                        data['especialistaLongitud'],
                                      );
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (opcion) {
                                      if (opcion == 'ver') {
                                        abrirDetalleCita(context, data);
                                      }

                                      if (opcion == 'asignar') {
                                        abrirAsignarEspecialista(
                                          context,
                                          data,
                                          especialistas,
                                          citas,
                                        );
                                      }

                                      if (opcion == 'estado') {
                                        abrirEditarEstadoCita(
                                            context, idCita, data);
                                      }

                                      if (opcion == 'mapa') {
                                        abrirMapaEspecialista(
                                          context,
                                          data['especialistaLatitud'],
                                          data['especialistaLongitud'],
                                        );
                                      }

                                      if (opcion == 'eliminar') {
                                        confirmarEliminarCita(
                                          context,
                                          idCita,
                                          clienteNombre,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) {
                                      return [
                                        const PopupMenuItem(
                                          value: 'ver',
                                          child: Text('Ver detalle'),
                                        ),
                                        PopupMenuItem(
                                          value: 'asignar',
                                          child: Text(
                                            tieneEspecialista
                                                ? 'Reasignar especialista'
                                                : 'Asignar especialista',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'estado',
                                          child: Text('Editar estado'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'mapa',
                                          child: Text('Ver mapa'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'eliminar',
                                          child: Text('Eliminar'),
                                        ),
                                      ];
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Card seleccionable de una especialista dentro de "Asignar especialista"
// (reemplaza el DropdownButtonFormField que había antes). Los 4 datos
// secundarios son siempre informativos/sugerencia -- ninguno filtra la
// lista, eso ya lo hizo el filtro obligatorio de disponibilidad antes de
// llegar acá.
class _CardEspecialistaSeleccionable extends StatelessWidget {
  final String especialistaId;
  final String nombre;
  final String especialidad;
  final bool seleccionada;
  final bool coincideDistrito;
  final String? distrito;
  // null = sin calificaciones todavía (total == 0) -- se omite el badge,
  // no se muestra "0.0" ni "Sin calificar".
  final double? calificacionPromedio;
  final int calificacionTotal;
  final int citasEsteDia;
  // null = sin datos de disponibilidad configurados ese día
  // (EstadoDisponibilidad.sinConfigurar) -- se omite el badge, mostrar
  // "0h" ahí sería engañoso (no significa que esté ocupada todo el día).
  final double? horasLibres;
  final String? experiencia;
  final VoidCallback onTap;

  const _CardEspecialistaSeleccionable({
    required this.especialistaId,
    required this.nombre,
    required this.especialidad,
    required this.seleccionada,
    required this.coincideDistrito,
    required this.distrito,
    required this.calificacionPromedio,
    required this.calificacionTotal,
    required this.citasEsteDia,
    required this.horasLibres,
    required this.experiencia,
    required this.onTap,
  });

  String get _textoHorasLibres {
    final horas = horasLibres!;
    final redondeado = horas.roundToDouble();
    final texto = horas == redondeado
        ? redondeado.toStringAsFixed(0)
        : horas.toStringAsFixed(1);
    return '${texto}h libres';
  }

  Widget _badgePill(IconData icono, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: seleccionada ? primario.withValues(alpha: 0.06) : null,
            border: Border.all(
              color: seleccionada ? primario : Colors.grey.shade300,
              width: seleccionada ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                seleccionada
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: seleccionada ? primario : Colors.grey,
              ),
              const SizedBox(width: 8),
              EspecialistaAvatar(
                especialistaId: especialistaId,
                nombre: nombre,
                radio: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (especialidad.isNotEmpty)
                      Text(
                        especialidad,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        calificacionPromedio != null
                            ? _badgePill(
                                Icons.star,
                                '${calificacionPromedio!.toStringAsFixed(1)} ($calificacionTotal)',
                                const Color(0xFFF9A825),
                              )
                            : _badgePill(
                                Icons.star_border,
                                'Sin reseñas aún',
                                Colors.grey,
                              ),
                        if (distrito == null || distrito!.isEmpty)
                          _badgePill(
                            Icons.location_on,
                            'Distrito no configurado',
                            Colors.grey,
                          )
                        else if (coincideDistrito)
                          _badgePill(
                            Icons.location_on,
                            'Mismo distrito',
                            const Color(0xFF2E7D32),
                          )
                        else
                          _badgePill(Icons.location_on, distrito!, Colors.grey),
                        _badgePill(
                          Icons.event_note,
                          citasEsteDia == 1
                              ? '1 cita hoy'
                              : '$citasEsteDia citas hoy',
                          const Color(0xFF1565C0),
                        ),
                        horasLibres != null
                            ? _badgePill(
                                Icons.schedule,
                                _textoHorasLibres,
                                const Color(0xFF00897B),
                              )
                            : _badgePill(
                                Icons.schedule,
                                'Horario no configurado',
                                Colors.grey,
                              ),
                        (experiencia == null || experiencia!.isEmpty)
                            ? _badgePill(
                                Icons.work,
                                'Experiencia no registrada',
                                Colors.grey,
                              )
                            : _badgePill(
                                Icons.work,
                                experiencia!,
                                const Color(0xFF5E35B1),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _buscarCitaPorId(
  List<Map<String, dynamic>> citas,
  String citaId,
) {
  for (final cita in citas) {
    if (cita['id'] == citaId) return cita;
  }
  return null;
}
