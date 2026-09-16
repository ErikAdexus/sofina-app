import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/categoria_servicio.dart';
import '../../models/servicio_catalogo.dart';
import '../../services/catalogo_service.dart';
import '../../services/configuracion_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class CatalogoServiciosPage extends StatelessWidget {
  const CatalogoServiciosPage({super.key});

  List<CategoriaServicio> convertirCategorias(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final categorias = <CategoriaServicio>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final categoria = CategoriaServicio.fromMap(
          key.toString(),
          Map<dynamic, dynamic>.from(value),
        );

        if (categoria.nombre.trim().isNotEmpty) {
          categorias.add(categoria);
        }
      }
    });

    categorias.sort((a, b) {
      final ordenComparado = a.orden.compareTo(b.orden);
      if (ordenComparado != 0) return ordenComparado;
      return a.nombre.compareTo(b.nombre);
    });

    return categorias;
  }

  List<ServicioCatalogo> convertirServicios(dynamic value) {
    if (value == null || value is! Map) {
      return [];
    }

    final mapa = Map<dynamic, dynamic>.from(value);
    final servicios = <ServicioCatalogo>[];

    mapa.forEach((key, value) {
      if (value is Map) {
        final servicio = ServicioCatalogo.fromMap(
          key.toString(),
          Map<dynamic, dynamic>.from(value),
        );

        if (servicio.nombre.trim().isNotEmpty) {
          servicios.add(servicio);
        }
      }
    });

    servicios.sort((a, b) {
      final ordenComparado = a.orden.compareTo(b.orden);
      if (ordenComparado != 0) return ordenComparado;
      return a.nombre.compareTo(b.nombre);
    });

    return servicios;
  }

  void abrirFormularioCategoria(
    BuildContext context, {
    CategoriaServicio? categoria,
  }) {
    final nombreController =
        TextEditingController(text: categoria?.nombre ?? '');
    final ordenController = TextEditingController(
      text: categoria == null ? '1' : categoria.orden.toString(),
    );

    String estadoSeleccionado = categoria?.estado ?? 'Activo';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                  categoria == null ? 'Nueva categoría' : 'Editar categoría'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de categoría',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ordenController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Orden',
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
                          estadoSeleccionado = value ?? 'Activo';
                        });
                      },
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
                    final nombre = nombreController.text.trim();

                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingrese el nombre de la categoría'),
                        ),
                      );
                      return;
                    }

                    final orden =
                        int.tryParse(ordenController.text.trim()) ?? 1;

                    try {
                      await CatalogoService().guardarCategoria(
                        id: categoria?.id,
                        nombre: nombre,
                        estado: estadoSeleccionado,
                        orden: orden,
                      );

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar categoría: $e'),
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

  void abrirFormularioServicio(
    BuildContext context, {
    required List<CategoriaServicio> categorias,
    ServicioCatalogo? servicio,
  }) {
    if (categorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea una categoría de servicio'),
        ),
      );
      return;
    }

    final nombreController =
        TextEditingController(text: servicio?.nombre ?? '');
    final descripcionController =
        TextEditingController(text: servicio?.descripcion ?? '');
    final precioController = TextEditingController(
      text: servicio == null ? '' : servicio.precio.toStringAsFixed(0),
    );
    final duracionController = TextEditingController(
      text: servicio == null ? '30' : servicio.duracionMinutos.toString(),
    );
    final ordenController = TextEditingController(
      text: servicio == null ? '1' : servicio.orden.toString(),
    );
    final imagenAssetController = TextEditingController(
      text: servicio?.imagenAsset ?? '',
    );

    String categoriaSeleccionada = servicio?.categoriaId ?? categorias.first.id;

    final existeCategoria =
        categorias.any((item) => item.id == categoriaSeleccionada);
    if (!existeCategoria) {
      categoriaSeleccionada = categorias.first.id;
    }

    String estadoSeleccionado = servicio?.estado ?? 'Activo';
    bool requiereCotizacion = servicio?.requiereCotizacion ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title:
                  Text(servicio == null ? 'Nuevo servicio' : 'Editar servicio'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: categoriaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                      items: categorias.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria.id,
                          child: Text(categoria.nombre),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          categoriaSeleccionada =
                              value ?? categoriaSeleccionada;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del servicio',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precioController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precio S/',
                        hintText:
                            'Déjalo vacío o en 0 si el precio es a consultar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: duracionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duración minutos',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ordenController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Orden',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imagenAssetController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de archivo de imagen',
                        hintText:
                            'Debe coincidir EXACTO (mayúsculas incluidas). Ej: Nail_Art.png',
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
                          estadoSeleccionado = value ?? 'Activo';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: requiereCotizacion,
                      title: const Text('Requiere cotización'),
                      subtitle: const Text(
                        'El cliente no podrá reservarlo directo: el chat y el '
                        'formulario le van a pedir que te contacte por '
                        'WhatsApp en vez de mostrar un precio fijo.',
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          requiereCotizacion = value;
                        });
                      },
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
                    final nombre = nombreController.text.trim();
                    final descripcion = descripcionController.text.trim();
                    final precioTexto = precioController.text.trim();
                    final precio = precioTexto.isEmpty
                        ? 0.0
                        : double.tryParse(precioTexto);
                    final duracion =
                        int.tryParse(duracionController.text.trim()) ?? 0;
                    final orden =
                        int.tryParse(ordenController.text.trim()) ?? 1;
                    final imagenAsset = imagenAssetController.text.trim();

                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingrese el nombre del servicio'),
                        ),
                      );
                      return;
                    }

                    if (precio == null || precio < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ingrese un precio válido, o déjelo vacío/0 si es a consultar',
                          ),
                        ),
                      );
                      return;
                    }

                    if (imagenAsset.isNotEmpty &&
                        !RegExp(r'\.(png|jpg)$', caseSensitive: false)
                            .hasMatch(imagenAsset)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El nombre de archivo de imagen debe terminar en .png o .jpg',
                          ),
                        ),
                      );
                      return;
                    }

                    final categoria = categorias.firstWhere(
                      (item) => item.id == categoriaSeleccionada,
                    );

                    try {
                      await CatalogoService().guardarServicio(
                        id: servicio?.id,
                        categoriaId: categoria.id,
                        categoriaNombre: categoria.nombre,
                        nombre: nombre,
                        descripcion: descripcion,
                        precio: precio,
                        duracionMinutos: duracion,
                        estado: estadoSeleccionado,
                        orden: orden,
                        mostrarEnPublicidad: true,
                        imagenAsset: imagenAsset,
                        requiereCotizacion: requiereCotizacion,
                      );

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar servicio: $e'),
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

  // Círculo pequeño (thumbnail) para el leading del ListTile. Si hay
  // imagenAsset, se puede tocar para verla ampliada en el modal; si no,
  // muestra el ícono de respaldo sin acción.
  Widget imagenServicio(BuildContext context, ServicioCatalogo servicio) {
    final avatar = CircleAvatar(
      radius: 40,
      backgroundColor: servicio.activo ? const Color(0xFF2E7D32) : Colors.grey,
      backgroundImage: servicio.imagenAsset.isEmpty
          ? null
          : AssetImage(
              'assets/images/servicios/${servicio.imagenAsset}',
            ),
      onBackgroundImageError:
          servicio.imagenAsset.isEmpty ? null : (exception, stackTrace) {},
      child: servicio.imagenAsset.isEmpty
          ? const Icon(
              Icons.spa,
              color: Colors.white,
              size: 36,
            )
          : null,
    );

    if (servicio.imagenAsset.isEmpty) {
      return avatar;
    }

    return GestureDetector(
      onTap: () => abrirImagenAmpliada(context, servicio),
      child: avatar,
    );
  }

  void abrirImagenAmpliada(BuildContext context, ServicioCatalogo servicio) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final alturaMaxima = MediaQuery.of(dialogContext).size.height * 0.75;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: BoxConstraints(maxHeight: alturaMaxima),
              color: Colors.black,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Image.asset(
                      'assets/images/servicios/${servicio.imagenAsset}',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    color: Colors.black87,
                    child: Text(
                      servicio.nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> cambiarEstadoServicio(
    BuildContext context,
    ServicioCatalogo servicio,
  ) async {
    try {
      final nuevoEstado =
          await CatalogoService().cambiarEstadoServicio(servicio);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servicio actualizado a $nuevoEstado'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar estado: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: StreamBuilder<DatabaseEvent>(
        stream: CatalogoService().streamCategorias(),
        builder: (context, categoriasSnapshot) {
          final categorias = convertirCategorias(
            categoriasSnapshot.data?.snapshot.value,
          );

          return StreamBuilder<DatabaseEvent>(
            stream: CatalogoService().streamServicios(),
            builder: (context, serviciosSnapshot) {
              final servicios = convertirServicios(
                serviciosSnapshot.data?.snapshot.value,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _TarjetaPrecioRetiro(),
                  const SizedBox(height: 12),
                  const _TarjetaWhatsapp(),
                  const SizedBox(height: 12),
                  const _TarjetaQrPago(),
                  const SizedBox(height: 12),
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
                            'Catálogo de servicios',
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
                            'Administra categorías, precios y servicios que el cliente podrá reservar.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () =>
                                    abrirFormularioCategoria(context),
                                icon: const Icon(Icons.category),
                                label: const Text('Nueva categoría'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => abrirFormularioServicio(
                                  context,
                                  categorias: categorias,
                                ),
                                icon: const Icon(Icons.add_business),
                                label: const Text('Nuevo servicio'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .extension<SofinaColors>()!
                                      .primaryDark,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 4,
                    child: ExpansionTile(
                      initiallyExpanded: categorias.isEmpty,
                      leading: const Icon(Icons.category),
                      title: const Text(
                        'Categorías',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: categorias.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No hay categorías registradas.'),
                              ),
                            ]
                          : categorias.map((categoria) {
                              return ListTile(
                                title: Text(categoria.nombre),
                                subtitle: Text(
                                  'Estado: ${categoria.estado} · Orden: ${categoria.orden}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => abrirFormularioCategoria(
                                    context,
                                    categoria: categoria,
                                  ),
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (servicios.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context)
                              .extension<SofinaColors>()!
                              .softTint,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storefront,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'No hay servicios registrados. Crea uno nuevo con el botón de arriba.',
                              style: TextStyle(
                                color: Colors.black54,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...servicios.map((servicio) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: imagenServicio(context, servicio),
                          title: Text(
                            servicio.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${servicio.categoriaNombre.isEmpty ? 'Sin categoría' : servicio.categoriaNombre}\n'
                                '${servicio.requiereCotizacion || servicio.precio <= 0 ? 'Precio a consultar' : 'S/ ${servicio.precio.toStringAsFixed(0)}'} · ${servicio.duracionMinutos} min · ${servicio.estado}'
                                '${servicio.requiereCotizacion ? ' · Requiere cotización' : ''}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    servicio.imagenAsset.isEmpty
                                        ? Icons.image_not_supported
                                        : Icons.image,
                                    size: 14,
                                    color: servicio.imagenAsset.isEmpty
                                        ? Colors.grey
                                        : const Color(0xFF2E7D32),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    servicio.imagenAsset.isEmpty
                                        ? 'Sin imagen'
                                        : servicio.imagenAsset,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'editar') {
                                abrirFormularioServicio(
                                  context,
                                  categorias: categorias,
                                  servicio: servicio,
                                );
                              }

                              if (value == 'estado') {
                                cambiarEstadoServicio(context, servicio);
                              }
                            },
                            itemBuilder: (context) {
                              return [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'estado',
                                  child: Text(
                                    servicio.activo ? 'Desactivar' : 'Activar',
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Precio de retiro (limpieza de trabajo previo), aplicable por unidad de
// servicio cuando el cliente lo pide. Editable acá sin redeployar: la
// Cloud Function crearCita lee este mismo valor al calcular el precio
// final, nunca confía en lo que mande el cliente.
class _TarjetaPrecioRetiro extends StatefulWidget {
  const _TarjetaPrecioRetiro();

  @override
  State<_TarjetaPrecioRetiro> createState() => _TarjetaPrecioRetiroState();
}

class _TarjetaPrecioRetiroState extends State<_TarjetaPrecioRetiro> {
  final montoController = TextEditingController();
  final servicio = ConfiguracionService();

  bool guardando = false;
  double? montoActual;

  @override
  void dispose() {
    montoController.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final monto = double.tryParse(montoController.text.trim());

    if (monto == null || monto < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un monto válido')),
      );
      return;
    }

    setState(() => guardando = true);

    try {
      await servicio.guardarPrecioRetiro(monto);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio de retiro actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: StreamBuilder<DatabaseEvent>(
          stream: servicio.streamPrecioRetiro(),
          builder: (context, snapshot) {
            final valor = snapshot.data?.snapshot.value;
            final monto = valor is num ? valor.toDouble() : 0.0;

            if (montoActual != monto) {
              montoActual = monto;
              montoController.text = monto.toStringAsFixed(0);
            }

            final primarioOscuro =
                Theme.of(context).extension<SofinaColors>()!.primaryDark;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cleaning_services, color: primarioOscuro),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio de retiro',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cargo opcional por unidad de servicio, aplicable cuando el cliente pide retiro de trabajo previo.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: montoController,
                              enabled: !guardando,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Monto S/',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: guardando ? null : guardar,
                            child: Text(guardando ? 'Guardando...' : 'Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Número de WhatsApp del negocio, usado para armar el enlace
// https://wa.me/<numero> tanto en el chat de Sofina Cliente como en los
// servicios que requieren cotización. Editable acá sin redeployar.
class _TarjetaWhatsapp extends StatefulWidget {
  const _TarjetaWhatsapp();

  @override
  State<_TarjetaWhatsapp> createState() => _TarjetaWhatsappState();
}

class _TarjetaWhatsappState extends State<_TarjetaWhatsapp> {
  final numeroController = TextEditingController();
  final servicio = ConfiguracionService();

  bool guardando = false;
  String? numeroActual;

  @override
  void dispose() {
    numeroController.dispose();
    super.dispose();
  }

  Future<void> guardar() async {
    final texto = numeroController.text.trim();
    final soloDigitos = texto.startsWith('+') ? texto.substring(1) : texto;

    if (soloDigitos.isEmpty || !RegExp(r'^\d+$').hasMatch(soloDigitos)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ingrese un número válido (solo dígitos, con código de país)'),
        ),
      );
      return;
    }

    setState(() => guardando = true);

    try {
      await servicio.guardarWhatsapp(soloDigitos);

      if (!mounted) return;
      numeroController.text = soloDigitos;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de WhatsApp actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: StreamBuilder<DatabaseEvent>(
          stream: servicio.streamWhatsapp(),
          builder: (context, snapshot) {
            final valor = snapshot.data?.snapshot.value?.toString() ?? '';

            if (numeroActual != valor) {
              numeroActual = valor;
              numeroController.text = valor;
            }

            final primarioOscuro =
                Theme.of(context).extension<SofinaColors>()!.primaryDark;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chat, color: primarioOscuro),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp de contacto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Número al que se dirige al cliente cuando un servicio requiere cotización. Incluye código de país, sin espacios ni símbolos (ej: 51936106272).',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: numeroController,
                              enabled: !guardando,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Número (con código de país)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: guardando ? null : guardar,
                            child: Text(guardando ? 'Guardando...' : 'Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// QR de pago (Yape) que la especialista muestra al cobrar un servicio
// (ver CobrarServicioPage). Vive en Firebase Storage, ruta fija
// "configuracion/qr_pago.png" (cada subida nueva sobrescribe la anterior);
// la URL de descarga se guarda en configuracion/pago/qrUrl para que la app
// del especialista la lea sin necesidad de republicar la app cuando Sofía
// cambie de cuenta.
class _TarjetaQrPago extends StatefulWidget {
  const _TarjetaQrPago();

  @override
  State<_TarjetaQrPago> createState() => _TarjetaQrPagoState();
}

class _TarjetaQrPagoState extends State<_TarjetaQrPago> {
  final servicio = ConfiguracionService();
  final storage = StorageService();

  bool subiendo = false;

  Future<void> seleccionarYSubir() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (resultado == null || resultado.files.isEmpty) return;

    final archivo = resultado.files.single;
    final extension = archivo.extension?.toLowerCase() ?? 'png';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

    setState(() => subiendo = true);

    try {
      final url = await storage.subirQrPago(
        archivo: archivo,
        contentType: contentType,
      );

      await servicio.guardarQrPagoUrl(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR de pago actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir el QR: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => subiendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primarioOscuro =
        Theme.of(context).extension<SofinaColors>()!.primaryDark;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: StreamBuilder<DatabaseEvent>(
          stream: servicio.streamQrPago(),
          builder: (context, snapshot) {
            final url = snapshot.data?.snapshot.value?.toString() ?? '';

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_2, color: primarioOscuro),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR de pago (Yape)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'La especialista muestra este QR al cliente al cobrar un servicio. Súbelo aquí si cambia de cuenta.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      if (url.isEmpty)
                        const Text(
                          'Aún no hay un QR configurado.',
                          style: TextStyle(color: Colors.black54),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 160,
                            height: 160,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 160,
                                height: 160,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox(
                                width: 160,
                                height: 160,
                                child: Center(
                                  child: Text('No se pudo cargar el QR'),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: subiendo ? null : seleccionarYSubir,
                        icon: subiendo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: Text(
                          subiendo
                              ? 'Subiendo...'
                              : url.isEmpty
                                  ? 'Subir QR'
                                  : 'Reemplazar QR',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
