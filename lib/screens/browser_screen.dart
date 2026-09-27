import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/ad_block.dart';
import '../core/js_scripts.dart';
import '../core/url_utils.dart';
import '../services/pairing_service.dart';
import '../widgets/pairing_dialog.dart' show formatarPin;

/// User-Agent de desktop (Chrome no Windows). Atualize o número da versão de
/// vez em quando: alguns sites recusam navegadores muito antigos.
const String _uaDesktop =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

/// Papel deste aparelho no espelhamento de tela (veja mais abaixo).
enum PapelEspelho { nenhum, anfitriao, convidado }

/// Tela do navegador — é a tela inicial do app, tanto no celular quanto na
/// Android TV. [modoTvInicial] só define o ponto de partida do "Modo de
/// exibição": dá para trocar depois pelos três pontinhos, sem reabrir o app.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.modoTvInicial});

  final bool modoTvInicial;

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
  String? _erroCarga;
  String? _uaMovel;

  /// Modo de exibição atual: true = TV (sem teclado na tela; use mouse e
  /// teclado USB), false = Celular (teclado normal do sistema).
  late bool _modoTvAtivo = widget.modoTvInicial;

  NivelBloqueio _nivelBloqueio = NivelBloqueio.padrao;

  // ---------------------------------------------------------------------------
  // Espelhamento de tela: este aparelho pode virar "anfitrião" (gera um PIN)
  // ou "convidado" (digita o PIN de outro aparelho). Em qualquer um dos dois
  // papéis, os dois lados carregam a mesma URL e um clique em qualquer um
  // deles é reproduzido no outro.
  // ---------------------------------------------------------------------------
  SessaoTv? _sessaoAnfitriao;
  ControleRemoto? _controleConvidado;
  final ValueNotifier<PapelEspelho> _papelNotifier =
      ValueNotifier<PapelEspelho>(PapelEspelho.nenhum);

  /// Última URL que chegou (ou foi enviada) pelo espelhamento — evita que o
  /// vaivém de "carreguei aqui" -> "avisei o outro" -> "o outro avisou de
  /// volta" fique recarregando a página sem parar.
  String? _ultimaUrlRemota;
  Timer? _debounceDigitar;

  @override
  void initState() {
    super.initState();
    unawaited(_descobrirUaMovel());
  }

  @override
  void dispose() {
    final anfitriao = _sessaoAnfitriao;
    if (anfitriao != null) unawaited(anfitriao.encerrar());
    final convidado = _controleConvidado;
    if (convidado != null) {
      convidado.urlDaTv.removeListener(_aoUrlDoAnfitriaoMudar);
      unawaited(convidado.encerrar());
    }
    _papelNotifier.dispose();
    _debounceDigitar?.cancel();
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
      // Bloqueio de anúncios (Desligado / Padrão / Avançado).
      contentBlockers: AdBlock.regras(_nivelBloqueio),
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

    // Espelhamento: avisa quem estiver do outro lado que a página mudou
    // aqui — a menos que essa mudança tenha vindo justamente de lá.
    final anfitriao = _sessaoAnfitriao;
    if (anfitriao != null) anfitriao.publicarUrl(url);

    final convidado = _controleConvidado;
    if (convidado != null && url != _ultimaUrlRemota) {
      _ultimaUrlRemota = url;
      unawaited(convidado.enviarUrl(url));
    }
  }

  /// Botão "Voltar" do sistema / controle remoto: volta na página; se não
  /// houver mais para onde voltar, sai do app (esta é a única tela do app).
  Future<void> _aoVoltarDoSistema() async {
    final web = _web;
    if (web != null && await web.canGoBack()) {
      await web.goBack();
      return;
    }
    if (!mounted) return;
    await SystemNavigator.pop();
  }

  /// Executa um comando vindo do outro aparelho pareado (celular -> TV
  /// quando este aparelho é o anfitrião do espelhamento).
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
      case TipoComando.clique:
        final partes = comando.valor.split(',');
        if (partes.length == 2) {
          final fx = double.tryParse(partes[0]);
          final fy = double.tryParse(partes[1]);
          if (fx != null && fy != null) {
            await web.evaluateJavascript(
              source: JsScripts.clicarNaPosicao(fx, fy),
            );
          }
        }
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
  // Espelhamento de tela
  // ---------------------------------------------------------------------------

  Future<void> _atualizarFlagEspelhoNoWebview() async {
    final ligado = _papelNotifier.value != PapelEspelho.nenhum;
    await _web?.evaluateJavascript(
      source: JsScripts.instalarCapturaDeCliques(ligado),
    );
  }

  void _aoUrlDoAnfitriaoMudar() {
    final controle = _controleConvidado;
    if (controle == null) return;
    final url = controle.urlDaTv.value;
    if (url.isEmpty || url == _ultimaUrlRemota) return;
    _ultimaUrlRemota = url;
    unawaited(_carregar(url));
  }

  Future<void> _tornarAnfitriao() async {
    await _encerrarEspelhamento(atualizarPapel: false);
    final sessao = SessaoTv();
    sessao.aoReceberComando = _executarComando;
    _sessaoAnfitriao = sessao;
    _papelNotifier.value = PapelEspelho.anfitriao;
    if (mounted) setState(() {});
    await _atualizarFlagEspelhoNoWebview();
    await sessao.iniciar();
  }

  Future<String?> _conectarComoConvidado(String pin) async {
    final controle = ControleRemoto();
    final erro = await controle.conectar(pin);
    if (erro != null) {
      await controle.encerrar();
      return erro;
    }
    await _encerrarEspelhamento(atualizarPapel: false);
    controle.aoReceberCliqueDoAnfitriao = (fx, fy) {
      unawaited(
        _web?.evaluateJavascript(source: JsScripts.clicarNaPosicao(fx, fy)),
      );
    };
    controle.urlDaTv.addListener(_aoUrlDoAnfitriaoMudar);
    _controleConvidado = controle;
    _papelNotifier.value = PapelEspelho.convidado;
    if (mounted) setState(() {});
    await _atualizarFlagEspelhoNoWebview();
    // Se o anfitrião já estiver em alguma página, carrega ela agora.
    _aoUrlDoAnfitriaoMudar();
    return null;
  }

  Future<void> _encerrarEspelhamento({bool atualizarPapel = true}) async {
    final anfitriao = _sessaoAnfitriao;
    _sessaoAnfitriao = null;
    if (anfitriao != null) unawaited(anfitriao.encerrar());

    final convidado = _controleConvidado;
    _controleConvidado = null;
    if (convidado != null) {
      convidado.urlDaTv.removeListener(_aoUrlDoAnfitriaoMudar);
      unawaited(convidado.encerrar());
    }

    if (atualizarPapel) {
      _papelNotifier.value = PapelEspelho.nenhum;
      if (mounted) setState(() {});
      await _atualizarFlagEspelhoNoWebview();
    }
  }

  // ---------------------------------------------------------------------------
  // Ferramentas (menu dos três pontinhos)
  // ---------------------------------------------------------------------------

  String _rotuloBloqueio(NivelBloqueio nivel) {
    switch (nivel) {
      case NivelBloqueio.desligado:
        return 'Desligado';
      case NivelBloqueio.padrao:
        return 'Padrão';
      case NivelBloqueio.avancado:
        return 'Avançado';
    }
  }

  String _rotuloEspelho(PapelEspelho papel) {
    switch (papel) {
      case PapelEspelho.nenhum:
        return 'Desligado';
      case PapelEspelho.anfitriao:
        final pin = _sessaoAnfitriao?.pin.value;
        return pin == null ? 'Gerando PIN...' : 'Anfitrião · PIN ${formatarPin(pin)}';
      case PapelEspelho.convidado:
        return 'Conectado como convidado';
    }
  }

  Future<void> _abrirFerramentas() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(_desktop ? Icons.desktop_windows : Icons.smartphone),
                title: const Text('Modo desktop'),
                subtitle: Text(_desktop ? 'Ativado' : 'Desativado'),
                trailing: Switch(
                  value: _desktop,
                  onChanged: (_) {
                    Navigator.of(sheetContext).pop();
                    unawaited(_alternarDesktop());
                  },
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_alternarDesktop());
                },
              ),
              ListTile(
                leading: Icon(_modoTvAtivo ? Icons.tv : Icons.smartphone),
                title: const Text('Modo de exibição'),
                subtitle: Text(_modoTvAtivo ? 'TV' : 'Celular'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_abrirDialogoModoExibicao());
                },
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Bloqueio de anúncios'),
                subtitle: Text(_rotuloBloqueio(_nivelBloqueio)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_abrirDialogoBloqueio());
                },
              ),
              ListenableBuilder(
                listenable: _papelNotifier,
                builder: (context, _) {
                  final conectado = (_sessaoAnfitriao?.celularConectado.value ?? false) ||
                      (_controleConvidado?.ativa.value ?? false);
                  return ListTile(
                    leading: Icon(
                      conectado ? Icons.cast_connected : Icons.cast_outlined,
                    ),
                    title: const Text('Espelhamento de tela'),
                    subtitle: Text(_rotuloEspelho(_papelNotifier.value)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_abrirDialogoEspelhamento());
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirDialogoModoExibicao() async {
    final escolha = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Modo de exibição'),
        children: [
          RadioListTile<bool>(
            value: false,
            groupValue: _modoTvAtivo,
            title: const Text('Celular'),
            subtitle: const Text('Teclado do sistema aparece normalmente.'),
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
          ),
          RadioListTile<bool>(
            value: true,
            groupValue: _modoTvAtivo,
            title: const Text('TV'),
            subtitle: const Text('Sem teclado na tela — use mouse/teclado USB.'),
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
          ),
        ],
      ),
    );
    if (escolha == null || escolha == _modoTvAtivo || !mounted) return;
    setState(() => _modoTvAtivo = escolha);
    await _web?.reload();
  }

  Future<void> _abrirDialogoBloqueio() async {
    final escolha = await showDialog<NivelBloqueio>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Bloqueio de anúncios'),
        children: [
          RadioListTile<NivelBloqueio>(
            value: NivelBloqueio.desligado,
            groupValue: _nivelBloqueio,
            title: const Text('Desligado'),
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
          ),
          RadioListTile<NivelBloqueio>(
            value: NivelBloqueio.padrao,
            groupValue: _nivelBloqueio,
            title: const Text('Padrão'),
            subtitle: const Text('Bloqueia os anúncios e rastreadores mais comuns.'),
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
          ),
          RadioListTile<NivelBloqueio>(
            value: NivelBloqueio.avancado,
            groupValue: _nivelBloqueio,
            title: const Text('Avançado'),
            subtitle: const Text('Lista maior de domínios + esconde anúncios que sobrarem.'),
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
          ),
        ],
      ),
    );
    if (escolha == null || escolha == _nivelBloqueio || !mounted) return;
    setState(() => _nivelBloqueio = escolha);
    await _web?.setSettings(settings: _configuracoes());
    await _web?.reload();
  }

  Future<void> _abrirDialogoEspelhamento() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Espelhamento de tela'),
          content: SizedBox(
            width: 440,
            child: ListenableBuilder(
              listenable: _papelNotifier,
              builder: (context, _) {
                switch (_papelNotifier.value) {
                  case PapelEspelho.nenhum:
                    return _corpoEspelhoDesligado();
                  case PapelEspelho.anfitriao:
                    return _corpoEspelhoAnfitriao();
                  case PapelEspelho.convidado:
                    return _corpoEspelhoConvidado();
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Widget _corpoEspelhoDesligado() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Conecte dois aparelhos: um clique em qualquer um deles acontece '
          'também no outro, e os dois acompanham a mesma página.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => unawaited(_tornarAnfitriao()),
          icon: const Icon(Icons.cast),
          label: const Text('Gerar PIN neste aparelho'),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Ou digite o PIN gerado no outro aparelho:'),
        const SizedBox(height: 8),
        _FormularioConectarConvidado(aoConectar: _conectarComoConvidado),
      ],
    );
  }

  Widget _corpoEspelhoAnfitriao() {
    final sessao = _sessaoAnfitriao!;
    return ListenableBuilder(
      listenable: Listenable.merge([sessao.pin, sessao.celularConectado, sessao.erro]),
      builder: (context, _) {
        final pin = sessao.pin.value;
        final conectado = sessao.celularConectado.value;
        final erro = sessao.erro.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Digite este PIN no outro aparelho:'),
            const SizedBox(height: 12),
            Center(
              child: Text(
                pin == null ? '------' : formatarPin(pin),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
              ),
            ),
            const SizedBox(height: 12),
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
                        ? 'Conectado! Um clique em qualquer aparelho acontece no outro.'
                        : 'Aguardando o outro aparelho...',
                  ),
                ),
              ],
            ),
            if (erro != null) ...[
              const SizedBox(height: 8),
              Text(erro, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => unawaited(_encerrarEspelhamento()),
              icon: const Icon(Icons.link_off),
              label: const Text('Encerrar espelhamento'),
            ),
          ],
        );
      },
    );
  }

  void _aoDigitarParaAnfitriao(String texto) {
    _debounceDigitar?.cancel();
    _debounceDigitar = Timer(const Duration(milliseconds: 150), () {
      unawaited(_controleConvidado?.enviarTexto(texto));
    });
  }

  Widget _corpoEspelhoConvidado() {
    final controle = _controleConvidado!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Conectado ao PIN ${formatarPin(controle.pin ?? '')}'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'A página muda sozinha para acompanhar o anfitrião; um clique em '
          'qualquer um dos dois aparelhos acontece também no outro.',
        ),
        const SizedBox(height: 16),
        const Text('Digitar no campo selecionado no anfitrião:'),
        const SizedBox(height: 8),
        TextField(
          onChanged: _aoDigitarParaAnfitriao,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'O texto aparece no campo focado no outro aparelho',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => unawaited(_encerrarEspelhamento()),
          icon: const Icon(Icons.link_off),
          label: const Text('Sair do espelhamento'),
        ),
      ],
    );
  }

  Widget _botaoFerramentas() {
    return ListenableBuilder(
      listenable: _papelNotifier,
      builder: (context, _) {
        final anfitriao = _sessaoAnfitriao;
        final convidado = _controleConvidado;
        final extras = <Listenable>[
          if (anfitriao != null) anfitriao.celularConectado,
          if (convidado != null) convidado.ativa,
        ];
        if (extras.isEmpty) return _iconeFerramentas(false);
        return ListenableBuilder(
          listenable: Listenable.merge(extras),
          builder: (context, __) {
            final conectado = (anfitriao?.celularConectado.value ?? false) ||
                (convidado?.ativa.value ?? false);
            return _iconeFerramentas(conectado);
          },
        );
      },
    );
  }

  Widget _iconeFerramentas(bool conectado) {
    return IconButton(
      tooltip: 'Ferramentas',
      onPressed: () => unawaited(_abrirFerramentas()),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.more_vert),
          if (conectado)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  Widget _campoEndereco() {
    return TextField(
      controller: _urlCtrl,
      focusNode: _urlFoco,
      // Em modo TV o app nunca pede o teclado do sistema: só um teclado USB
      // físico envia teclas, e essas continuam funcionando normalmente.
      keyboardType: _modoTvAtivo ? TextInputType.none : TextInputType.url,
      showCursor: true,
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
        prefixIcon: const Icon(Icons.search, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _webView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(UrlUtils.paginaInicial)),
      initialSettings: _configuracoes(),
      onWebViewCreated: (controller) {
        _web = controller;
        // Espelhamento: recebe os cliques capturados na própria página deste
        // aparelho e os repassa para quem estiver do outro lado da conexão.
        controller.addJavaScriptHandler(
          handlerName: 'espelhoClique',
          callback: (args) {
            if (args.length < 2) return;
            final fx = (args[0] as num).toDouble();
            final fy = (args[1] as num).toDouble();
            final anfitriao = _sessaoAnfitriao;
            if (anfitriao != null) {
              anfitriao.publicarCliqueProprio(fx, fy);
              return;
            }
            final convidado = _controleConvidado;
            if (convidado != null) unawaited(convidado.enviarClique(fx, fy));
          },
        );
      },
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
      onLoadStop: (controller, url) async {
        if (_modoTvAtivo) {
          // Garante que a página nunca abra o teclado do sistema: só o
          // teclado físico USB (que não depende disso) digita.
          await controller.evaluateJavascript(source: JsScripts.semTecladoNaTela);
        }
        // Reinstala (ou reafirma) a captura de cliques do espelhamento —
        // cada navegação zera as variáveis JavaScript da página anterior.
        await controller.evaluateJavascript(
          source: JsScripts.instalarCapturaDeCliques(
            _papelNotifier.value != PapelEspelho.nenhum,
          ),
        );
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (jaFechou, resultado) {
        if (jaFechou) return;
        unawaited(_aoVoltarDoSistema());
      },
      child: Scaffold(
        appBar: AppBar(
          title: _campoEndereco(),
          titleSpacing: 8,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: () => unawaited(_voltar()),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Avançar',
              onPressed: () => unawaited(_avancar()),
            ),
            IconButton(
              icon: Icon(_carregando ? Icons.close : Icons.refresh),
              tooltip: _carregando ? 'Parar' : 'Atualizar',
              onPressed: () => unawaited(_recarregarOuParar()),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Página inicial',
              onPressed: () => unawaited(_carregar(UrlUtils.paginaInicial)),
            ),
            _botaoFerramentas(),
          ],
        ),
        body: Column(
          children: [
            // Indicador de progresso
            SizedBox(
              height: 3,
              child: _progresso < 1.0 && _carregando
                  ? LinearProgressIndicator(value: _progresso)
                  : const SizedBox.shrink(),
            ),

            // WebView + aviso de erro
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    key: const ValueKey('webview'),
                    child: _webView(),
                  ),
                  if (_erroCarga != null) _avisoDeErro(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulário simples de PIN usado para entrar como convidado no
/// espelhamento de tela. Fica em um widget à parte para manter o estado do
/// campo de texto e da mensagem de erro isolado do resto da tela.
class _FormularioConectarConvidado extends StatefulWidget {
  const _FormularioConectarConvidado({required this.aoConectar});

  final Future<String?> Function(String pin) aoConectar;

  @override
  State<_FormularioConectarConvidado> createState() =>
      _FormularioConectarConvidadoState();
}

class _FormularioConectarConvidadoState extends State<_FormularioConectarConvidado> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _conectando = false;
  String? _erro;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _tentar() async {
    if (_conectando) return;
    setState(() {
      _conectando = true;
      _erro = null;
    });
    final erro = await widget.aoConectar(_pinCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _conectando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => unawaited(_tentar()),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '000000',
            counterText: '',
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 8),
          Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _conectando ? null : () => unawaited(_tentar()),
          icon: _conectando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link),
          label: Text(_conectando ? 'Conectando...' : 'Conectar'),
        ),
      ],
    );
  }
}
