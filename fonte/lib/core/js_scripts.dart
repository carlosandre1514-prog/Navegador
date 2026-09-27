import 'dart:convert';

/// Scripts JavaScript injetados na página.
///
/// IMPORTANTE: nenhum texto é concatenado "cru" dentro do script. Tudo que
/// vem de fora (texto digitado no celular, coordenadas) passa por
/// [_literal] (jsonEncode), então aspas, barras invertidas, quebras de linha
/// ou tentativas de injeção de código não conseguem escapar da string.
class JsScripts {
  JsScripts._();

  static String _literal(String valor) {
    return jsonEncode(valor)
        .replaceAll('\u2028', r'\u2028')
        .replaceAll('\u2029', r'\u2029');
  }

  // ---------------------------------------------------------------------------
  // Edição do campo focado
  // ---------------------------------------------------------------------------

  /// modo: 'substituir' | 'anexar' | 'apagar'
  static String editarCampo(String modo, String texto) {
    return '(function (modo, texto) {$_corpoEditarCampo})('
        '${_literal(modo)}, ${_literal(texto)});';
  }

  static const String _corpoEditarCampo = r'''
    var el = document.activeElement;
    for (var i = 0; i < 10 && el; i++) {
      if (el.shadowRoot && el.shadowRoot.activeElement) {
        el = el.shadowRoot.activeElement;
        continue;
      }
      if (el.tagName === 'IFRAME') {
        try {
          var d = el.contentDocument;
          if (d && d.activeElement) { el = d.activeElement; continue; }
        } catch (e) {}
      }
      break;
    }
    if (!el) return false;

    function calcular(atual) {
      if (modo === 'anexar') return atual + texto;
      if (modo === 'apagar') return atual.slice(0, -1);
      return texto;
    }

    var tag = (el.tagName || '').toUpperCase();
    if (tag === 'INPUT' || tag === 'TEXTAREA') {
      var proto = tag === 'INPUT' ? HTMLInputElement.prototype : HTMLTextAreaElement.prototype;
      var desc = Object.getOwnPropertyDescriptor(proto, 'value');
      var novo = calcular(el.value || '');
      // Usa o setter nativo: frameworks como React/Vue só percebem a mudança assim.
      if (desc && desc.set) { desc.set.call(el, novo); } else { el.value = novo; }
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    }
    if (el.isContentEditable) {
      el.textContent = calcular(el.textContent || '');
      el.dispatchEvent(new Event('input', { bubbles: true }));
      return true;
    }
    return false;
  ''';

  static String inserirTexto(String texto) => editarCampo('substituir', texto);

  // ---------------------------------------------------------------------------
  // Enter (envia o formulário / dispara a pesquisa)
  // ---------------------------------------------------------------------------

  static const String pressionarEnter = r'''
    (function () {
      var el = document.activeElement;
      if (!el) return false;
      var opcoes = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
      var naoCancelado = el.dispatchEvent(new KeyboardEvent('keydown', opcoes));
      el.dispatchEvent(new KeyboardEvent('keypress', opcoes));
      el.dispatchEvent(new KeyboardEvent('keyup', opcoes));
      if (naoCancelado && el.form) {
        if (el.form.requestSubmit) { el.form.requestSubmit(); } else { el.form.submit(); }
      }
      return true;
    })();
  ''';

  // ---------------------------------------------------------------------------
  // Clique na posição do cursor virtual (coordenadas em fração 0..1)
  // ---------------------------------------------------------------------------

  static String clicarNaPosicao(double fx, double fy) {
    final x = fx.clamp(0.0, 1.0).toStringAsFixed(5);
    final y = fy.clamp(0.0, 1.0).toStringAsFixed(5);
    return '(function (fx, fy) {$_corpoClique})($x, $y);';
  }

  static const String _corpoClique = r'''
    var x = Math.round(fx * window.innerWidth);
    var y = Math.round(fy * window.innerHeight);
    var el = document.elementFromPoint(x, y);
    if (!el) return false;
    var seletor = 'a,button,input,textarea,select,label,summary,[role="button"],[role="link"],[contenteditable="true"]';
    var alvo = (el.closest && el.closest(seletor)) || el;
    try { alvo.focus(); } catch (e) {}
    var base = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y };
    ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function (tipo) {
      var Construtor = (tipo.indexOf('pointer') === 0 && window.PointerEvent) ? PointerEvent : MouseEvent;
      alvo.dispatchEvent(new Construtor(tipo, base));
    });
    return true;
  ''';
}
