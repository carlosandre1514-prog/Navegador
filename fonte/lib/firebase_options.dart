import 'package:firebase_core/firebase_core.dart';

/// Configuração do Firebase.
///
/// Preencha com os dados do seu projeto (Console do Firebase ->
/// Configurações do projeto -> Seus apps -> app Android). Veja o README.md.
///
/// Enquanto os valores abaixo começarem com "COLE_AQUI", o navegador funciona
/// normalmente, mas o pareamento celular <-> TV fica desativado.
class FirebaseConfig {
  FirebaseConfig._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'COLE_AQUI_API_KEY', // "current_key" no google-services.json
    appId: 'COLE_AQUI_APP_ID', // "mobilesdk_app_id" no google-services.json
    messagingSenderId: 'COLE_AQUI_NUMERO', // "project_number"
    projectId: 'COLE_AQUI_PROJECT_ID', // "project_id"
    databaseURL: 'https://COLE_AQUI-default-rtdb.firebaseio.com',
  );

  static bool get configurado =>
      !android.apiKey.startsWith('COLE_AQUI') &&
      !android.appId.startsWith('COLE_AQUI') &&
      !android.projectId.startsWith('COLE_AQUI');
}
