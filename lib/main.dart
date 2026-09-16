import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/notificaciones_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // TEMPORAL -- SOLO PARA PROBAR EL WIZARD EN CHROME LOCALMENTE, REVERTIR
  // ANTES DE TERMINAR. activate() no tiene webProvider configurado y en Web
  // lanza sin capturar, lo que aborta el arranque antes de runApp().
  try {
    // Debug en desarrollo (flutter run) -- requiere registrar el token de
    // debug en Firebase Console. Play Integrity en release, válido recién
    // ahora que build.gradle firma con el keystore real
    // (android/upload-keystore.jks) en vez del de debug.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    debugPrint('TEMPORAL testing: App Check activate() falló: $e');
  }

  // No debe poder tirar el arranque de la app si algo sale mal acá --
  // runApp() todavía no se llamó en este punto.
  try {
    await revisarAperturaInicialDesdeNotificacion();
  } catch (e) {
    debugPrint('No se pudo revisar el mensaje inicial de notificación: $e');
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: construirTemaClaro(),
      darkTheme: construirTemaOscuro(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
