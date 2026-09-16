import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class AuthService {
  Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<UserCredential> iniciarSesion({
    required String credencial,
    required String password,
  }) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: credencial,
      password: password,
    );
  }

  Future<UserCredential> registrarUsuario({
    required String credencial,
    required String password,
  }) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: credencial,
      password: password,
    );
  }

  Future<void> cerrarSesion() {
    return FirebaseAuth.instance.signOut();
  }

  // Crea un usuario de acceso en una instancia secundaria de Firebase Auth,
  // para no cerrar la sesión del administrador que está creando la cuenta.
  Future<String> crearUsuarioAuthSecundario({
    required String credencial,
    required String password,
  }) async {
    const secondaryAppName = 'SecondaryAuthApp';

    FirebaseApp secondaryApp;

    try {
      secondaryApp = Firebase.app(secondaryAppName);
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    final credential = await secondaryAuth.createUserWithEmailAndPassword(
      email: credencial.trim(),
      password: password.trim(),
    );

    final uid = credential.user?.uid;

    if (uid == null) {
      throw Exception('No se pudo obtener el UID del usuario creado');
    }

    await secondaryAuth.signOut();

    return uid;
  }
}
