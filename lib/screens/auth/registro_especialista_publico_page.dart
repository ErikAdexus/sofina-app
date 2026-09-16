import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/datos_bancarios.dart';
import '../../models/documento_identidad.dart';
import '../../models/especialista_registro.dart';
import '../../services/dni_validacion_service.dart';
import '../../utils/auth_helpers.dart';
import '../../services/especialistas_service.dart';
import '../../widgets/selector_metodo_acceso.dart';
import '../../theme/app_theme.dart';

const _totalPasos = 4;
const _titulosPaso = [
  'Documento de identidad',
  'Datos personales y acceso',
  'Perfil profesional',
  'Datos bancarios',
];

class RegistroEspecialistaPublicoPage extends StatefulWidget {
  const RegistroEspecialistaPublicoPage({super.key});

  @override
  State<RegistroEspecialistaPublicoPage> createState() =>
      _RegistroEspecialistaPublicoPageState();
}

class _RegistroEspecialistaPublicoPageState
    extends State<RegistroEspecialistaPublicoPage> {
  final formKeys = List.generate(_totalPasos, (_) => GlobalKey<FormState>());

  // Paso 1 -- documento de identidad
  TipoDocumentoIdentidad tipoDocumento = TipoDocumentoIdentidad.dni;
  final numeroDocumentoController = TextEditingController();
  final paisOrigenController = TextEditingController();
  PlatformFile? fotoDocumentoAnverso;
  PlatformFile? fotoDocumentoReverso;
  bool verificandoDni = false;
  ResultadoValidacionDni? resultadoValidacionDni;
  // Nombre sugerido por la API del DNI, guardado acá (no directo en
  // nombreController) porque llega mientras el campo de nombre -- que vive
  // en el Paso 2 -- puede no estar montado todavía. Se aplica al
  // controller recién al entrar al Paso 2, y solo si sigue vacío.
  String? nombreAutocompletadoDni;
  Timer? _dniDebounce;

  // Paso 2 -- datos personales y acceso
  final nombreController = TextEditingController();
  final celularController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarPasswordController = TextEditingController();
  String metodoAcceso = 'correo';

  // Paso 3 -- perfil profesional
  final direccionController = TextEditingController();
  final experienciaController = TextEditingController();
  final especialidadController = TextEditingController();
  PlatformFile? fotoSeleccionada;
  PlatformFile? pdfSeleccionado;

  // Paso 4 -- datos bancarios
  BancoEspecialista banco = BancoEspecialista.bcp;
  final bancoOtroNombreController = TextEditingController();
  final numeroCuentaController = TextEditingController();
  final cciController = TextEditingController();
  bool declaracionTitularidad = false;

  int currentStep = 0;
  bool guardando = false;
  bool ocultarPassword = true;
  bool ocultarConfirmarPassword = true;

  Future<void> seleccionarImagen(ValueChanged<PlatformFile> onSeleccionada) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (resultado != null && resultado.files.isNotEmpty) {
      setState(() {
        onSeleccionada(resultado.files.single);
      });
    }
  }

  Future<void> seleccionarPdf() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (resultado != null && resultado.files.isNotEmpty) {
      setState(() {
        pdfSeleccionado = resultado.files.single;
      });
    }
  }

  void mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Dispara la verificación best-effort apenas el número de DNI tiene 8
  // dígitos válidos, sin esperar a que se presione Continuar -- con un
  // pequeño debounce para no disparar en cada tecla mientras se sigue
  // editando. Nunca gatea la navegación (ver _construirBarraNavegacion,
  // que no depende de esto para habilitar Continuar).
  void _onNumeroDocumentoCambiado(String value) {
    _dniDebounce?.cancel();

    if (tipoDocumento != TipoDocumentoIdentidad.dni) return;

    final texto = value.trim();
    if (!formatoDni.hasMatch(texto)) return;

    _dniDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // El usuario pudo seguir editando durante el debounce -- solo
      // dispara si el número sigue siendo el mismo que completó los 8
      // dígitos.
      if (numeroDocumentoController.text.trim() != texto) return;
      _dispararValidacionDni(texto);
    });
  }

  Future<void> _dispararValidacionDni(String numero) async {
    setState(() => verificandoDni = true);

    final resultado = await DniValidacionService().validar(numero: numero);

    if (!mounted) return;

    setState(() {
      resultadoValidacionDni = resultado;
      verificandoDni = false;
    });

    if (resultado.nombreSugerido != null && resultado.nombreSugerido!.isNotEmpty) {
      nombreAutocompletadoDni = resultado.nombreSugerido;
      _aplicarNombreAutocompletadoSiVacio();
    }
  }

  // Solo pisa el campo de nombre si sigue vacío en este momento -- si la
  // especialista ya avanzó al Paso 2 y escribió su nombre a mano antes de
  // que la API respondiera, lo que ella escribió queda intacto.
  void _aplicarNombreAutocompletadoSiVacio() {
    final sugerido = nombreAutocompletadoDni;
    if (sugerido != null &&
        sugerido.isNotEmpty &&
        nombreController.text.trim().isEmpty) {
      nombreController.text = sugerido;
    }
  }

  bool validarPasoDocumento() {
    if (!formKeys[0].currentState!.validate()) return false;

    if (fotoDocumentoAnverso == null) {
      mostrarError('Debe seleccionar la foto del anverso del documento');
      return false;
    }

    if (fotoDocumentoReverso == null) {
      mostrarError('Debe seleccionar la foto del reverso del documento');
      return false;
    }

    return true;
  }

  bool validarPasoDatosPersonales() {
    if (!formKeys[1].currentState!.validate()) return false;

    if (passwordController.text.trim() !=
        confirmarPasswordController.text.trim()) {
      mostrarError('Las contraseñas no coinciden');
      return false;
    }

    return true;
  }

  bool validarPasoPerfil() {
    if (!formKeys[2].currentState!.validate()) return false;

    if (fotoSeleccionada == null) {
      mostrarError('Debe seleccionar una foto de perfil');
      return false;
    }

    if (pdfSeleccionado == null) {
      mostrarError('Debe seleccionar sus antecedentes o certificado PDF');
      return false;
    }

    return true;
  }

  bool validarPasoBancario() {
    if (!formKeys[3].currentState!.validate()) return false;

    if (!declaracionTitularidad) {
      mostrarError('Debe declarar que la cuenta bancaria es de su titularidad');
      return false;
    }

    return true;
  }

  void irAPasoSiguiente() {
    final valido = switch (currentStep) {
      0 => validarPasoDocumento(),
      1 => validarPasoDatosPersonales(),
      2 => validarPasoPerfil(),
      _ => true,
    };

    if (!valido) return;

    setState(() => currentStep++);

    // No-op si no hay nombre sugerido pendiente o si ya se aplicó antes.
    _aplicarNombreAutocompletadoSiVacio();
  }

  void irAPasoAnterior() {
    setState(() => currentStep--);
  }

  Future<void> enviarPostulacion() async {
    if (!validarPasoBancario()) return;

    try {
      setState(() => guardando = true);

      final datos = EspecialistaRegistro(
        metodoAcceso: metodoAcceso,
        nombre: nombreController.text.trim(),
        celular: celularController.text.trim(),
        correo: correoController.text.trim(),
        password: passwordController.text.trim(),
        direccion: direccionController.text.trim(),
        experiencia: experienciaController.text.trim(),
        especialidad: especialidadController.text.trim(),
        foto: fotoSeleccionada!,
        pdfCertificado: pdfSeleccionado!,
        tipoDocumento: tipoDocumento,
        numeroDocumento: numeroDocumentoController.text.trim(),
        paisOrigen: tipoDocumento == TipoDocumentoIdentidad.carnetExtranjeria
            ? paisOrigenController.text.trim()
            : null,
        fotoDocumentoAnverso: fotoDocumentoAnverso!,
        fotoDocumentoReverso: fotoDocumentoReverso!,
        validacionDni: resultadoValidacionDni,
        banco: banco,
        bancoOtroNombre: banco == BancoEspecialista.otro
            ? bancoOtroNombreController.text.trim()
            : null,
        numeroCuenta: numeroCuentaController.text.trim(),
        cci: cciController.text.trim(),
        declaracionTitularidad: declaracionTitularidad,
      );

      await EspecialistasService().registrarPostulacion(datos);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Postulación registrada. Quedará pendiente de aprobación.'),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorAuth(e, metodoAcceso: metodoAcceso)),
        ),
      );
    } on FirebaseException catch (e) {
      // TEMPORAL debug -- FirebaseException (Storage, RTDB, etc.) trae code y
      // message reales; el mensaje genérico de abajo los tapaba. Ver consola
      // para el code exacto (ej. storage/unauthorized) en vez de "unknown".
      debugPrint(
        'Error al registrar postulación [${e.plugin}/${e.code}]: ${e.message}',
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al registrar postulación [${e.plugin}/${e.code}]: ${e.message ?? e.toString()}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar postulación: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => guardando = false);
      }
    }
  }

  @override
  void dispose() {
    _dniDebounce?.cancel();
    numeroDocumentoController.dispose();
    paisOrigenController.dispose();
    nombreController.dispose();
    celularController.dispose();
    correoController.dispose();
    passwordController.dispose();
    confirmarPasswordController.dispose();
    direccionController.dispose();
    experienciaController.dispose();
    especialidadController.dispose();
    bancoOtroNombreController.dispose();
    numeroCuentaController.dispose();
    cciController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primarioOscuro =
        Theme.of(context).extension<SofinaColors>()!.primaryDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Paso ${currentStep + 1} de $_totalPasos · ${_titulosPaso[currentStep]}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Row(
            children: List.generate(_totalPasos, (indice) {
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    left: indice == 0 ? 0 : 1,
                    right: indice == _totalPasos - 1 ? 0 : 1,
                  ),
                  color: indice <= currentStep
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                ),
              );
            }),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (currentStep == 0) ...[
                  Icon(Icons.spa, size: 72, color: primarioOscuro),
                  const SizedBox(height: 16),
                  Text(
                    'Solicitud de especialista',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primarioOscuro,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu postulación será revisada por el administrador antes de activar tu acceso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                ],
                _construirPasoActual(),
                const SizedBox(height: 24),
                _construirBarraNavegacion(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirPasoActual() {
    return switch (currentStep) {
      0 => Form(key: formKeys[0], child: _construirPasoDocumento()),
      1 => Form(key: formKeys[1], child: _construirPasoDatosPersonales()),
      2 => Form(key: formKeys[2], child: _construirPasoPerfil()),
      _ => Form(key: formKeys[3], child: _construirPasoBancario()),
    };
  }

  Widget _construirBarraNavegacion() {
    final esUltimoPaso = currentStep == _totalPasos - 1;
    final procesando = guardando;

    return Row(
      children: [
        if (currentStep > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: procesando ? null : irAPasoAnterior,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Atrás'),
            ),
          ),
        if (currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: procesando
                ? null
                : (esUltimoPaso ? enviarPostulacion : irAPasoSiguiente),
            icon: procesando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(esUltimoPaso ? Icons.send : Icons.arrow_forward),
            label: Text(
              guardando
                  ? 'Registrando postulación...'
                  : (esUltimoPaso ? 'Enviar postulación' : 'Continuar'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirPasoDocumento() {
    final esCarnet = tipoDocumento == TipoDocumentoIdentidad.carnetExtranjeria;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _botonTipoDocumento(
                tipo: TipoDocumentoIdentidad.dni,
                icono: Icons.badge,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _botonTipoDocumento(
                tipo: TipoDocumentoIdentidad.carnetExtranjeria,
                icono: Icons.travel_explore,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: numeroDocumentoController,
          keyboardType: TextInputType.text,
          inputFormatters: esCarnet
              ? [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(15),
                ]
              : [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
          decoration: InputDecoration(
            labelText: esCarnet ? 'Número de carné' : 'Número de DNI',
            prefixIcon: const Icon(Icons.numbers),
            border: const OutlineInputBorder(),
          ),
          onChanged: _onNumeroDocumentoCambiado,
          validator: (value) {
            final texto = value?.trim() ?? '';

            if (texto.isEmpty) {
              return esCarnet
                  ? 'Ingrese el número de carné'
                  : 'Ingrese el número de DNI';
            }

            if (!esCarnet && !formatoDni.hasMatch(texto)) {
              return 'El DNI debe tener 8 dígitos numéricos';
            }

            if (esCarnet && !formatoCarnetExtranjeria.hasMatch(texto)) {
              return 'El carné debe ser alfanumérico (6 a 15 caracteres)';
            }

            return null;
          },
        ),
        if (!esCarnet && verificandoDni) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Verificando documento...',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
        if (esCarnet) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: paisOrigenController,
            decoration: const InputDecoration(
              labelText: 'País de origen',
              prefixIcon: Icon(Icons.public),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese el país de origen';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () => seleccionarImagen(
                      (archivo) => fotoDocumentoAnverso = archivo,
                    ),
            icon: const Icon(Icons.credit_card),
            label: Text(
              fotoDocumentoAnverso == null
                  ? 'Foto del documento (anverso)'
                  : 'Anverso: ${fotoDocumentoAnverso!.name}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () => seleccionarImagen(
                      (archivo) => fotoDocumentoReverso = archivo,
                    ),
            icon: const Icon(Icons.credit_card),
            label: Text(
              fotoDocumentoReverso == null
                  ? 'Foto del documento (reverso)'
                  : 'Reverso: ${fotoDocumentoReverso!.name}',
            ),
          ),
        ),
        if (resultadoValidacionDni != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resultadoValidacionDni!.mensaje,
                    style: TextStyle(color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _botonTipoDocumento({
    required TipoDocumentoIdentidad tipo,
    required IconData icono,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final primarioOscuro =
        Theme.of(context).extension<SofinaColors>()!.primaryDark;
    final seleccionado = tipoDocumento == tipo;

    return OutlinedButton.icon(
      onPressed: () => setState(() => tipoDocumento = tipo),
      style: OutlinedButton.styleFrom(
        backgroundColor: seleccionado ? colorScheme.primary : Colors.white,
        foregroundColor: seleccionado ? colorScheme.onPrimary : primarioOscuro,
        side: BorderSide(color: colorScheme.primary),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icono),
      label: Text(tipo.etiqueta),
    );
  }

  Widget _construirPasoDatosPersonales() {
    return Column(
      children: [
        SelectorMetodoAcceso(
          metodoSeleccionado: metodoAcceso,
          onChanged: (valor) => setState(() => metodoAcceso = valor),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese el nombre completo';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: celularController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Celular',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese el celular';
            }
            if (value.trim().length < 9) {
              return 'El celular debe tener mínimo 9 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: correoController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: metodoAcceso == 'telefono'
                ? 'Correo de acceso (opcional)'
                : 'Correo de acceso',
            prefixIcon: const Icon(Icons.email),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final texto = value?.trim() ?? '';

            if (metodoAcceso == 'correo') {
              if (texto.isEmpty) {
                return 'Ingrese el correo';
              }
              if (!texto.contains('@')) {
                return 'Ingrese un correo válido';
              }
              return null;
            }

            if (texto.isNotEmpty && !texto.contains('@')) {
              return 'Ingrese un correo válido';
            }

            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          obscureText: ocultarPassword,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                ocultarPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => ocultarPassword = !ocultarPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese la contraseña';
            }
            if (value.trim().length < 6) {
              return 'La contraseña debe tener mínimo 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: confirmarPasswordController,
          obscureText: ocultarConfirmarPassword,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                ocultarConfirmarPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: () => setState(
                () => ocultarConfirmarPassword = !ocultarConfirmarPassword,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Confirme la contraseña';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _construirPasoPerfil() {
    return Column(
      children: [
        TextFormField(
          controller: direccionController,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese la dirección';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: experienciaController,
          decoration: const InputDecoration(
            labelText: 'Experiencia',
            prefixIcon: Icon(Icons.work),
            border: OutlineInputBorder(),
            hintText: 'Ejemplo: 2 años',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese la experiencia';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: especialidadController,
          decoration: const InputDecoration(
            labelText: 'Especialidad',
            prefixIcon: Icon(Icons.brush),
            border: OutlineInputBorder(),
            hintText: 'Ejemplo: manicure, pedicure, acrílicas',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese la especialidad';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () => seleccionarImagen((archivo) => fotoSeleccionada = archivo),
            icon: const Icon(Icons.image),
            label: Text(
              fotoSeleccionada == null
                  ? 'Seleccionar foto de perfil'
                  : 'Foto: ${fotoSeleccionada!.name}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: guardando ? null : seleccionarPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(
              pdfSeleccionado == null
                  ? 'Seleccionar antecedentes o certificado PDF'
                  : 'PDF: ${pdfSeleccionado!.name}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirPasoBancario() {
    return Column(
      children: [
        DropdownButtonFormField<BancoEspecialista>(
          initialValue: banco,
          decoration: const InputDecoration(
            labelText: 'Banco',
            prefixIcon: Icon(Icons.account_balance),
            border: OutlineInputBorder(),
          ),
          items: BancoEspecialista.values
              .map(
                (valor) => DropdownMenuItem(
                  value: valor,
                  child: Text(valor.etiqueta),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(() => banco = valor!),
        ),
        if (banco == BancoEspecialista.otro) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: bancoOtroNombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre del banco',
              prefixIcon: Icon(Icons.edit),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese el nombre del banco';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Moneda',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Icon(Icons.payments, color: Colors.black54),
              SizedBox(width: 12),
              Text('S/ (Soles)'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: numeroCuentaController,
          decoration: const InputDecoration(
            labelText: 'Número de cuenta',
            prefixIcon: Icon(Icons.credit_card),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingrese el número de cuenta';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: cciController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(20),
          ],
          decoration: const InputDecoration(
            labelText: 'CCI',
            prefixIcon: Icon(Icons.pin),
            border: OutlineInputBorder(),
            hintText: '20 dígitos',
          ),
          validator: (value) {
            final texto = value?.trim() ?? '';

            if (texto.isEmpty) {
              return 'Ingrese el CCI';
            }

            if (!formatoCci.hasMatch(texto)) {
              return 'El CCI debe tener exactamente 20 dígitos numéricos';
            }

            return null;
          },
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: declaracionTitularidad,
          onChanged: (valor) =>
              setState(() => declaracionTitularidad = valor ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Declaro que la cuenta bancaria es de mi titularidad',
          ),
        ),
      ],
    );
  }
}
