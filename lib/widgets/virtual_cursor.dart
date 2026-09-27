import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cursor virtual para quem só tem o controle remoto comum (setas + OK).
///
/// Enquanto está ativo, ele captura as setas e o OK:
///   - setas movem o cursor (segurar acelera);
///   - OK clica na posição do cursor;
///   - empurrar contra a borda de cima/baixo rola a página.
/// Quem usa mouse USB/Bluetooth NÃO precisa disso: o WebView já aceita mouse.
class VirtualCursor extends StatefulWidget {
  const VirtualCursor({
    super.key,
    required this.aoClicar,
    required this.aoRolar,
  });

  /// Recebe a posição como fração da área do WebView (0.0 a 1.0).
  final void Function(double fx, double fy) aoClicar;
  final void Function(int dy) aoRolar;

  @override
  State<VirtualCursor> createState() => _VirtualCursorState();
}

class _VirtualCursorState extends State<VirtualCursor> {
  final FocusNode _foco = FocusNode(debugLabel: 'cursor-virtual');
  Offset? _pos;
  Size _tamanho = Size.zero;
  int _repeticoes = 0;

  @override
  void initState() {
    super.initState();
    _foco.addListener(_recuperarFoco);
  }

  @override
  void dispose() {
    _foco.removeListener(_recuperarFoco);
    _foco.dispose();
    super.dispose();
  }

  /// O WebView nativo às vezes "rouba" o foco. Se isso acontecer, pede de volta,
  /// exceto quando o usuário foi para um campo de texto ou abriu uma janela.
  void _recuperarFoco() {
    if (_foco.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _foco.hasFocus) return;
      final rota = ModalRoute.of(context);
      if (rota == null || !rota.isCurrent) return;
      final contexto = FocusManager.instance.primaryFocus?.context;
      final emCampoDeTexto =
          contexto?.findAncestorWidgetOfExactType<EditableText>() != null;
      if (!emCampoDeTexto) _foco.requestFocus();
    });
  }

  Offset? _direcao(LogicalKeyboardKey tecla) {
    if (tecla == LogicalKeyboardKey.arrowLeft) return const Offset(-1, 0);
    if (tecla == LogicalKeyboardKey.arrowRight) return const Offset(1, 0);
    if (tecla == LogicalKeyboardKey.arrowUp) return const Offset(0, -1);
    if (tecla == LogicalKeyboardKey.arrowDown) return const Offset(0, 1);
    return null;
  }

  KeyEventResult _aoTecla(FocusNode node, KeyEvent evento) {
    final tecla = evento.logicalKey;
    final pos = _pos;
    if (pos == null || _tamanho.isEmpty) return KeyEventResult.ignored;

    final ehSelecionar = tecla == LogicalKeyboardKey.select ||
        tecla == LogicalKeyboardKey.enter ||
        tecla == LogicalKeyboardKey.numpadEnter ||
        tecla == LogicalKeyboardKey.gameButtonA;

    if (ehSelecionar) {
      if (evento is KeyDownEvent) {
        widget.aoClicar(pos.dx / _tamanho.width, pos.dy / _tamanho.height);
      }
      return KeyEventResult.handled;
    }

    final direcao = _direcao(tecla);
    if (direcao == null) return KeyEventResult.ignored;
    if (evento is KeyUpEvent) return KeyEventResult.handled;

    _repeticoes = evento is KeyRepeatEvent ? _repeticoes + 1 : 0;
    final passo = 10.0 + (_repeticoes * 2).clamp(0, 40);

    // Já estava na borda e continuou empurrando: rola a página.
    if (direcao.dy < 0 && pos.dy <= 1) widget.aoRolar(-160);
    if (direcao.dy > 0 && pos.dy >= _tamanho.height - 1) widget.aoRolar(160);

    final x = (pos.dx + direcao.dx * passo).clamp(0.0, _tamanho.width).toDouble();
    final y = (pos.dy + direcao.dy * passo).clamp(0.0, _tamanho.height).toDouble();
    setState(() => _pos = Offset(x, y));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        _tamanho = Size(restricoes.maxWidth, restricoes.maxHeight);
        _pos ??= Offset(_tamanho.width / 2, _tamanho.height / 2);

        return Focus(
          focusNode: _foco,
          autofocus: true,
          onKeyEvent: _aoTecla,
          // IgnorePointer: mouse e toque continuam chegando ao WebView.
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _PintorCursor(_pos!)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Modo cursor · setas movem · OK clica · Voltar sai',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PintorCursor extends CustomPainter {
  _PintorCursor(this.pos);

  final Offset pos;

  @override
  void paint(Canvas canvas, Size size) {
    final caminho = Path()
      ..moveTo(pos.dx, pos.dy)
      ..lineTo(pos.dx, pos.dy + 22)
      ..lineTo(pos.dx + 5, pos.dy + 17)
      ..lineTo(pos.dx + 9, pos.dy + 26)
      ..lineTo(pos.dx + 13, pos.dy + 24)
      ..lineTo(pos.dx + 9, pos.dy + 16)
      ..lineTo(pos.dx + 16, pos.dy + 16)
      ..close();

    canvas.drawPath(caminho, Paint()..color = Colors.white);
    canvas.drawPath(
      caminho,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorCursor antigo) => antigo.pos != pos;
}
