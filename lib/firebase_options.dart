import 'package:firebase_core/firebase_core.dart';

/// Configuração do Firebase.
///
/// Preenchido com os dados do projeto navegador-f06a8.
class FirebaseConfig {
  FirebaseConfig._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGCTp0oE1F5WkWmfrEGVckvlaaDEzQh-8',
    appId: '1:55916264760:android:3c0d9deab822d0806a15cd',
    messagingSenderId: '55916264760',
    projectId: 'navegador-f06a8',
    databaseURL: 'https://navegador-f06a8-default-rtdb.firebaseio.com',
    storageBucket: 'navegador-f06a8.firebasestorage.app',
  );

  static bool get configurado =>
      !android.apiKey.startsWith('COLE_AQUI') &&
      !android.appId.startsWith('COLE_AQUI') &&
      !android.projectId.startsWith('COLE_AQUI');
}
