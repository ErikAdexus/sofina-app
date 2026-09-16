import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/item_cita_guardado.dart';
import '../../services/auth_service.dart';
import '../../services/citas_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/buscador_estandar.dart';
import '../../widgets/detalle_cita_widgets.dart';
import '../../widgets/servicio_chip.dart';

// Estados terminales: citas ya cerradas (atendidas o canceladas). Los
// estados accionables viven en CitasEspecialistaPage.
const _estadosTerminalesEspecialista = {'Atendida', 'Cancelada'};

class HistorialEspecialistaPage extends StatefulWidget {
  final String? citaIdInicial;

  const HistorialEspecialistaPage({super.key, this.citaIdInicial});

  @override
  State<HistorialEspecialistaPage> createState() =>
      _HistorialEspecialistaPageState();
}

class _HistorialEspecialistaPageState extends State<HistorialEspecialistaPage> {
  String filtro = 'todas';
  String busqueda = '';

  // Cacheado: CitasService().streamCitas() crea un Stream nuevo en cada
  // llamada. Si se llamara directo en build(), cada setState() (tocar un
  // filtro) le pasaría a StreamBuilder una instancia distinta y lo
  // forzaría a desuscribirse/resuscribirse, mostrando el spinner de carga
  // en cada interacción (mismo bug ya corregido antes en Pagos).
  late final Stream<DatabaseEvent> _citasStream = CitasService()
      .streamCitasDeEspecialista(AuthService().currentUser?.uid ?? '');
  bool _citaInicialAtendida = false;

  // colorEstadoCita/iconoEstadoCita ahora viven centralizadas en
  // widgets/detalle_cita_widgets.dart (antes era una versión parcial --
  // solo Atendida/Cancelada, los dos estados terminales que se ven acá --
  // de la misma que estaba triplicada en admin_gestion_citas_page.dart y
  // citas_especialista_page.dart).

  String formatoPrecioServicio(dynamic precio) {
    final valor = num.tryParse(precio?.toString() ?? '');

    if (valor == null || valor <= 0) {
      return '';
    }

    return 'S/ ${valor.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> convertirMiHistorial(dynamic value) {
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

        if (esMiCita && _estadosTerminalesEspecialista.contains(estado)) {
          citas.add({
            'id': key.toString(),
            'clienteNombre': data['clienteNombre']?.toString() ?? '',
            'clienteCelular': data['clienteCelular']?.toString() ?? '',
            'clienteCorreo': data['clienteCorreo']?.toString() ?? '',
            // Dirección real donde se hizo ESTA cita, independiente de la
            // dirección de perfil del cliente -- el salón atiende a
            // domicilio y puede ser en otro lugar (antes el modal usaba
            // por error clienteDireccion, la dirección de perfil).
            'direccionServicio': data['direccionServicio'] is Map
                ? Map<dynamic, dynamic>.from(data['direccionServicio'])
                : null,
            'servicios':
                data['servicios'] is List ? data['servicios'] : const [],
            'salidaEspecialista': data['salidaEspecialista'] is Map
                ? Map<dynamic, dynamic>.from(data['salidaEspecialista'])
                : null,
            'llegadaEspecialista': data['llegadaEspecialista'] is Map
                ? Map<dynamic, dynamic>.from(data['llegadaEspecialista'])
                : null,
            'servicio': data['servicio']?.toString() ?? '',
            'precioServicio': data['precioServicio'] is num
                ? data['precioServicio']
                : num.tryParse(data['precioServicio']?.toString() ?? '') ?? 0,
            'observacion': data['observacion']?.toString() ?? '',
            'fechaCita': data['fechaCita']?.toString() ?? '',
            'horaCita': data['horaCita']?.toString() ?? '',
            'fechaHoraCitaMillis': data['fechaHoraCitaMillis'] is int
                ? data['fechaHoraCitaMillis']
                : 0,
            'estado': estado,
            'fechaRegistroMillis': data['fechaRegistroMillis'] is int
                ? data['fechaRegistroMillis']
                : 0,
          });
        }
      }
    });

    // Descendente: la cita más reciente primero (al revés que en Citas,
    // donde la más próxima en el tiempo va primero).
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

      return fechaB.compareTo(fechaA);
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

  void abrirDetalleCita(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final precioServicio = formatoPrecioServicio(data['precioServicio']);
        final estado = (data['estado'] ?? '').toString();

        final clienteNombre = (data['clienteNombre'] ?? '').toString();
        final clienteCelular = (data['clienteCelular'] ?? '').toString();
        final clienteCorreo = (data['clienteCorreo'] ?? '').toString();

        // "Lun 31 ago" / "9:41 pm" a partir de fechaHoraCitaMillis; si la
        // cita no lo trajera (dato viejo), cae a los strings crudos que
        // ya vienen listos de RTDB -- mismo respaldo que las referencias.
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
        // con el nombre/precio ya combinados -- mismo respaldo que usan
        // las 2 referencias ya conformes.
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                                      fontWeight: FontWeight.bold,
                                    ),
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
    // idéntico a citas_especialista_page.dart -- convertirMiHistorial ya
    // filtró por esMiCita antes de esto.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: StreamBuilder<DatabaseEvent>(
        stream: _citasStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al cargar tu historial'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final todoElHistorial = convertirMiHistorial(
            snapshot.data?.snapshot.value,
          );

          _intentarAbrirCitaInicial(todoElHistorial);

          final porEstado = filtro == 'todas'
              ? todoElHistorial
              : todoElHistorial.where((c) => c['estado'] == filtro).toList();
          final citas = filtrarPorBusqueda(porEstado);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: filtro == 'todas',
                      onSelected: (_) => setState(() => filtro = 'todas'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Atendida'),
                      selected: filtro == 'Atendida',
                      onSelected: (_) => setState(() => filtro = 'Atendida'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Cancelada'),
                      selected: filtro == 'Cancelada',
                      onSelected: (_) => setState(() => filtro = 'Cancelada'),
                    ),
                  ],
                ),
              ),
              BuscadorEstandar(
                hintText: 'Buscar por cliente o servicio...',
                onChanged: (texto) {
                  setState(() {
                    busqueda = texto;
                  });
                },
              ),
              Expanded(
                child: citas.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No hay citas en este filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: citas.length,
                        itemBuilder: (context, index) {
                          final data = citas[index];

                          final clienteNombre =
                              data['clienteNombre'] ?? 'Sin cliente';
                          final direccionServicio =
                              data['direccionServicio'] as Map?;
                          final distrito =
                              direccionServicio?['distrito']?.toString() ?? '';
                          final servicio = data['servicio'] ?? '';
                          final precioServicio =
                              formatoPrecioServicio(data['precioServicio']);
                          final fechaCita = data['fechaCita'] ?? '';
                          final horaCita = data['horaCita'] ?? '';
                          final estado = data['estado'] ?? '';
                          final serviciosCita = parseServiciosDeCita(
                            data['servicios'],
                          );
                          final serviciosIds = serviciosCita
                              .map((item) => item.servicioId)
                              .toList();

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
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
                                      fontWeight: FontWeight.bold,
                                    ),
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

Map<String, dynamic>? _buscarCitaPorId(
  List<Map<String, dynamic>> citas,
  String citaId,
) {
  for (final cita in citas) {
    if (cita['id'] == citaId) return cita;
  }
  return null;
}
