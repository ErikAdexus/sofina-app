import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'constants.dart';

DatabaseReference dbRef(String path) {
  return FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: realtimeDatabaseUrl,
  ).ref(path);
}
