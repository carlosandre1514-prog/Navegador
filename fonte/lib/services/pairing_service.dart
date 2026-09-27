import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Tipos de comando que o celular pode enviar para a TV.
enum TipoComando { texto, url, acao }

/// Ações rápidas do controle remoto.
enum AcaoRemota { voltar, avancar, recarregar, inicio, rolarCima, rolarBaixo, enter }

TipoComando? tipoComandoPorNome(String nome) {
  for (final t in TipoComando.values) {
    if (t.name == nome) return t;
  }
  return null;
}

AcaoRemota? acaoRemotaPorNome(String nome) {
  for (final a in AcaoRemota.values) {
    if (a.name == nome) return a;
  }
  return null;
}

class Comando {
  const Comando({required this.seq, required this.tipo, required this.valor});

  final int seq;
  final TipoComando tipo;
  final String valor;
}

/// Inicializa Firebase + login anônimo uma única vez.
///
/// O login anônimo é o que permite às regras do banco (database.rules.json)
/// exigirem `auth != null` e identificarem "dono da TV" e "celular pareado".
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool>? _iniciando;
  static String? erro;

  static Future<bool> garantirPronto() {
    return _iniciando ??= _iniciar().then((ok) {
      if (!ok) _iniciando = null; // permite tentar de novo (ex.: sem internet)
      return ok;
    });
  }

  static Future<bool> _iniciar() async {
    if (!FirebaseConfig.configurado) {
      erro = 'Firebase não configurado. Preencha lib/firebase_options.dart '
          '(veja o README.md).';
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: FirebaseConfig.android);
      }
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      erro = null;
      return true;
    } catch (e) {
      erro = 'Não foi possível conectar ao Firebase. Verifique a internet e '
          'se o login anônimo está ativado. ($e)';
      return false;
    }
  }
}

/// Relógio do servidor (evita depender da hora errada do aparelho).
class _Relogio {
  static int _deslocamento = 0;

  static Future<void> sincronizar(FirebaseDatabase db) async {
    try {
      final evento = await db
          .ref('.info/serverTimeOffset')
          .onValue
          .first
          .timeout(const Duration(seconds: 5));
      final valor = evento.snapshot.value;
      if (valor is num) _deslocamento = valor.toInt();
    } catch (_) {
      // mantém o deslocamento anterior
    }
  }

  static int agora() => DateTime.now().millisecondsSinceEpoch + _deslocamento;
}

// =============================================================================
// LADO DA TV
// =============================================================================

/// Sessão de pareamento criada pela TV.
///
/// Estrutura no Realtime Database:
///   /sessoes/<PIN de 6 dígitos>
///       donoTv:     uid anônimo da TV
///       expiraEm:   timestamp (ms) - a TV renova a cada 60 s
///       urlAtual:   página aberta na TV (para o celular mostrar)
///       celularUid: uid do celular pareado (gravado UMA vez pelo celular)
///       controle:   {seq, tipo, valor} - último comando do celular
class SessaoTv {
  static const int _validadeMs = 5 * 60 * 1000;
  static const Duration _batimento = Duration(seconds: 60);

  final ValueNotifier<String?> pin = ValueNotifier<String?>(null);
  final ValueNotifier<bool> celularConectado = ValueNotifier<bool>(false);
  final ValueNotifier<String?> erro = ValueNotifier<String?>(null);

  /// Chamado quando o celular envia um comando.
  void Function(Comando comando)? aoReceberComando;

  DatabaseReference? _ref;
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _subSessao;
  StreamSubscription<DatabaseEvent>? _subControle;
  bool _primeiroControle = true;
  int? _ultimoSeq;

  /// Cria uma sessão nova com um PIN aleatório. Devolve true se deu certo.
  Future<bool> iniciar() async {
    await encerrar();
    erro.value = null;

    final pronto = await FirebaseBootstrap.garantirPronto();
    if (!pronto) {
      erro.value = FirebaseBootstrap.erro;
      return false;
    }

    final db = FirebaseDatabase.instance;
    await _Relogio.sincronizar(db);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final aleatorio = Random.secure();

    for (var tentativa = 0; tentativa < 12; tentativa++) {
      final candidato = (100000 + aleatorio.nextInt(900000)).toString();
      final ref = db.ref('sessoes/$candidato');
      try {
        // As regras recusam se o PIN já estiver em uso por outra TV.
        await ref.set({
          'donoTv': uid,
          'expiraEm': _Relogio.agora() + _validadeMs,
          'urlAtual': '',
        }).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        erro.value = 'Sem conexão com a internet.';
        return false;
      } catch (_) {
        continue; // PIN ocupado: sorteia outro
      }

      _ref = ref;
      _primeiroControle = true;
      _ultimoSeq = null;
      pin.value = candidato;

      // Se a TV cair ou o app fechar, o servidor apaga a sessão sozinho.
      unawaited(ref.onDisconnect().remove().catchError((_) {}));

      _subSessao = ref.onValue.listen((evento) {
        final valor = evento.snapshot.value;
        celularConectado.value = valor is Map && valor['celularUid'] != null;
      });
      _subControle = ref.child('controle').onValue.listen(_aoMudarControle);
      _timer = Timer.periodic(_batimento, (_) => _renovar());
      return true;
    }

    erro.value = 'Não consegui gerar um PIN livre. Tente novamente.';
    return false;
  }

  void _renovar() {
    _ref?.child('expiraEm').set(_Relogio.agora() + _validadeMs).catchError((_) {});
  }

  void _aoMudarControle(DatabaseEvent evento) {
    final valor = evento.snapshot.value;
    if (valor is! Map) {
      _primeiroControle = false;
      return;
    }
    final seq = valor['seq'];
    final tipoTexto = valor['tipo'];
    final conteudo = valor['valor'];
    if (seq is! num || tipoTexto is! String || conteudo is! String) return;

    // O primeiro valor lido é o que já estava gravado: não executa.
    if (_primeiroControle) {
      _primeiroControle = false;
      _ultimoSeq = seq.toInt();
      return;
    }
    if (seq.toInt() == _ultimoSeq) return;
    _ultimoSeq = seq.toInt();

    final tipo = tipoComandoPorNome(tipoTexto);
    if (tipo == null) return;
    aoReceberComando?.call(Comando(seq: seq.toInt(), tipo: tipo, valor: conteudo));
  }

  /// Mostra no celular qual página está aberta na TV.
  void publicarUrl(String url) {
    final ref = _ref;
    if (ref == null) return;
    final cortada = url.length > 2000 ? url.substring(0, 2000) : url;
    ref.child('urlAtual').set(cortada).catchError((_) {});
  }

  /// Desconecta o celular atual, mas mantém o mesmo PIN.
  Future<void> desconectarCelular() async {
    final ref = _ref;
    if (ref == null) return;
    _primeiroControle = true;
    _ultimoSeq = null;
    try {
      await ref.child('celularUid').remove();
      await ref.child('controle').remove();
    } catch (_) {}
  }

  /// Encerra a sessão e apaga os dados do servidor.
  Future<void> encerrar() async {
    _timer?.cancel();
    _timer = null;
    await _subSessao?.cancel();
    await _subControle?.cancel();
    _subSessao = null;
    _subControle = null;

    final ref = _ref;
    _ref = null;
    pin.value = null;
    celularConectado.value = false;

    if (ref != null) {
      try {
        await ref.onDisconnect().cancel();
        await ref.remove().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }
}

// =============================================================================
// LADO DO CELULAR
// =============================================================================

class ControleRemoto {
  final ValueNotifier<bool> ativa = ValueNotifier<bool>(false);
  final ValueNotifier<String> urlDaTv = ValueNotifier<String>('');
  final ValueNotifier<String?> aviso = ValueNotifier<String?>(null);

  DatabaseReference? _ref;
  StreamSubscription<DatabaseEvent>? _sub;
  String? pin;

  /// Tenta parear. Devolve `null` se deu certo, ou a mensagem de erro.
  Future<String?> conectar(String pinDigitado) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pinDigitado)) {
      return 'O PIN tem 6 dígitos.';
    }
    final pronto = await FirebaseBootstrap.garantirPronto();
    if (!pronto) return FirebaseBootstrap.erro ?? 'Não foi possível conectar.';

    final db = FirebaseDatabase.instance;
    await _Relogio.sincronizar(db);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = db.ref('sessoes/$pinDigitado');

    try {
      final foto = await ref.get().timeout(const Duration(seconds: 8));
      final dados = foto.value;
      if (!foto.exists || dados is! Map) {
        return 'PIN não encontrado. Confira o número mostrado na TV.';
      }
      final expira = dados['expiraEm'];
      if (expira is! num || expira.toInt() < _Relogio.agora()) {
        return 'Esse PIN expirou. Gere um novo na TV.';
      }
      final atual = dados['celularUid'];
      if (atual != null && atual != uid) {
        return 'Esse PIN já está sendo usado por outro celular.';
      }
      if (atual == null) {
        // As regras só permitem gravar celularUid uma vez (quem chegar primeiro).
        await ref.child('celularUid').set(uid).timeout(const Duration(seconds: 8));
      }
    } on TimeoutException {
      return 'Sem resposta. Verifique a internet do celular e da TV.';
    } catch (_) {
      return 'Não foi possível parear (PIN incorreto, expirado ou em uso).';
    }

    await encerrar(apagarVinculo: false);
    _ref = ref;
    pin = pinDigitado;
    aviso.value = null;

    _sub = ref.onValue.listen((evento) {
      final valor = evento.snapshot.value;
      if (valor is! Map || valor['celularUid'] != uid) {
        // A TV fechou a sessão ou desconectou este celular.
        aviso.value = 'A TV encerrou a sessão. Digite um novo PIN.';
        encerrar(apagarVinculo: false);
        return;
      }
      final url = valor['urlAtual'];
      urlDaTv.value = url is String ? url : '';
    }, onError: (_) {
      aviso.value = 'Conexão perdida com a TV.';
      encerrar(apagarVinculo: false);
    });

    ativa.value = true;
    return null;
  }

  Future<String?> _enviar(TipoComando tipo, String valor) async {
    final ref = _ref;
    if (ref == null) return 'Você não está conectado a uma TV.';
    try {
      await ref.child('controle').set({
        'seq': DateTime.now().microsecondsSinceEpoch,
        'tipo': tipo.name,
        'valor': valor,
      }).timeout(const Duration(seconds: 6));
      return null;
    } on TimeoutException {
      return 'Sem resposta. Verifique a conexão.';
    } catch (_) {
      return 'A TV recusou o comando (a sessão pode ter expirado).';
    }
  }

  Future<String?> enviarTexto(String texto) {
    final cortado = texto.length > 2000 ? texto.substring(0, 2000) : texto;
    return _enviar(TipoComando.texto, cortado);
  }

  Future<String?> enviarUrl(String url) => _enviar(TipoComando.url, url);

  Future<String?> enviarAcao(AcaoRemota acao) => _enviar(TipoComando.acao, acao.name);

  Future<void> encerrar({bool apagarVinculo = true}) async {
    await _sub?.cancel();
    _sub = null;
    final ref = _ref;
    _ref = null;
    pin = null;
    ativa.value = false;
    urlDaTv.value = '';
    if (apagarVinculo && ref != null) {
      try {
        await ref.child('celularUid').remove().timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }
}
