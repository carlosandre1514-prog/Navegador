import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pairing_service.dart';

/// O celular vira teclado e controle remoto da TV.
class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  final ControleRemoto _controle = ControleRemoto();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _textoCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();

  Timer? _debounce;
  bool _conectando = false;
  String? _erroPin;

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_controle.encerrar());
    _pinCtrl.dispose();
    _textoCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _conectar() async {
    if (_conectando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _conectando = true;
      _erroPin = null;
    });
    final erro = await _controle.conectar(_pinCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _conectando = false;
      _erroPin = erro;
    });
    if (erro == null) {
      _textoCtrl.clear();
      _urlCtrl.clear();
    }
  }

  Future<void> _executar(Future<String?> Function() envio) async {
    final erro = await envio();
    if (erro != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  /// O que você digita aqui aparece na hora no campo selecionado na TV.
  void _aoDigitar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(_executar(() => _controle.enviarTexto(texto))),
    );
  }

  void _limpar() {
    _debounce?.cancel();
    _textoCtrl.clear();
    unawaited(_executar(() => _controle.enviarTexto('')));
  }

  void _abrirUrl(String valor) {
    final url = valor.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    unawaited(_executar(() => _controle.enviarUrl(url)));
  }

  void _acao(AcaoRemota acao) {
    unawaited(_executar(() => _controle.enviarAcao(acao)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controle.ativa,
      builder: (context, ativa, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Controle remoto'),
            actions: [
              if (ativa)
                TextButton.icon(
                  onPressed: () => unawaited(_controle.encerrar()),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Desconectar'),
                ),
            ],
          ),
          body: SafeArea(child: ativa ? _painelControle() : _telaPin()),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Fase 1: digitar o PIN
  // ---------------------------------------------------------------------------

  Widget _telaPin() {
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: _controle.aviso,
      builder: (context, _) {
        final mensagem = _erroPin ?? _controle.aviso.value;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.tv, size: 64, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Digite o PIN que aparece na TV',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Na TV: botão "PIN" na barra do navegador.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: tema.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
              onChanged: (_) {
                if (_erroPin != null) setState(() => _erroPin = null);
              },
              onSubmitted: (_) => unawaited(_conectar()),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '000000',
                counterText: '',
              ),
            ),
            if (mensagem != null) ...[
              const SizedBox(height: 12),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _conectando ? null : () => unawaited(_conectar()),
              icon: _conectando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(_conectando ? 'Conectando...' : 'Conectar'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Fase 2: controlar a TV
  // ---------------------------------------------------------------------------

  Widget _painelControle() {
    final tema = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.tv),
            title: Text('Conectado · PIN ${_controle.pin ?? ''}'),
            subtitle: ValueListenableBuilder<String>(
              valueListenable: _controle.urlDaTv,
              builder: (context, url, _) => Text(
                url.isEmpty ? 'Aguardando a página da TV...' : url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Digitar na TV', style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Toque em um campo de texto na TV e digite aqui.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textoCtrl,
          minLines: 2,
          maxLines: 4,
          onChanged: _aoDigitar,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'O texto aparece no campo selecionado na TV',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _limpar,
                icon: const Icon(Icons.clear),
                label: const Text('Limpar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _acao(AcaoRemota.enter),
                icon: const Icon(Icons.keyboard_return),
                label: const Text('Enter'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Abrir endereço na TV', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          onSubmitted: _abrirUrl,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'youtube.com ou o que quiser pesquisar',
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _abrirUrl(_urlCtrl.text),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Controles', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _botaoAcao(Icons.arrow_back, 'Voltar', AcaoRemota.voltar),
            _botaoAcao(Icons.arrow_forward, 'Avançar', AcaoRemota.avancar),
            _botaoAcao(Icons.refresh, 'Atualizar', AcaoRemota.recarregar),
            _botaoAcao(Icons.home, 'Início', AcaoRemota.inicio),
            _botaoAcao(Icons.keyboard_arrow_up, 'Rolar', AcaoRemota.rolarCima),
            _botaoAcao(Icons.keyboard_arrow_down, 'Rolar', AcaoRemota.rolarBaixo),
          ],
        ),
      ],
    );
  }

  Widget _botaoAcao(IconData icone, String rotulo, AcaoRemota acao) {
    return FilledButton.tonalIcon(
      onPressed: () => _acao(acao),
      icon: Icon(icone),
      label: Text(rotulo),
    );
  }
}
