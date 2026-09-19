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
    final cores = tema.colorScheme;
    final escuro = tema.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: escuro
                ? [cores.surface, Color.lerp(cores.surface, cores.primary, 0.16)!]
                : [
                    Color.lerp(cores.surface, cores.primaryContainer, 0.35)!,
                    cores.surface,
                  ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricoes) {
              final largo = restricoes.maxWidth >= 680;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Cabecalho(cores: cores),
                        const SizedBox(height: 40),
                        largo
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _CartaoOpcao(
                                      icone: Icons.travel_explore,
                                      titulo: 'Navegar',
                                      descricao:
                                          'Abra o navegador completo neste aparelho, com renderização de desktop.',
                                      destaque: true,
                                      aoPressionar: () => _abrir(
                                        context,
                                        const BrowserScreen(modoTv: false),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _CartaoOpcao(
                                      icone: Icons.settings_remote,
                                      titulo: 'Controle remoto da TV',
                                      descricao:
                                          'Digite o PIN mostrado na TV e use o celular como teclado e comando.',
                                      aoPressionar: () =>
                                          _abrir(context, const RemoteScreen()),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _CartaoOpcao(
                                      icone: Icons.tv,
                                      titulo: 'Modo TV (teste)',
                                      descricao:
                                          'Mostra a interface da TV neste aparelho, com PIN de pareamento.',
                                      aoPressionar: () => _abrir(
                                        context,
                                        const BrowserScreen(modoTv: true),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _CartaoOpcao(
                                    icone: Icons.travel_explore,
                                    titulo: 'Navegar',
                                    descricao:
                                        'Abra o navegador completo neste aparelho, com renderização de desktop.',
                                    destaque: true,
                                    aoPressionar: () => _abrir(
                                      context,
                                      const BrowserScreen(modoTv: false),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _CartaoOpcao(
                                    icone: Icons.settings_remote,
                                    titulo: 'Controle remoto da TV',
                                    descricao:
                                        'Digite o PIN mostrado na TV e use o celular como teclado e comando.',
                                    aoPressionar: () =>
                                        _abrir(context, const RemoteScreen()),
                                  ),
                                  const SizedBox(height: 14),
                                  _CartaoOpcao(
                                    icone: Icons.tv,
                                    titulo: 'Modo TV (teste)',
                                    descricao:
                                        'Mostra a interface da TV neste aparelho, com PIN de pareamento.',
                                    aoPressionar: () => _abrir(
                                      context,
                                      const BrowserScreen(modoTv: true),
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 28),
                        _RodapeDica(cores: cores),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.cores});

  final ColorScheme cores;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cores.primary, cores.tertiary],
            ),
            boxShadow: [
              BoxShadow(
                color: cores.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.public, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          'Meu Navegador Híbrido',
          style: tema.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Um navegador só, pensado para celular e Android TV.',
          style: tema.textTheme.bodyLarge?.copyWith(
            color: cores.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CartaoOpcao extends StatefulWidget {
  const _CartaoOpcao({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.aoPressionar,
    this.destaque = false,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback aoPressionar;
  final bool destaque;

  @override
  State<_CartaoOpcao> createState() => _CartaoOpcaoState();
}

class _CartaoOpcaoState extends State<_CartaoOpcao> {
  bool _foco = false;
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final realcado = _foco || _sobre;

    final corFundo = widget.destaque
        ? cores.primaryContainer.withValues(alpha: realcado ? 1 : 0.9)
        : cores.surface;

    return MouseRegion(
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _foco = v),
        child: InkWell(
          onTap: widget.aoPressionar,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, realcado ? -3 : 0, 0),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: corFundo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: realcado ? cores.primary : cores.outlineVariant,
                width: realcado ? 2 : 1,
              ),
              boxShadow: realcado
                  ? [
                      BoxShadow(
                        color: cores.primary.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: widget.destaque
                        ? Colors.white.withValues(alpha: 0.5)
                        : cores.primaryContainer.withValues(alpha: 0.6),
                  ),
                  child: Icon(widget.icone, color: cores.primary, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.titulo,
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.descricao,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: cores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Abrir',
                      style: tema.textTheme.labelLarge?.copyWith(
                        color: cores.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: cores.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RodapeDica extends StatelessWidget {
  const _RodapeDica({required this.cores});

  final ColorScheme cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cores.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: cores.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Na Android TV o navegador abre direto, sem esta tela — plugue mouse e teclado USB para navegar sem o controle.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cores.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
