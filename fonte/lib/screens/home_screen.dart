import 'package:flutter/material.dart';

import 'browser_screen.dart';
import 'remote_screen.dart';

/// Tela inicial do celular: navegar ou usar o celular como controle da TV.
/// (Na Android TV o app abre direto no navegador.)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _abrir(BuildContext context, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                Icon(Icons.public, size: 72, color: tema.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Meu Navegador Híbrido',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineMedium,
                ),
                const SizedBox(height: 28),
                _Opcao(
                  icone: Icons.language,
                  titulo: 'Navegar',
                  descricao: 'Abrir o navegador neste aparelho.',
                  aoPressionar: () =>
                      _abrir(context, const BrowserScreen(modoTv: false)),
                ),
                const SizedBox(height: 12),
                _Opcao(
                  icone: Icons.settings_remote,
                  titulo: 'Controle remoto da TV',
                  descricao:
                      'Digite o PIN mostrado na TV e use o celular como teclado.',
                  aoPressionar: () => _abrir(context, const RemoteScreen()),
                ),
                const SizedBox(height: 12),
                _Opcao(
                  icone: Icons.tv,
                  titulo: 'Abrir em modo TV (teste)',
                  descricao:
                      'Mostra a interface da TV neste aparelho, com PIN de pareamento.',
                  aoPressionar: () =>
                      _abrir(context, const BrowserScreen(modoTv: true)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.aoPressionar,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback aoPressionar;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(icone, size: 34),
        title: Text(titulo),
        subtitle: Text(descricao),
        trailing: const Icon(Icons.chevron_right),
        onTap: aoPressionar,
      ),
    );
  }
}
