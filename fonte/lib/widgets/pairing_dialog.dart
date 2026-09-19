import 'package:flutter/material.dart';

import '../services/pairing_service.dart';

/// Formata "483920" como "483 920".
String formatarPin(String pin) {
  if (pin.length != 6) return pin;
  return '${pin.substring(0, 3)} ${pin.substring(3)}';
}

/// Janela que mostra o PIN da TV e o estado do pareamento.
Future<void> mostrarDialogoPareamento(BuildContext context, SessaoTv sessao) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogoPareamento(sessao: sessao),
  );
}

class _DialogoPareamento extends StatelessWidget {
  const _DialogoPareamento({required this.sessao});

  final SessaoTv sessao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        sessao.pin,
        sessao.celularConectado,
        sessao.erro,
      ]),
      builder: (context, _) {
        final pin = sessao.pin.value;
        final conectado = sessao.celularConectado.value;
        final erro = sessao.erro.value;

        return AlertDialog(
          title: const Text('Parear com o celular'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No celular, abra o app, escolha "Controle remoto" e '
                  'digite o PIN abaixo.',
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    pin == null ? '------' : formatarPin(pin),
                    style: tema.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      conectado ? Icons.check_circle : Icons.hourglass_top,
                      color: conectado ? Colors.greenAccent : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conectado
                            ? 'Celular conectado!'
                            : (pin == null
                                ? 'Sem sessão ativa.'
                                : 'Aguardando o celular...'),
                      ),
                    ),
                  ],
                ),
                if (erro != null) ...[
                  const SizedBox(height: 12),
                  Text(erro, style: TextStyle(color: tema.colorScheme.error)),
                ],
                const SizedBox(height: 8),
                Text(
                  'O PIN vale enquanto o navegador estiver aberto e só aceita '
                  'um celular por vez.',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => sessao.iniciar(),
              child: const Text('Novo PIN'),
            ),
            if (conectado)
              TextButton(
                onPressed: () => sessao.desconectarCelular(),
                child: const Text('Desconectar celular'),
              ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
