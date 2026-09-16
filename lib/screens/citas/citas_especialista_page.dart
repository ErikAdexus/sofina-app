import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/item_cita_guardado.dart';
import '../../services/auth_service.dart';
import '../../services/citas_service.dart';
import '../../services/pagos_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/location_helpers.dart';
import '../../utils/transiciones_cita.dart';
import '../../widgets/buscador_estandar.dart';
import '../../widgets/detalle_cita_widgets.dart';
import '../../widgets/servicio_chip.dart';
import 'cobrar_servicio_page.dart';

// Estados accionables: lo que el especialista todavía tiene que atender.
// Atendida/Cancelada son estados terminales y viven en HistorialEspecialistaPage.
const estadosAccionablesEspecialista = {
  'Pendiente',
  'Confirmada',
  'En camino',
  'En sitio',
};

class CitasEspecialistaPage extends StatefulWidget {
  final String? citaIdInicial;

  const CitasEspecialistaPage({super.key, this.citaIdInicial});

  @override
  State<CitasEspecialistaPage> createState() => _CitasEspecialistaPageState();
}

class _CitasEspecialistaPageState extends State<CitasEspecialistaPage> {
  // Cacheado: si se llamara directo en build(), el setState() del
  // buscador le pasaría a StreamBuilder una instancia nueva de stream en
  // cada tecla y lo forzaría a desuscribirse/resuscribirse, mostrando el
  // spinner de carga en cada interacción (mismo bug ya corregido antes
  // en Pagos/Historial).
  late final Stream<DatabaseEvent> _citasStream = CitasService()
      .streamCitasDeEspecialista(AuthService().currentUser?.uid ?? '');
  String busqueda = '';
  bool _citaInicialAtendida = false;

  // colorEstadoCita/iconoEstadoCita ahora viven centralizadas en
  // widgets/detalle_cita_widgets.dart (antes estaban triplicadas de forma
  // idéntica en esta pantalla, admin_gestion_citas_page.dart y
  // historial_especialista_page.dart).

  String formatoPrecioServicio(dynamic precio) {
    final valor = num.tryParse(precio?.toString() ?? '');

    if (valor == null || valor <= 0) {
      return '';
    }

    return 'S/ ${valor.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> convertirMisCitasAsignadas(dynamic value) {
    final user = AuthService().currentUser;

    if (user == null || value == null || value is! Map) {
      return [];
    }

    final uidActual = user.uid;
    final correoActual = user.email ?? '';

    final mapa = Map<dynamic, dynamic>.from(value);
    final citas = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final data = Map<dynamic, dynamic>.from(value);

        final especialistaUid = data['especialistaUid']?.toString() ?? '';
        final especialistaCorreo = data['especialistaCorreo']?.toString() ?? '';

        final esMiCita = especialistaUid == uidActual ||
            (correoActual.isNotEmpty && especialistaCorreo == correoActual);
        final estado = data['estado']?.toString() ?? 'Pendiente';

        if (esMiCita && estadosAccionablesEspecialista.contains(estado)) {
          citas.add({
            'id': key.toString(),
            'clienteId': data['clienteId']?.toString() ?? '',
            'clienteUid': data['clienteUid']?.toString() ?? '',
            'clienteNombre': data['clienteNombre']?.toString() ?? '',
            'clienteCelular': data['clienteCelular']?.toString() ?? '',
            'clienteCorreo': data['clienteCorreo']?.toString() ?? '',
            'especialistaId': data['especialistaId']?.toString() ?? '',
            'especialistaUid': especialistaUid,
            'especialistaNombre': data['especialistaNombre']?.toString() ?? '',
            'especialistaCelular':
                data['especialistaCelular']?.toString() ?? '',
            'especialistaCorreo': especialistaCorreo,
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
            'servicios':
                data['servicios'] is List ? data['servicios'] : const [],
            // Dirección real donde se hace ESTA cita, independiente de la
            // dirección de perfil del cliente (clienteDireccion).
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
          '${data['clienteNombre']} ${data['servicio']}'.toLowerCase();
      return texto.contains(termino);
    }).toList();
  }

  void abrirDetalleCita(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final precioServicio = formatoPrecioServicio(data['precioServicio']);
        final estado = (data['estado'] ?? 'Pendiente').toString();

        final clienteNombre = (data['clienteNombre'] ?? '').toString();
        final clienteCelular = (data['clienteCelular'] ?? '').toString();
        final clienteCorreo = (data['clienteCorreo'] ?? '').toString();

        // "Lun 31 ago" / "9:41 pm" a partir de fechaHoraCitaMillis; si la
        // cita no lo trajera (dato viejo), cae a los strings crudos que
        // ya vienen listos de RTDB.
        final fechaHoraCitaMillis = data['fechaHoraCitaMillis'] is int
            ? data['fechaHoraCitaMillis'] as int
            : 0;
        final fechaCitaDateTime = fechaHoraCitaMillis > 0
            ? DateTime.fromMillisecondsSinceEpoch(fechaHoraCitaMillis)
            : null;
        final fechaCita = fechaCitaDateTime != null
            ? formatearFechaCorta(fechaCitaDateTime)
            : (data['fechaCita'] ?? '').toString();
        final horaCita = fechaCitaDateTime != null
            ? formatearHora12h(fechaCitaDateTime)
            : (data['horaCita'] ?? '').toString();

        final direccionServicio = data['direccionServicio'] as Map?;
        final distrito = direccionServicio?['distrito']?.toString() ?? '';
        final direccionExacta =
            direccionServicio?['direccionExacta']?.toString() ?? '';

        // Desglose por servicio (con retiro incluido si aplica); si la
        // cita no trajera servicios[] estructurado, cae a un único chip
        // con el nombre/precio ya combinados -- mismo respaldo que usa
        // Sofina Cliente y admin_gestion_citas_page.dart.
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

        final salidaMap = data['salidaEspecialista'] is Map
            ? data['salidaEspecialista'] as Map
            : null;
        final llegadaMap = data['llegadaEspecialista'] is Map
            ? data['llegadaEspecialista'] as Map
            : null;
        final tieneRegistro = salidaMap != null || llegadaMap != null;

        final salidaFecha = salidaMap != null
            ? DateTime.tryParse(salidaMap['fechaHora']?.toString() ?? '')
            : null;
        final llegadaFecha = llegadaMap != null
            ? DateTime.tryParse(llegadaMap['fechaHora']?.toString() ?? '')
            : null;

        final tiempoTraslado =
            calcularTiempoTraslado(salidaFecha, llegadaFecha);

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
                        'Detalle de cita asignada',
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
                        if (tieneRegistro) ...[
                          const SizedBox(height: 12),
                          SeccionInfoCita(
                            icono: Icons.directions_run,
                            titulo: 'Tu registro',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (salidaFecha != null)
                                  FilaRegistroConPunto(
                                    color: const Color(0xFF854F0B),
                                    texto:
                                        'Salida: ${formatearFechaHora(salidaFecha)}',
                                  )
                                else if (salidaMap != null)
                                  Text(
                                      'Salida: ${salidaMap['fechaHora'] ?? ''}'),
                                if (llegadaFecha != null)
                                  FilaRegistroConPunto(
                                    color: const Color(0xFF27500A),
                                    texto:
                                        'Llegada: ${formatearFechaHora(llegadaFecha)}',
                                  )
                                else if (llegadaMap != null)
                                  Text(
                                      'Llegada: ${llegadaMap['fechaHora'] ?? ''}'),
                                if (tiempoTraslado != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tiempo de traslado: ${tiempoTraslado.inMinutes} min',
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        BadgeEstadoCita(
                          estado: estado,
                          color: colorEstadoCita(estado),
                          icono: iconoEstadoCita(estado),
                        ),
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

  Future<void> cambiarEstado(
    BuildContext context,
    String idCita,
    String nuevoEstado, {
    bool registrarUbicacion = false,
    String tipoUbicacion = '',
  }) async {
    try {
      Position? posicion;

      if (registrarUbicacion) {
        posicion = await obtenerUbicacionActual(context);

        if (posicion == null) {
          return;
        }
      }

      await CitasService().actualizarEstadoConUbicacion(
        idCita: idCita,
        nuevoEstado: nuevoEstado,
        posicion: posicion,
        tipoUbicacion: tipoUbicacion,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cita marcada como $nuevoEstado'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar cita: $e'),
        ),
      );
    }
  }

  // Chequeo del lado cliente antes de "Finalizar atención": la regla real
  // vive en database.rules.json (estado.validate exige que exista
  // pagos/{citaId} para pasar a Atendida) -- esto es solo para avisarle a
  // la especialista ANTES de intentar el write, con un botón directo a
  // CobrarServicioPage, en vez de que se entere por un error crudo de
  // permiso denegado.
  Future<void> _intentarFinalizarAtencion(
    BuildContext context,
    Map<String, dynamic> data,
    String idCita,
  ) async {
    final tienePago = await PagosService().existePago(idCita);
    debugPrint(
      '[DEBUG-FIN] entrando a _intentarFinalizarAtencion, tienePago=$tienePago',
    );

    if (!context.mounted) return;

    if (!tienePago) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Falta registrar el cobro'),
          content: const Text(
            'Debes registrar el cobro antes de finalizar la atención.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CobrarServicioPage(cita: data),
                  ),
                );
              },
              child: const Text('Cobrar servicio'),
            ),
          ],
        ),
      );
      return;
    }

    debugPrint('[DEBUG-FIN] llamando a cambiarEstado hacia Atendida');
    await cambiarEstado(context, idCita, 'Atendida');
  }

  void abrirOpcionesEstado(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final estadoActual = (data['estado'] ?? 'Pendiente').toString();

    showModalBottomSheet(
      context: context,
      // sheetContext: SOLO para Navigator.pop (cerrar el propio sheet). El
      // resto de las acciones usa `context` (el de la página, capturado
      // arriba, antes de abrir el sheet) -- reusar el context del sheet
      // después de cerrarlo es lo que causaba que cambiarEstado()/
      // _intentarFinalizarAtencion() se cortaran en silencio por
      // `if (!context.mounted) return`, ya que ese context se desmonta
      // apenas el sheet termina su animación de cierre.
      builder: (sheetContext) {
        final idCita = data['id'] ?? '';

        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Ver detalle'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  abrirDetalleCita(context, data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_walk),
                title: const Text('Iniciar salida de casa'),
                subtitle: const Text(
                    'Guarda GPS de salida y marca la cita En camino'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarEstado(
                    context,
                    idCita,
                    'En camino',
                    registrarUbicacion: true,
                    tipoUbicacion: 'salida',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Confirmar llegada al cliente'),
                subtitle: const Text(
                    'Guarda GPS de llegada y marca la cita En sitio'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarEstado(
                    context,
                    idCita,
                    'En sitio',
                    registrarUbicacion: true,
                    tipoUbicacion: 'llegada',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Finalizar atención'),
                onTap: () {
                  debugPrint(
                    '[DEBUG-FIN] onTap Finalizar atención, citaId=$idCita',
                  );
                  Navigator.pop(sheetContext);
                  _intentarFinalizarAtencion(context, data, idCita);
                },
              ),
              if (puedeCancelarCita(estadoActual))
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Marcar como Cancelada'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    cambiarEstado(context, idCita, 'Cancelada');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          BuscadorEstandar(
            hintText: 'Buscar por cliente o servicio...',
            onChanged: (texto) {
              setState(() {
                busqueda = texto;
              });
            },
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _citasStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error al cargar tus citas asignadas'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final todasMisCitas = convertirMisCitasAsignadas(
                  snapshot.data?.snapshot.value,
                );

                _intentarAbrirCitaInicial(todasMisCitas);

                if (todasMisCitas.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no tienes citas asignadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                }

                final citas = filtrarPorBusqueda(todasMisCitas);

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

                    final clienteNombre =
                        data['clienteNombre'] ?? 'Sin cliente';
                    // Distrito de ESTA cita (direccionServicio), no la dirección
                    // de perfil del cliente (clienteDireccion) -- mismo bug ya
                    // corregido en historial_especialista_page.dart.
                    final direccionServicio = data['direccionServicio'] as Map?;
                    final distrito =
                        direccionServicio?['distrito']?.toString() ?? '';
                    final servicio = data['servicio'] ?? '';
                    final precioServicio =
                        formatoPrecioServicio(data['precioServicio']);
                    final fechaCita = data['fechaCita'] ?? '';
                    final horaCita = data['horaCita'] ?? '';
                    final estado = data['estado'] ?? 'Pendiente';

                    final puedeCobrar = estado == 'En sitio';
                    final serviciosCita = parseServiciosDeCita(
                      data['servicios'],
                    );
                    final serviciosIds =
                        serviciosCita.map((item) => item.servicioId).toList();

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              abrirDetalleCita(context, data);
                            },
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
                                    'Distrito: ${distrito.isEmpty ? 'Sin dirección' : distrito}\n'
                                    'Servicio: $servicio${precioServicio.isNotEmpty ? ' - $precioServicio' : ''}',
                                  ),
                                  const SizedBox(height: 4),
                                  PildoraEstadoCita(estado: estado),
                                ],
                              ),
                              isThreeLine: false,
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  abrirOpcionesEstado(context, data);
                                },
                              ),
                            ),
                          ),
                          if (puedeCobrar)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CobrarServicioPage(cita: data),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.qr_code),
                                  label: const Text('Cobrar servicio'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2E7D32),
                                    side: const BorderSide(
                                        color: Color(0xFF2E7D32)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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

Map<String, dynamic>? _buscarCitaPorId(
  List<Map<String, dynamic>> citas,
  String citaId,
) {
  for (final cita in citas) {
    if (cita['id'] == citaId) return cita;
  }
  return null;
}

// Fila de "Tu registro" (salida/llegada) con un punto de color de 8px
// antes del texto -- ámbar para salida, verde para llegada.
