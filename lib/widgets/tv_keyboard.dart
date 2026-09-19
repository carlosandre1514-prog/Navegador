import 'package:flutter/material.dart';

import 'tv_focusable.dart';

/// Teclado na tela para a TV (usado quando o celular não está pareado).
///
/// Cada tecla altera o campo que estiver focado na página web.
class TecladoTv extends StatefulWidget {
  const TecladoTv({
    super.key,
    required this.aoAnexar,
    required this.aoApagar,
    required this.aoEnter,
    required this.aoFechar,
  });

  final void Function(String texto) aoAnexar;
  final VoidCallback aoApagar;
  final VoidCallback aoEnter;
  final VoidCallback aoFechar;

  @override
  State<TecladoTv> createState() => _TecladoTvState();
}

class _TecladoTvState extends State<TecladoTv> {
  static const List<String> _linhas = [
    '1234567890-',
    'qwertyuiop',
    'asdfghjkl@',
    'zxcvbnm._/:',
  ];

  bool _maiusculas = false;

  String _letra(String c) => _maiusculas ? c.toUpperCase() : c;

  Widget _linha(String caracteres, {bool primeira = false}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < caracteres.length; i++)
          _Tecla(
            rotulo: _letra(caracteres[i]),
            autofocus: primeira && i == 0,
            aoPressionar: () => widget.aoAnexar(_letra(caracteres[i])),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _linhas.length; i++) ...[
              _linha(_linhas[i], primeira: i == 0),
              const SizedBox(height: 4),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                _Tecla(
                  rotulo: _maiusculas ? 'abc' : 'ABC',
                  largura: 64,
                  ativa: _maiusculas,
                  aoPressionar: () => setState(() => _maiusculas = !_maiusculas),
                ),
                _Tecla(
                  rotulo: '.com',
                  largura: 64,
                  aoPressionar: () => widget.aoAnexar('.com'),
                ),
                _Tecla(
                  rotulo: 'Espaço',
                  largura: 200,
                  aoPressionar: () => widget.aoAnexar(' '),
                ),
                _Tecla(
                  icone: Icons.backspace_outlined,
                  largura: 64,
                  aoPressionar: widget.aoApagar,
                ),
                _Tecla(
                  icone: Icons.keyboard_return,
                  largura: 64,
                  aoPressionar: widget.aoEnter,
                ),
                _Tecla(
                  icone: Icons.keyboard_hide,
                  largura: 64,
                  aoPressionar: widget.aoFechar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tecla extends StatelessWidget {
  const _Tecla({
    this.rotulo,
    this.icone,
    required this.aoPressionar,
    this.largura = 44,
    this.autofocus = false,
    this.ativa = false,
  });

  final String? rotulo;
  final IconData? icone;
  final VoidCallback aoPressionar;
  final double largura;
  final bool autofocus;
  final bool ativa;

  @override
  Widget build(BuildContext context) {
    final texto = rotulo;
    final simbolo = icone;
    return CaixaFocavel(
      aoPressionar: aoPressionar,
      autofocus: autofocus,
      ativo: ativa,
      minLargura: largura,
      minAltura: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: simbolo != null
          ? Icon(simbolo, size: 22)
          : Text(
              texto ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
    );
  }
}
