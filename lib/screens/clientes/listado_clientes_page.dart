import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../services/clientes_service.dart';

class ListadoClientesPage extends StatelessWidget {
  const ListadoClientesPage({super.key});

  void abrirEditarCliente(
    BuildContext context,
    String idCliente,
    Map<String, dynamic> data,
  ) {
    final nombreController = TextEditingController(
      text: data['nombreCompleto'] ?? '',
    );
    final celularController = TextEditingController(
      text: data['celular'] ?? '',
    );
    final direccionController = TextEditingController(
      text: data['direccion'] ?? '',
    );
    final correoController = TextEditingController(
      text: data['correo'] ?? '',
    );

    String estadoSeleccionado = data['estado'] ?? 'Activo';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar cliente'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
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
                      controller: direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
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
                    DropdownButtonFormField<String>(
                      initialValue: estadoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Activo',
                          child: Text('Activo'),
                        ),
                        DropdownMenuItem(
                          value: 'Inactivo',
                          child: Text('Inactivo'),
                        ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          estadoSeleccionado = value!;
                        });
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
                      await ClientesService().actualizarCliente(
                        idCliente: idCliente,
                        authUid: data['authUid']?.toString() ?? '',
                        nombreCompleto: nombreController.text.trim(),
                        celular: celularController.text.trim(),
                        direccion: direccionController.text.trim(),
                        correo: correoController.text.trim(),
                        estado: estadoSeleccionado,
                      );

                      if (!context.mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente actualizado correctamente'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar cliente: $e'),
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

  List<Map<String, dynamic>> convertirClientes(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final clientes = <Map<String, dynamic>>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final data = Map<dynamic, dynamic>.from(value);

        clientes.add({
          'id': key.toString(),
          'nombreCompleto': data['nombreCompleto']?.toString() ?? '',
          'celular': data['celular']?.toString() ?? '',
          'direccion': data['direccion']?.toString() ?? '',
          'correo': data['correo']?.toString() ?? '',
          'metodoAcceso': data['metodoAcceso']?.toString() ?? 'correo',
          'estado': data['estado']?.toString() ?? 'Activo',
          'authUid': data['authUid']?.toString() ?? '',
          'fechaRegistro': data['fechaRegistro']?.toString() ?? '',
          'fechaRegistroMillis': data['fechaRegistroMillis'] is int
              ? data['fechaRegistroMillis']
              : 0,
        });
      }
    });

    clientes.sort((a, b) {
      final fechaA = a['fechaRegistroMillis'] as int;
      final fechaB = b['fechaRegistroMillis'] as int;
      return fechaB.compareTo(fechaA);
    });

    return clientes;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: StreamBuilder<DatabaseEvent>(
        stream: ClientesService().streamClientes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al cargar clientes'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final clientes = convertirClientes(snapshot.data?.snapshot.value);

          if (clientes.isEmpty) {
            return const Center(
              child: Text(
                'No hay clientes registrados',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final data = clientes[index];

              final idCliente = data['id'] ?? '';
              final nombre = data['nombreCompleto'] ?? 'Sin nombre';
              final celular = data['celular'] ?? '';
              final direccion = data['direccion'] ?? '';
              final correo = (data['correo'] ?? '').toString();
              final estado = data['estado'] ?? 'Activo';
              final correoMostrar =
                  correo.isEmpty ? 'Sin correo (accede con celular)' : correo;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: estado == 'Activo'
                        ? const Color(0xFF1565C0)
                        : Colors.grey,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Celular: $celular\nDirección: $direccion\nCorreo: $correoMostrar\nEstado: $estado',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      abrirEditarCliente(context, idCliente, data);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
