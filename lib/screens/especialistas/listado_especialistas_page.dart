import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/especialistas_service.dart';
import '../../utils/distritos_lima.dart';
import '../../utils/formatters.dart';
import '../../widgets/detalle_cita_widgets.dart';
import '../calificaciones/admin_calificaciones_page.dart';
import '../disponibilidad/franja_horaria_page.dart';

// Mismo patrón que abrirEnGoogleMaps en location_helpers.dart: abre el PDF
// del certificado en una app externa (navegador/visor), con snackbar de
// respaldo si no hay nada instalado que lo abra.
Future<void> _abrirCertificado(BuildContext context, String urlPdf) async {
  final uri = Uri.parse(urlPdf);
  final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!abierto && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el certificado.')),
    );
  }
}

class ListadoEspecialistasPage extends StatelessWidget {
  const ListadoEspecialistasPage({super.key});

  Color colorEstado(String estado) {
    switch (estado) {
      case 'Activo':
        return const Color(0xFF2E7D32);
      case 'Rechazado':
        return const Color(0xFFC62828);
      case 'Pendiente':
        return const Color(0xFFF9A825);
      default:
        return Colors.grey;
    }
  }

  String descripcionEstado(String estado) {
    switch (estado) {
      case 'Activo':
        return 'Activo - filtro positivo';
      case 'Rechazado':
        return 'Rechazado - filtro negativo';
      case 'Pendiente':
        return 'Pendiente - por validar';
      default:
        return estado;
    }
  }

  List<Map<String, dynamic>> convertirEspecialistas(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final especialistas = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final data = Map<dynamic, dynamic>.from(value);
        final resumen = data['calificacionResumen'] is Map
            ? Map<dynamic, dynamic>.from(data['calificacionResumen'])
            : null;

        especialistas.add({
          'id': key.toString(),
          'nombreCompleto': data['nombreCompleto']?.toString() ?? '',
          'celular': data['celular']?.toString() ?? '',
          'correo': data['correo']?.toString() ?? '',
          'metodoAcceso': data['metodoAcceso']?.toString() ?? 'correo',
          'direccion': data['direccion']?.toString() ?? '',
          'experiencia': data['experiencia']?.toString() ?? '',
          'especialidad': data['especialidad']?.toString() ?? '',
          'estado': data['estado']?.toString() ?? 'Activo',
          'distrito': data['distrito']?.toString(),
          'urlFoto': data['urlFoto']?.toString() ?? '',
          'urlPdf': data['urlPdf']?.toString() ?? '',
          'nombreFoto': data['nombreFoto']?.toString() ?? '',
          'nombrePdf': data['nombrePdf']?.toString() ?? '',
          'authUid': data['authUid']?.toString() ?? '',
          'fechaRegistro': data['fechaRegistro']?.toString() ?? '',
          'fechaRegistroMillis': data['fechaRegistroMillis'] is int
              ? data['fechaRegistroMillis']
              : 0,
          // Ya calculado por la Cloud Function actualizarResumenCalificacion
          // (proyectocitas2/functions/index.js); se lee del mismo registro
          // que ya se trae acá, sin ninguna lectura adicional.
          'calificacionPromedio': resumen != null && resumen['promedio'] is num
              ? (resumen['promedio'] as num).toDouble()
              : 0.0,
          'calificacionTotal': resumen != null && resumen['total'] is num
              ? (resumen['total'] as num).toInt()
              : 0,
        });
      }
    });

    especialistas.sort((a, b) {
      final fechaA = a['fechaRegistroMillis'] as int;
      final fechaB = b['fechaRegistroMillis'] as int;
      return fechaB.compareTo(fechaA);
    });

    return especialistas;
  }

  void abrirDetalleEspecialista(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final urlFoto = (data['urlFoto'] ?? '').toString();
    final urlPdf = (data['urlPdf'] ?? '').toString();
    final nombrePdf = (data['nombrePdf'] ?? '').toString();
    final correo = (data['correo'] ?? '').toString();
    final correoMostrar =
        correo.isEmpty ? 'Sin correo (accede con celular)' : correo;
    final estado = (data['estado'] ?? 'Activo').toString();
    final distrito = (data['distrito'] ?? '').toString();
    final calificacionPromedio = data['calificacionPromedio'] as double? ?? 0.0;
    final calificacionTotal = data['calificacionTotal'] as int? ?? 0;
    final fechaRegistro = DateTime.tryParse(
      (data['fechaRegistro'] ?? '').toString(),
    );
    final fechaRegistroTexto = fechaRegistro != null
        ? formatearFechaCorta(fechaRegistro)
        : 'Sin registrar';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['nombreCompleto'] ?? 'Detalle de especialista',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Center(
                    child: urlFoto.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              urlFoto,
                              height: 160,
                              width: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 160,
                                width: 160,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.person,
                                    size: 90, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            height: 160,
                            width: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.person,
                                size: 90, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(height: 16),
                  SeccionInfoCita(
                    icono: Icons.contact_phone,
                    titulo: 'Contacto y dirección',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Celular: ${data['celular'] ?? ''}'),
                        const SizedBox(height: 4),
                        Text('Correo: $correoMostrar'),
                        const SizedBox(height: 4),
                        Text('Dirección: ${data['direccion'] ?? ''}'),
                        const SizedBox(height: 4),
                        Text(
                          'Distrito: ${distrito.isNotEmpty ? distrito : 'Sin distrito registrado'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SeccionInfoCita(
                    icono: Icons.badge,
                    titulo: 'Especialidad',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Especialidad: ${data['especialidad'] ?? ''}'),
                        const SizedBox(height: 4),
                        Text('Experiencia: ${data['experiencia'] ?? ''}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SeccionInfoCita(
                    icono: Icons.star,
                    titulo: 'Calificaciones',
                    child: calificacionTotal > 0
                        ? Text(
                            '⭐ ${calificacionPromedio.toStringAsFixed(1)} · '
                            '$calificacionTotal calificación${calificacionTotal == 1 ? '' : 'es'}',
                          )
                        : const Text('Sin calificaciones aún'),
                  ),
                  const SizedBox(height: 12),
                  SeccionInfoCita(
                    icono: Icons.description,
                    titulo: 'Registro y certificado',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estado: ${descripcionEstado(estado)}'),
                        const SizedBox(height: 4),
                        Text('Especialista desde: $fechaRegistroTexto'),
                        const SizedBox(height: 8),
                        if (urlPdf.isNotEmpty)
                          InkWell(
                            onTap: () => _abrirCertificado(context, urlPdf),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    nombrePdf.isNotEmpty
                                        ? nombrePdf
                                        : 'Ver certificado',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text('Sin certificado cargado'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  BadgeEstadoCita(
                    estado: estado,
                    color: colorEstado(estado),
                    icono: estado == 'Activo'
                        ? Icons.check_circle
                        : estado == 'Rechazado'
                            ? Icons.cancel
                            : Icons.schedule,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void abrirEditarEspecialista(
    BuildContext context,
    String idEspecialista,
    Map<String, dynamic> data,
  ) {
    final nombreController = TextEditingController(
      text: data['nombreCompleto'] ?? '',
    );
    final celularController = TextEditingController(
      text: data['celular'] ?? '',
    );
    final correoController = TextEditingController(
      text: data['correo'] ?? '',
    );
    final direccionController = TextEditingController(
      text: data['direccion'] ?? '',
    );
    final experienciaController = TextEditingController(
      text: data['experiencia'] ?? '',
    );
    final especialidadController = TextEditingController(
      text: data['especialidad'] ?? '',
    );

    String estadoSeleccionado = data['estado'] ?? 'Pendiente';

    // Texto libre a propósito (Autocomplete, no dropdown): se muestra tal
    // cual lo que ya esté guardado, aunque no matchee ningún distrito de
    // la lista vigente (ej. dato viejo). Se valida recién al Guardar --
    // ver más abajo -- para no perder silenciosamente lo que el admin ya
    // había registrado con solo abrir el diálogo.
    final distritoGuardado = data['distrito']?.toString() ?? '';
    String distritoTexto = distritoGuardado;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar especialista'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    EspecialistaAvatar(
                      especialistaId: idEspecialista,
                      nombre: data['nombreCompleto']?.toString() ?? '',
                      radio: 32,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: celularController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: experienciaController,
                      decoration: const InputDecoration(
                        labelText: 'Experiencia',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: especialidadController,
                      decoration: const InputDecoration(
                        labelText: 'Especialidad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: estadoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Pendiente',
                          child: Text('Pendiente - por validar'),
                        ),
                        DropdownMenuItem(
                          value: 'Activo',
                          child: Text('Activo - filtro positivo'),
                        ),
                        DropdownMenuItem(
                          value: 'Rechazado',
                          child: Text('Rechazado - filtro negativo'),
                        ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          estadoSeleccionado = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: distritoTexto),
                      optionsBuilder: (textEditingValue) {
                        final texto =
                            textEditingValue.text.trim().toLowerCase();
                        if (texto.isEmpty) return distritosLima;

                        return distritosLima.where(
                          (distrito) => distrito.toLowerCase().contains(texto),
                        );
                      },
                      onSelected: (seleccion) {
                        distritoTexto = seleccion;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmit) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Distrito donde vive',
                            hintText: 'Escribe para buscar...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (texto) {
                            distritoTexto = texto;
                          },
                        );
                      },
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
                    try {
                      // Solo se guarda si matchea EXACTO uno de los 43
                      // distritos -- texto libre que no coincide con
                      // ninguno (typo, distrito fuera de Lima, etc.) se
                      // guarda como "sin definir" en vez de basura suelta
                      // en el perfil.
                      final distritoValido = distritosLima.contains(
                        distritoTexto.trim(),
                      );

                      await EspecialistasService().actualizarEspecialista(
                        idEspecialista: idEspecialista,
                        authUid: data['authUid']?.toString() ?? '',
                        nombreCompleto: nombreController.text.trim(),
                        celular: celularController.text.trim(),
                        correo: correoController.text.trim(),
                        direccion: direccionController.text.trim(),
                        experiencia: experienciaController.text.trim(),
                        especialidad: especialidadController.text.trim(),
                        estado: estadoSeleccionado,
                        distrito: distritoValido ? distritoTexto.trim() : null,
                      );

                      if (!context.mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Especialista actualizado correctamente'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar especialista: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminCalificacionesPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.star_rate),
                label: const Text('Ver calificaciones de especialistas'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FranjaHorariaPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.event_available),
                label: const Text('Disponibilidad por horario'),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: EspecialistasService().streamEspecialistas(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error al cargar especialistas'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final especialistas =
                    convertirEspecialistas(snapshot.data?.snapshot.value);

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

                    final idEspecialista = data['id'] ?? '';
                    final nombre = data['nombreCompleto'] ?? 'Sin nombre';
                    final celular = data['celular'] ?? '';
                    final especialidad = data['especialidad'] ?? '';
                    final estado = data['estado'] ?? 'Activo';
                    final urlFoto = data['urlFoto'] ?? '';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorEstado(estado),
                          backgroundImage: urlFoto.toString().isNotEmpty
                              ? NetworkImage(urlFoto)
                              : null,
                          child: urlFoto.toString().isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        title: Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Celular: $celular\nEspecialidad: $especialidad\nEstado: ${descripcionEstado(estado)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () {
                                abrirDetalleEspecialista(context, data);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                abrirEditarEspecialista(
                                  context,
                                  idEspecialista,
                                  data,
                                );
                              },
                            ),
                          ],
                        ),
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
