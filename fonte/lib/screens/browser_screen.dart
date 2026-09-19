import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/js_scripts.dart';
import '../core/url_utils.dart';
import '../services/pairing_service.dart';
import '../widgets/pairing_dialog.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_keyboard.dart';
import '../widgets/virtual_cursor.dart';

/// User-Agent de desktop (Chrome no Windows). Atualize o número da versão de
/// vez em quando: alguns sites recusam navegadores muito antigos.
const String _uaDesktop =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

/// Tela do navegador. [modoTv] liga os recursos de Android TV:
/// PIN de pareamento, cursor virtual por setas, teclado na tela e botões
/// maiores com foco bem visível.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.modoTv});

  final bool modoTv;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _web;
  final TextEditingController _urlCtrl =
      TextEditingController(text: UrlUtils.paginaInicial);
  final FocusNode _urlFoco = FocusNode();

  double _progresso = 0;
  bool _carregando = false;
  bool _desktop = true;
  bool _modoCursor = false;
  bool _tecladoAberto = false;
  String? _erroCarga;
  String? _uaMovel;

  SessaoTv? _sessao;

  bool get _tv => widget.modoTv;

  @override
  void initState() {
    super.initState();
    unawaited(_descobrirUaMovel());
    if (_tv) {
      final sessao = SessaoTv();
      sessao.aoReceberComando = _executarComando;
      _sessao = sessao;
      unawaited(sessao.iniciar());
    }
  }

  @override
  void dispose() {
    final sessao = _sessao;
    if (sessao != null) unawaited(sessao.encerrar());
    _urlCtrl.dispose();
    _urlFoco.dispose();
    super.dispose();
  }

  Future<void> _descobrirUaMovel() async {
    try {
      _uaMovel = await InAppWebViewController.getDefaultUserAgent();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Configurações do WebView
  // ---------------------------------------------------------------------------

  InAppWebViewSettings _configuracoes() {
    return InAppWebViewSettings(
      // Modo desktop forçado (User-Agent + viewport de desktop).
      userAgent: _desktop ? _uaDesktop : (_uaMovel ?? ''),
      preferredContentMode: _desktop
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      thirdPartyCookiesEnabled: true,
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
      // Segurança: a página não precisa ler arquivos do aparelho.
      allowFileAccess: false,
      allowContentAccess: false,
      // target="_blank" e window.open são tratados em onCreateWindow.
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      useShouldOverrideUrlLoading: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Navegação
  // ---------------------------------------------------------------------------

  Future<void> _carregar(String entrada) async {
    final url = UrlUtils.normalizar(entrada);
    await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _voltar() async {
    final web = _web;
    if (web != null && await web.canGoBack()) await web.goBack();
  }

  Future<void> _avancar() async {
    final web = _web;
    if (web != null && await web.canGoForward()) await web.goForward();
  }

  Future<void> _recarregarOuParar() async {
    if (_carregando) {
      await _web?.stopLoading();
    } else {
      await _web?.reload();
    }
  }

  Future<void> _alternarDesktop() async {
    setState(() => _desktop = !_desktop);
    await _web?.setSettings(settings: _configuracoes());
    await _web?.reload();
  }

  void _atualizarUrl(String? url) {
    if (url == null || !mounted) return;
    if (!_urlFoco.hasFocus) _urlCtrl.text = url;
    _sessao?.publicarUrl(url);
  }

  /// Botão "Voltar" do sistema / controle remoto.
  Future<void> _aoVoltarDoSistema() async {
    if (_modoCursor) {
      setState(() => _modoCursor = false);
      return;
    }
    if (_tecladoAberto) {
      setState(() => _tecladoAberto = false);
      return;
    }
    final web = _web;
    if (web != null && await web.canGoBack()) {
      await web.goBack();
      return;
    }
    if (!mounted) return;
    if (_tv) {
      await SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Recursos de TV
  // ---------------------------------------------------------------------------

  void _alternarCursor() {
    setState(() {
      _modoCursor = !_modoCursor;
      if (_modoCursor) _tecladoAberto = false;
    });
    if (_modoCursor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cursor ligado: setas movem, OK clica. Voltar desliga o cursor.',
          ),
        ),
      );
    }
  }

  void _alternarTeclado() {
    setState(() {
      _tecladoAberto = !_tecladoAberto;
      if (_tecladoAberto) _modoCursor = false;
    });
  }

  Future<void> _clicarNaPagina(double fx, double fy) async {
    await _web?.evaluateJavascript(source: JsScripts.clicarNaPosicao(fx, fy));
  }

  Future<void> _rolar(int dy) async {
    await _web?.scrollBy(x: 0, y: dy, animated: true);
  }

  Future<void> _editarCampo(String modo, String texto) async {
    await _web?.evaluateJavascript(source: JsScripts.editarCampo(modo, texto));
  }

  /// Executa um comando vindo do celular pareado.
  Future<void> _executarComando(Comando comando) async {
    final web = _web;
    if (web == null) return;

    switch (comando.tipo) {
      case TipoComando.texto:
        await web.evaluateJavascript(
          source: JsScripts.inserirTexto(comando.valor),
        );
      case TipoComando.url:
        await _carregar(comando.valor);
      case TipoComando.acao:
        final acao = acaoRemotaPorNome(comando.valor);
        if (acao != null) await _executarAcao(web, acao);
    }
  }

  Future<void> _executarAcao(InAppWebViewController web, AcaoRemota acao) async {
    switch (acao) {
      case AcaoRemota.voltar:
        if (await web.canGoBack()) await web.goBack();
      case AcaoRemota.avancar:
        if (await web.canGoForward()) await web.goForward();
      case AcaoRemota.recarregar:
        await web.reload();
      case AcaoRemota.inicio:
        await _carregar(UrlUtils.paginaInicial);
      case AcaoRemota.rolarCima:
        await web.scrollBy(x: 0, y: -400, animated: true);
      case AcaoRemota.rolarBaixo:
        await web.scrollBy(x: 0, y: 400, animated: true);
      case AcaoRemota.enter:
        await web.evaluateJavascript(source: JsScripts.pressionarEnter);
    }
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  Widget _campoEndereco() {
    return TextField(
      controller: _urlCtrl,
      focusNode: _urlFoco,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      enableSuggestions: false,
      onTap: () => _urlCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _urlCtrl.text.length),
      onSubmitted: (valor) {
        _urlFoco.unfocus();
        unawaited(_carregar(valor));
      },
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        hintText: 'Pesquise ou digite o endereço',
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _botaoDesktop() {
    return BotaoBarra(
      icone: _desktop ? Icons.desktop_windows : Icons.smartphone,
      dica: _desktop ? 'Modo desktop (ligado)' : 'Modo celular',
      ativo: _desktop,
      aoPressionar: () => unawaited(_alternarDesktop()),
    );
  }

  /// Barra da TV: tudo em uma linha, com rótulos nos botões especiais.
  Widget _barraTv() {
    final sessao = _sessao;
    return Row(
      children: [
        BotaoBarra(
          icone: Icons.arrow_back,
          dica: 'Voltar',
          aoPressionar: () => unawaited(_voltar()),
        ),
        BotaoBarra(
          icone: Icons.arrow_forward,
          dica: 'Avançar',
          aoPressionar: () => unawaited(_avancar()),
        ),
        BotaoBarra(
          icone: _carregando ? Icons.close : Icons.refresh,
          dica: _carregando ? 'Parar' : 'Atualizar',
          aoPressionar: () => unawaited(_recarregarOuParar()),
        ),
        BotaoBarra(
          icone: Icons.home,
          dica: 'Página inicial',
          aoPressionar: () => unawaited(_carregar(UrlUtils.paginaInicial)),
        ),
        const SizedBox(width: 8),
        Expanded(child: _campoEndereco()),
        const SizedBox(width: 8),
        BotaoBarra(
          icone: Icons.mouse,
          rotulo: 'Cursor',
          dica: 'Cursor virtual (setas + OK)',
          ativo: _modoCursor,
          aoPressionar: _alternarCursor,
        ),
        BotaoBarra(
          icone: Icons.keyboard,
          rotulo: 'Teclado',
          dica: 'Teclado na tela',
          ativo: _tecladoAberto,
          aoPressionar: _alternarTeclado,
        ),
        if (sessao != null)
          ListenableBuilder(
            listenable: Listenable.merge([sessao.pin, sessao.celularConectado]),
            builder: (context, _) {
              final pin = sessao.pin.value;
              final conectado = sessao.celularConectado.value;
              return BotaoBarra(
                icone: conectado ? Icons.phone_android : Icons.link,
                rotulo: conectado
                    ? 'Conectado'
                    : (pin == null ? 'Parear' : 'PIN ${formatarPin(pin)}'),
                dica: 'Parear com o celular',
                ativo: conectado,
                aoPressionar: () => unawaited(
                  mostrarDialogoPareamento(context, sessao),
                ),
              );
            },
          ),
        _botaoDesktop(),
      ],
    );
  }

  /// Barra do celular: endereço em cima, navegação embaixo (alcance do polegar).
  Widget _barraSuperiorCelular() {
    return Row(
      children: [
        Expanded(child: _campoEndereco()),
        _botaoDesktop(),
      ],
    );
  }

  Widget _barraInferiorCelular() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        BotaoBarra(
          icone: Icons.arrow_back,
          dica: 'Voltar',
          aoPressionar: () => unawaited(_voltar()),
        ),
        BotaoBarra(
          icone: Icons.arrow_forward,
          dica: 'Avançar',
          aoPressionar: () => unawaited(_avancar()),
        ),
        BotaoBarra(
          icone: _carregando ? Icons.close : Icons.refresh,
          dica: _carregando ? 'Parar' : 'Atualizar',
          aoPressionar: () => unawaited(_recarregarOuParar()),
        ),
        BotaoBarra(
          icone: Icons.home,
          dica: 'Página inicial',
          aoPressionar: () => unawaited(_carregar(UrlUtils.paginaInicial)),
        ),
      ],
    );
  }

  Widget _webView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(UrlUtils.paginaInicial)),
      initialSettings: _configuracoes(),
      onWebViewCreated: (controller) => _web = controller,
      shouldOverrideUrlLoading: (controller, acao) async {
        final url = acao.request.url?.toString();
        return UrlUtils.esquemaPermitido(url)
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (controller, acao) async {
        // Abas/pop-ups abrem na mesma tela.
        final url = acao.request.url;
        if (url != null && UrlUtils.esquemaPermitido(url.toString())) {
          await controller.loadUrl(urlRequest: URLRequest(url: url));
        }
        return true;
      },
      onLoadStart: (controller, url) {
        if (!mounted) return;
        setState(() {
          _carregando = true;
          _erroCarga = null;
        });
        _atualizarUrl(url?.toString());
      },
      onLoadStop: (controller, url) {
        if (!mounted) return;
        setState(() => _carregando = false);
        _atualizarUrl(url?.toString());
      },
      onProgressChanged: (controller, progresso) {
        if (!mounted) return;
        setState(() => _progresso = progresso / 100);
      },
      onUpdateVisitedHistory: (controller, url, recarregando) {
        _atualizarUrl(url?.toString());
      },
      onReceivedError: (controller, requisicao, erro) {
        if (!mounted) return;
        if (requisicao.isForMainFrame ?? true) {
          setState(() => _erroCarga = erro.description);
        }
      },
    );
  }

  Widget _avisoDeErro() {
    final cores = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: cores.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: cores.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Não foi possível carregar a página: $_erroCarga',
                  style: TextStyle(color: cores.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_web?.reload() ?? Future<void>.value()),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (jaFechou, resultado) {
        if (jaFechou) return;
        unawaited(_aoVoltarDoSistema());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Material(
                color: cores.surfaceContainer,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: _tv ? 8 : 4),
                  child: _tv ? _barraTv() : _barraSuperiorCelular(),
                ),
              ),
              SizedBox(
                height: 3,
                child: _progresso < 1.0 && _carregando
                    ? LinearProgressIndicator(value: _progresso)
                    : null,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(key: const ValueKey('webview'), child: _webView()),
                    if (_erroCarga != null) _avisoDeErro(),
                    if (_modoCursor)
                      Positioned.fill(
                        key: const ValueKey('cursor'),
                        child: VirtualCursor(
                          aoClicar: (fx, fy) => unawaited(_clicarNaPagina(fx, fy)),
                          aoRolar: (dy) => unawaited(_rolar(dy)),
                        ),
                      ),
                  ],
                ),
              ),
              if (_tv && _tecladoAberto)
                TecladoTv(
                  aoAnexar: (texto) => unawaited(_editarCampo('anexar', texto)),
                  aoApagar: () => unawaited(_editarCampo('apagar', '')),
                  aoEnter: () => unawaited(
                    _web?.evaluateJavascript(source: JsScripts.pressionarEnter) ??
                        Future<void>.value(),
                  ),
                  aoFechar: () => setState(() => _tecladoAberto = false),
                ),
              if (!_tv)
                Material(
                  color: cores.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _barraInferiorCelular(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
