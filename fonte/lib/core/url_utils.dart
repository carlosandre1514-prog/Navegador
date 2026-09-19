/// Utilitários para transformar o que o usuário digita em uma URL válida.
class UrlUtils {
  UrlUtils._();

  static const String paginaInicial = 'https://www.google.com';

  static final RegExp _local = RegExp(
    r'^(localhost|(\d{1,3}\.){3}\d{1,3})(:\d+)?([/?#].*)?$',
    caseSensitive: false,
  );

  static final RegExp _dominio = RegExp(
    r'^([a-z0-9-]+\.)+[a-z]{2,}(:\d+)?([/?#].*)?$',
    caseSensitive: false,
  );

  /// - Já começa com http(s)://  -> mantém.
  /// - localhost / IP            -> http://
  /// - Parece um domínio         -> https://
  /// - Qualquer outra coisa      -> pesquisa no Google.
  static String normalizar(String entrada) {
    final texto = entrada.trim();
    if (texto.isEmpty) return paginaInicial;

    final minusculo = texto.toLowerCase();
    if (minusculo.startsWith('http://') || minusculo.startsWith('https://')) {
      return texto;
    }
    if (!texto.contains(' ')) {
      if (_local.hasMatch(texto)) return 'http://$texto';
      if (_dominio.hasMatch(texto)) return 'https://$texto';
    }
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(texto)}';
  }

  /// Só deixa o WebView navegar por esquemas seguros. Bloqueia javascript:,
  /// file:, content:, intent:, market: etc.
  static bool esquemaPermitido(String? url) {
    if (url == null || url.isEmpty) return false;
    final esquema = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
    return esquema == 'http' ||
        esquema == 'https' ||
        esquema == 'about' ||
        esquema == 'blob';
  }
}
