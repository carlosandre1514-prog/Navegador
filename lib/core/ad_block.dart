import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Nível de bloqueio de anúncios escolhido pelo usuário no menu do navegador.
enum NivelBloqueio { desligado, padrao, avancado }

/// Monta as regras de [ContentBlocker] (recurso nativo do WebView) para cada
/// nível. "Padrão" bloqueia os domínios de anúncio/rastreamento mais comuns.
/// "Avançado" soma uma lista maior de domínios e ainda esconde por CSS
/// elementos que sobrarem na página (banners, caixas de anúncio etc.),
/// mesmo quando o anúncio em si não vem de um domínio bloqueado.
class AdBlock {
  AdBlock._();

  static const List<String> _dominiosPadrao = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'adservice.google.',
    'google-analytics.com',
    'googletagmanager.com',
    'scorecardresearch.com',
    'moatads.com',
    'adnxs.com',
    'pubmatic.com',
    'criteo.com',
    'criteo.net',
    'taboola.com',
    'outbrain.com',
    'adsafeprotected.com',
    'quantserve.com',
    'zedo.com',
    'exponential.com',
  ];

  static const List<String> _dominiosAvancado = [
    'adform.net',
    'adroll.com',
    'rlcdn.com',
    'bidswitch.net',
    'rubiconproject.com',
    'openx.net',
    'casalemedia.com',
    'yieldmo.com',
    'teads.tv',
    'smartadserver.com',
    'media.net',
    'mgid.com',
    'revcontent.com',
    'popads.net',
    'propellerads.com',
    'adcolony.com',
    'unityads.unity3d.com',
    'appsflyer.com',
    'branch.io',
    'amazon-adsystem.com',
  ];

  static const String _seletoresCssAvancado =
      '.ad, .ads, .adsbygoogle, .advert, .advertisement, .banner-ad, '
      '.banners, .widget-ads, .ad-unit, .ad-container, .ad-wrapper, '
      'ins.adsbygoogle, iframe[src*="ads"], iframe[id*="google_ads"]';

  static List<ContentBlocker> regras(NivelBloqueio nivel) {
    if (nivel == NivelBloqueio.desligado) return const [];

    final dominios = [
      ..._dominiosPadrao,
      if (nivel == NivelBloqueio.avancado) ..._dominiosAvancado,
    ];

    final bloqueiosDeRede = dominios
        .map(
          (dominio) => ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*${dominio.replaceAll('.', r'\.')}.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
        )
        .toList();

    if (nivel != NivelBloqueio.avancado) return bloqueiosDeRede;

    final ocultarRestante = ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: '.*'),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.CSS_DISPLAY_NONE,
        selector: _seletoresCssAvancado,
      ),
    );

    return [...bloqueiosDeRede, ocultarRestante];
  }
}
