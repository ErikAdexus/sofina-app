import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/formatters.dart';
import '../../utils/auth_helpers.dart';
import '../../services/auth_service.dart';
import '../../widgets/logo_sofina.dart';
import '../../widgets/selector_metodo_acceso.dart';
import '../../theme/app_theme.dart';
import 'registro_especialista_publico_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();

  final identificadorController = TextEditingController();
  final passwordController = TextEditingController();

  String metodoAcceso = 'correo';

  bool cargando = false;
  bool ocultarPassword = true;

  Future<void> iniciarSesion() async {
    if (!formKey.currentState!.validate()) return;

    try {
      setState(() {
        cargando = true;
      });

      final credencial = obtenerCredencialAcceso(
        metodoAcceso: metodoAcceso,
        correo: metodoAcceso == 'correo' ? identificadorController.text : '',
        telefono: metodoAcceso == 'telefono' ? identificadorController.text : '',
      );

      await AuthService().iniciarSesion(
        credencial: credencial,
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      String mensaje = metodoAcceso == 'telefono'
          ? 'Celular o contraseña incorrectos'
          : 'Correo o contraseña incorrectos';

      if (e.code == 'invalid-email') {
        mensaje = metodoAcceso == 'telefono'
            ? 'Número de celular inválido'
            : 'Correo inválido';
      } else if (e.code == 'user-not-found') {
        mensaje = metodoAcceso == 'telefono'
            ? 'No existe un usuario con ese celular'
            : 'No existe un usuario con ese correo';
      } else if (e.code == 'wrong-password') {
        mensaje = 'Contraseña incorrecta';
      } else if (e.code == 'invalid-credential') {
        mensaje = metodoAcceso == 'telefono'
            ? 'Celular o contraseña incorrectos'
            : 'Correo o contraseña incorrectos';
      } else if (e.code == 'network-request-failed') {
        mensaje = 'Sin conexión a internet';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  void abrirRegistroEspecialista() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistroEspecialistaPublicoPage(),
      ),
    );
  }

  @override
  void dispose() {
    identificadorController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoSofina(size: 90),
                    const SizedBox(height: 20),
                    Text(
                      'Ingreso de usuarios',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .extension<SofinaColors>()!
                            .primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa como especialista o administrador.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SelectorMetodoAcceso(
                      metodoSeleccionado: metodoAcceso,
                      onChanged: (valor) {
                        setState(() {
                          metodoAcceso = valor;
                          identificadorController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: identificadorController,
                      keyboardType: metodoAcceso == 'telefono'
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: metodoAcceso == 'telefono' ? 'Celular' : 'Correo',
                        prefixIcon: Icon(
                          metodoAcceso == 'telefono' ? Icons.phone_android : Icons.email,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final texto = value?.trim() ?? '';

                        if (texto.isEmpty) {
                          return metodoAcceso == 'telefono'
                              ? 'Ingrese el número de celular'
                              : 'Ingrese el correo';
                        }

                        if (metodoAcceso == 'correo') {
                          if (!texto.contains('@')) {
                            return 'Ingrese un correo válido';
                          }
                        } else {
                          if (limpiarTelefono(texto).length < 9) {
                            return 'El celular debe tener mínimo 9 dígitos';
                          }
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
                            ocultarPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              ocultarPassword = !ocultarPassword;
                            });
                          },
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: cargando ? null : iniciarSesion,
                        icon: cargando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          cargando ? 'Ingresando...' : 'Ingresar',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: abrirRegistroEspecialista,
                      child: const Text('Postular como especialista'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
