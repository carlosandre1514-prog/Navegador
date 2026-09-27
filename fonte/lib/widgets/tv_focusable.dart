import 'package:flutter/material.dart';

/// Caixa clicável com indicador de foco BEM visível (borda grossa).
///
/// Serve para toque, mouse e navegação por setas do controle remoto da TV
/// (Enter/OK aciona [aoPressionar]).
class CaixaFocavel extends StatefulWidget {
  const CaixaFocavel({
    super.key,
    required this.child,
    required this.aoPressionar,
    this.dica,
    this.ativo = false,
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.minLargura = 0,
    this.minAltura = 0,
  });

  final Widget child;
  final VoidCallback aoPressionar;
  final String? dica;
  final bool ativo;
  final bool autofocus;
  final EdgeInsetsGeometry padding;
  final double minLargura;
  final double minAltura;

  @override
  State<CaixaFocavel> createState() => _CaixaFocavelState();
}

class _CaixaFocavelState extends State<CaixaFocavel> {
  bool _focado = false;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    Widget corpo = InkWell(
      onTap: widget.aoPressionar,
      autofocus: widget.autofocus,
      borderRadius: BorderRadius.circular(12),
      onFocusChange: (valor) => setState(() => _focado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: BoxConstraints(
          minWidth: widget.minLargura,
          minHeight: widget.minAltura,
        ),
        padding: widget.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.ativo
              ? cores.primaryContainer
              : (_focado ? cores.surfaceContainerHighest : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focado ? cores.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: widget.child,
      ),
    );

    final dica = widget.dica;
    if (dica != null) {
      corpo = Tooltip(message: dica, child: corpo);
    }
    return corpo;
  }
}

/// Botão da barra do navegador: ícone + rótulo opcional.
class BotaoBarra extends StatelessWidget {
  const BotaoBarra({
    super.key,
    required this.icone,
    required this.dica,
    required this.aoPressionar,
    this.rotulo,
    this.ativo = false,
    this.autofocus = false,
  });

  final IconData icone;
  final String dica;
  final VoidCallback aoPressionar;
  final String? rotulo;
  final bool ativo;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final texto = rotulo;
    return CaixaFocavel(
      dica: dica,
      ativo: ativo,
      autofocus: autofocus,
      aoPressionar: aoPressionar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 26),
          if (texto != null) ...[
            const SizedBox(width: 6),
            Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
