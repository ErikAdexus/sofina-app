import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/configuracion_service.dart';
import '../../services/pagos_service.dart';
import '../../utils/formatters.dart';

// Fase 1 del cobro de servicios: la ESPECIALISTA muestra el QR único del
// negocio y certifica que recibió el pago (el cliente no registra su
// propio pago). Solo se guarda el registro; no toca el estado de la cita.
class CobrarServicioPage extends StatefulWidget {
  final Map<String, dynamic> cita;

  const CobrarServicioPage({super.key, required this.cita});

  @override
  State<CobrarServicioPage> createState() => _CobrarServicioPageState();
}

class _CobrarServicioPageState extends State<CobrarServicioPage> {
  final montoController = TextEditingController();

  String metodoPago = 'QR';
  bool guardando = false;

  late final String idCita;
  // Cacheado: PagosService().streamPago(idCita) crea un Stream nuevo en
  // cada llamada. Si se llamara directo en build(), cada setState() (ej.
  // cambiar el método de pago o confirmar el pago) le pasaría a
  // StreamBuilder una instancia distinta y lo forzaría a
  // desuscribirse/resuscribirse, mostrando el spinner de carga en cada
  // interacción.
  late final Stream<DatabaseEvent> _pagoStream;
  late final Stream<DatabaseEvent> _qrStream;

  @override
  void initState() {
    super.initState();

    idCita = widget.cita['id'] ?? '';
    _pagoStream = PagosService().streamPago(idCita);
    _qrStream = ConfiguracionService().streamQrPago();

    final precio = widget.cita['precioServicio'];
    final precioNum = precio is num
        ? precio.toDouble()
        : double.tryParse(precio?.toString() ?? '') ?? 0.0;

    if (precioNum > 0) {
      montoController.text = precioNum.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    montoController.dispose();
    super.dispose();
  }

  Future<void> confirmarPago() async {
    final monto = double.tryParse(montoController.text.trim());

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el monto recibido'),
        ),
      );
      return;
    }

    final especialista = AuthService().currentUser;

    if (especialista == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu sesión no es válida, vuelve a iniciar sesión'),
        ),
      );
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      await PagosService().confirmarPago(
        citaId: widget.cita['id'] ?? '',
        clienteId: widget.cita['clienteId'] ?? '',
        clienteNombre: widget.cita['clienteNombre'] ?? '',
        especialistaId: especialista.uid,
        especialistaNombre: widget.cita['especialistaNombre'] ?? '',
        servicio: widget.cita['servicio'] ?? '',
        montoDeclarado: monto,
        metodoPago: metodoPago,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago confirmado correctamente'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al confirmar pago: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobrar servicio'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _pagoStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final value = snapshot.data?.snapshot.value;

          if (value != null && value is Map) {
            final pago = Pago.fromMap(idCita, Map<dynamic, dynamic>.from(value));
            return _buildPagoConfirmado(pago);
          }

          return _buildFormulario();
        },
      ),
    );
  }

  Widget _buildPagoConfirmado(Pago pago) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pago ya confirmado para esta cita',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Monto: S/ ${pago.montoDeclarado.toStringAsFixed(0)}'),
              const SizedBox(height: 8),
              Text('Método de pago: ${pago.metodoPago}'),
              const SizedBox(height: 8),
              Text('Confirmado por: ${pago.especialistaNombre.isEmpty ? 'Sin nombre' : pago.especialistaNombre}'),
              const SizedBox(height: 8),
              Text(
                'Fecha y hora: ${formatearFechaHora(DateTime.fromMillisecondsSinceEpoch(pago.fechaHoraMillis))}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                widget.cita['clienteNombre'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                widget.cita['servicio'] ?? '',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              StreamBuilder<DatabaseEvent>(
                stream: _qrStream,
                builder: (context, snapshot) {
                  final url =
                      snapshot.data?.snapshot.value?.toString() ?? '';

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (url.isEmpty) {
                    return const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Text(
                          'El administrador aún no configuró el QR de pago',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(child: Text('No se pudo cargar el QR')),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Muestra este QR al cliente para que realice el pago',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto recibido S/',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: metodoPago,
                decoration: const InputDecoration(
                  labelText: 'Método de pago',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'QR', child: Text('QR')),
                  DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                ],
                onChanged: (value) {
                  setState(() {
                    metodoPago = value ?? 'QR';
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Al confirmar, declaras bajo tu responsabilidad que TÚ, la especialista, '
                'recibiste este pago del cliente. El administrador podrá verificarlo contra '
                'la cuenta bancaria del negocio.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: guardando ? null : confirmarPago,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
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
                      : const Icon(Icons.check),
                  label: Text(
                    guardando ? 'Confirmando...' : 'Confirmar pago recibido',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
