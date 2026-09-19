import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/device_mode.dart';
import 'screens/browser_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ehTv = await DeviceMode.ehAndroidTv();
  runApp(NavegadorApp(ehTv: ehTv));
}

class NavegadorApp extends StatelessWidget {
  const NavegadorApp({super.key, required this.ehTv});

  /// true quando o app está rodando em uma Android TV.
  final bool ehTv;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Navegador Híbrido',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7DFF),
          brightness: Brightness.dark,
        ),
      ),
      // Garante que o botão OK/Select do controle remoto acione botões.
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      // Na TV abre direto no navegador; no celular, no menu inicial.
      home: ehTv ? const BrowserScreen(modoTv: true) : const HomeScreen(),
    );
  }
}
