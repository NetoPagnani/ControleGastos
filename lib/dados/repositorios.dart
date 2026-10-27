import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/usuario_atual.dart';
import '../dominio/modelos.dart';
import '../dominio/parcelamento.dart';
import 'gravacao.dart';

const _uuid = Uuid();

String agoraIso() => DateTime.now().toUtc().toIso8601String();

/// Data como texto YYYY-MM-DD. Comparar esse texto ja ordena por data,
/// entao os filtros de periodo do Firestore funcionam direto nele.
String formatarData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Tudo de um usuario fica em usuarios/{uid}/{nome}. As regras do
/// Firestore so deixam cada pessoa ler e gravar dentro do proprio uid.
CollectionReference<Map<String, dynamic>> colecaoDoUsuario(FirebaseFirestore db, String usuarioId, String nome) =>
    db.collection('usuarios').doc(usuarioId).collection(nome);

String _padraoUsuarioAtual() => usuarioAtualId;

/// Leitura so do aparelho, para o que o app ja esta mostrando (e portanto
/// ja esta no cache): nao espera a rede e nao gasta leituras do plano.
const doAparelho = GetOptions(source: Source.cache);

class CategoriasRepositorio {
  CategoriasRepositorio(this._db, {String Function()? usuarioAtual})
      : _usuarioAtual = usuarioAtual ?? _padraoUsuarioAtual;

  final FirebaseFirestore _db;
  final String Function() _usuarioAtual;

  static const padroes = [
    'Alimentação', 'Transporte', 'Casa', 'Saúde', 'Lazer',
    'Compras', 'Educação', 'Assinaturas', 'Outros',
  ];

  /// Id determinístico: mesmo usuario + mesmo nome gera o mesmo id em
  /// qualquer aparelho. Assim, dois aparelhos offline nao duplicam a categoria.
  static String idPadrao(String usuarioId, String nome) =>
      _uuid.v5(Namespace.url.value, '$usuarioId:${nome.toLowerCase()}');

  CollectionReference<Map<String, dynamic>> _colecao(String usuarioId) =>
      colecaoDoUsuario(_db, usuarioId, 'categorias');

  /// So cria as que ainda nao existem, para nao desfazer nome editado
  /// nem desarquivar o que a pessoa arquivou. Se a resposta veio so do
  /// cache (sem internet), nao da para saber o que existe: nao faz nada e
  /// tenta de novo no proximo login.
  Future<void> garantirPadroes(String usuarioId) async {
    final atual = await _colecao(usuarioId).get();
    if (atual.metadata.isFromCache) return;
    final existentes = atual.docs.map((d) => d.id).toSet();
    final agora = agoraIso();
    final lote = _db.batch();
    var algum = false;
    for (var i = 0; i < padroes.length; i++) {
      final id = idPadrao(usuarioId, padroes[i]);
      if (existentes.contains(id)) continue;
      algum = true;
      lote.set(_colecao(usuarioId).doc(id), {
        'nome': padroes[i],
        'icone': null,
        'cor': null,
        'ordem': i,
        'arquivada': false,
        'criado_em': agora,
        'atualizado_em': agora,
      });
    }
    if (algum) gravarSemEsperar(lote.commit());
  }

  Stream<List<Categoria>> observarAtivas(String usuarioId) {
    return _colecao(usuarioId).where('arquivada', isEqualTo: false).snapshots().map((s) {
      final lista = [
        for (final d in s.docs)
          Categoria(id: d.id, nome: d['nome'] as String, ordem: d['ordem'] as int),
      ];
      lista.sort((a, b) {
        final porOrdem = a.ordem.compareTo(b.ordem);
        return porOrdem != 0 ? porOrdem : a.nome.compareTo(b.nome);
      });
      return lista;
    });
  }

  /// Categoria criada pela pessoa (fora das 9 padrao). Id aleatorio: nao
  /// precisa ser deterministico porque so existe depois que a pessoa pediu.
  Future<void> criar(String usuarioId, String nome) async {
    final docs = (await _colecao(usuarioId).get(doAparelho)).docs;
    var maior = -1;
    for (final d in docs) {
      final ordem = d['ordem'] as int;
      if (ordem > maior) maior = ordem;
    }
    final agora = agoraIso();
    gravarSemEsperar(_colecao(usuarioId).doc(_uuid.v4()).set({
      'nome': nome,
      'icone': null,
      'cor': null,
      'ordem': maior + 1,
      'arquivada': false,
      'criado_em': agora,
      'atualizado_em': agora,
    }));
  }

  Future<void> arquivar(String id) async {
    gravarSemEsperar(_colecao(_usuarioAtual()).doc(id).update({'arquivada': true, 'atualizado_em': agoraIso()}));
  }

  Future<void> renomear(String id, String nome) async {
    gravarSemEsperar(_colecao(_usuarioAtual()).doc(id).update({'nome': nome, 'atualizado_em': agoraIso()}));
  }

  /// Nome de toda categoria, arquivada ou nao. O historico continua
  /// mostrando o nome certo depois que a categoria sai da lista.
  Stream<Map<String, String>> observarNomes(String usuarioId) {
    return _colecao(usuarioId).snapshots().map((s) => {for (final d in s.docs) d.id: d['nome'] as String});
  }
}

class PerfilRepositorio {
  // usuarioAtual so para ter o mesmo construtor dos outros repositorios:
  // toda funcao do perfil ja recebe o id.
  PerfilRepositorio(this._db, {String Function()? usuarioAtual});

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String usuarioId) => _db.collection('usuarios').doc(usuarioId);

  /// Cria o perfil se ainda nao existir, sem tocar na renda se ja existir.
  /// Chamado a cada login; so o primeiro realmente grava.
  /// Resposta so do cache (sem internet) nao prova que o perfil nao existe:
  /// gravar ali zeraria a renda.
  Future<void> garantirPerfil(String usuarioId) async {
    final atual = await _doc(usuarioId).get();
    if (atual.exists || atual.metadata.isFromCache) return;
    final agora = agoraIso();
    gravarSemEsperar(_doc(usuarioId).set({
      'nome': null,
      'renda_mensal_centavos': 0,
      'criado_em': agora,
      'atualizado_em': agora,
    }, SetOptions(merge: true)));
  }

  /// Renda de referencia. Nao e transacao, so um numero que a pessoa ajusta
  /// quando muda de salario; destrava o percentual comprometido no Inicio.
  Stream<int> observarRendaCentavos(String usuarioId) {
    return _doc(usuarioId).snapshots().map((d) => (d.data()?['renda_mensal_centavos'] as int?) ?? 0);
  }

  Future<void> definirRendaCentavos(String usuarioId, int centavos) async {
    gravarSemEsperar(_doc(usuarioId).set(
      {'renda_mensal_centavos': centavos, 'atualizado_em': agoraIso()},
      SetOptions(merge: true),
    ));
  }
}

class ContasRepositorio {
  ContasRepositorio(this._db, {String Function()? usuarioAtual})
      : _usuarioAtual = usuarioAtual ?? _padraoUsuarioAtual;

  final FirebaseFirestore _db;
  final String Function() _usuarioAtual;

  CollectionReference<Map<String, dynamic>> _colecao(String usuarioId) =>
      colecaoDoUsuario(_db, usuarioId, 'contas');

  Future<String> criar({
    required String usuarioId,
    required String apelido,
    required String tipo,
    int? limiteCentavos,
    int? diaFechamento,
    int? diaVencimento,
  }) async {
    final id = _uuid.v4();
    final agora = agoraIso();
    gravarSemEsperar(_colecao(usuarioId).doc(id).set({
      'apelido': apelido,
      'tipo': tipo,
      'cor': null,
      'icone': null,
      'arquivada': false,
      'limite_centavos': limiteCentavos,
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
      'criado_em': agora,
      'atualizado_em': agora,
    }));
    return id;
  }

  Future<void> arquivar(String id) async {
    gravarSemEsperar(_colecao(_usuarioAtual()).doc(id).update({'arquivada': true, 'atualizado_em': agoraIso()}));
  }

  /// O tipo nao muda depois de criada: trocar cartao por debito deixaria
  /// as parcelas ja lancadas sem fatura.
  Future<void> editar({
    required String id,
    required String apelido,
    int? limiteCentavos,
    int? diaFechamento,
    int? diaVencimento,
  }) async {
    gravarSemEsperar(_colecao(_usuarioAtual()).doc(id).update({
      'apelido': apelido,
      'limite_centavos': limiteCentavos,
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
      'atualizado_em': agoraIso(),
    }));
  }

  /// Apelido de toda conta, arquivada ou nao (mesmo motivo das categorias).
  Stream<Map<String, String>> observarNomes(String usuarioId) {
    return _colecao(usuarioId).snapshots().map((s) => {for (final d in s.docs) d.id: d['apelido'] as String});
  }

  Stream<List<Conta>> observarAtivas(String usuarioId) {
    return _colecao(usuarioId).where('arquivada', isEqualTo: false).snapshots().map((s) {
      final lista = [
        for (final d in s.docs)
          Conta(
            id: d.id,
            apelido: d['apelido'] as String,
            tipo: d['tipo'] as String,
            limiteCentavos: d['limite_centavos'] as int?,
            diaFechamento: d['dia_fechamento'] as int?,
            diaVencimento: d['dia_vencimento'] as int?,
          ),
      ];
      lista.sort((a, b) => a.apelido.compareTo(b.apelido));
      return lista;
    });
  }
}

class LancamentosRepositorio {
  LancamentosRepositorio(this._db, {String Function()? usuarioAtual})
      : _usuarioAtual = usuarioAtual ?? _padraoUsuarioAtual;

  final FirebaseFirestore _db;
  final String Function() _usuarioAtual;

  CollectionReference<Map<String, dynamic>> _colecao(String usuarioId) =>
      colecaoDoUsuario(_db, usuarioId, 'lancamentos');

  /// Lanca uma compra. Se for parcelada, cria um documento por parcela,
  /// todos com o mesmo compra_id, usando as regras da Fase 1.
  Future<void> lancarCompra({
    required String usuarioId,
    required String contaId,
    required String categoriaId,
    required int totalCentavos,
    required DateTime data,
    int parcelas = 1,
    String? descricao,
  }) async {
    final ids = List.generate(parcelas, (_) => _uuid.v4());
    // Compra simples: o compra_id e o proprio id, como na spec.
    final compraId = parcelas == 1 ? ids.first : _uuid.v4();
    final valores = dividirEmParcelas(totalCentavos, parcelas);
    final datas = datasDasParcelas(data, parcelas);
    final agora = agoraIso();

    final lote = _db.batch();
    for (var i = 0; i < parcelas; i++) {
      lote.set(_colecao(usuarioId).doc(ids[i]), {
        'conta_id': contaId,
        'categoria_id': categoriaId,
        'valor_centavos': valores[i],
        'descricao': descricao,
        'data': formatarData(datas[i]),
        'compra_id': compraId,
        'parcela_num': i + 1,
        'parcelas_total': parcelas,
        'criado_em': agora,
        'atualizado_em': agora,
      });
    }
    gravarSemEsperar(lote.commit());
  }

  /// Apaga uma compra inteira (todas as parcelas de uma vez).
  Future<void> apagarCompra(String compraId) async {
    final parcelas = await _colecao(_usuarioAtual()).where('compra_id', isEqualTo: compraId).get(doAparelho);
    final lote = _db.batch();
    for (final d in parcelas.docs) {
      lote.delete(d.reference);
    }
    gravarSemEsperar(lote.commit());
  }

  /// Apaga so uma parcela.
  Future<void> apagarParcela(String id) async {
    gravarSemEsperar(_colecao(_usuarioAtual()).doc(id).delete());
  }

  /// Edita uma parcela (ou um gasto simples) por inteiro.
  Future<void> editarParcela({
    required String id,
    required String contaId,
    required String categoriaId,
    required int valorCentavos,
    required DateTime data,
    String? descricao,
  }) async {
    gravarSemEsperar(_colecao(_usuarioAtual()).doc(id).update({
      'conta_id': contaId,
      'categoria_id': categoriaId,
      'valor_centavos': valorCentavos,
      'data': formatarData(data),
      'descricao': descricao,
      'atualizado_em': agoraIso(),
    }));
  }

  /// Edita o que e comum a todas as parcelas. Valor e data ficam de fora:
  /// cada parcela tem os seus, e mudar o total refaria a divisao.
  Future<void> editarCompra({
    required String compraId,
    required String contaId,
    required String categoriaId,
    String? descricao,
  }) async {
    final parcelas = await _colecao(_usuarioAtual()).where('compra_id', isEqualTo: compraId).get(doAparelho);
    final agora = agoraIso();
    final lote = _db.batch();
    for (final d in parcelas.docs) {
      lote.update(d.reference, {
        'conta_id': contaId,
        'categoria_id': categoriaId,
        'descricao': descricao,
        'atualizado_em': agora,
      });
    }
    gravarSemEsperar(lote.commit());
  }

  /// Conta e categoria do ultimo gasto lancado, para vir pre-selecionadas.
  Future<({String contaId, String categoriaId})?> ultimaEscolha(String usuarioId) async {
    final s = await _colecao(usuarioId).orderBy('criado_em', descending: true).limit(1).get();
    if (s.docs.isEmpty) return null;
    final d = s.docs.first;
    return (contaId: d['conta_id'] as String, categoriaId: d['categoria_id'] as String);
  }

  /// Todos os lancamentos, mais antigos primeiro. Usado pela exportacao CSV.
  Future<List<Lancamento>> todos(String usuarioId) async {
    final s = await _colecao(usuarioId).get();
    final docs = [...s.docs]..sort((a, b) {
        final porData = (a['data'] as String).compareTo(b['data'] as String);
        return porData != 0 ? porData : (a['criado_em'] as String).compareTo(b['criado_em'] as String);
      });
    return [for (final d in docs) deDocumento(d)];
  }

  static Lancamento deDocumento(DocumentSnapshot<Map<String, dynamic>> d) => Lancamento(
        id: d.id,
        contaId: d['conta_id'] as String,
        categoriaId: d['categoria_id'] as String,
        valorCentavos: d['valor_centavos'] as int,
        descricao: d['descricao'] as String?,
        data: DateTime.parse(d['data'] as String),
        compraId: d['compra_id'] as String,
        parcelaNum: d['parcela_num'] as int,
        parcelasTotal: d['parcelas_total'] as int,
      );

  /// Lancamentos com data entre [inicio] (incluso) e [fim] (excluso).
  Stream<List<Lancamento>> observarPeriodo({
    required String usuarioId,
    required DateTime inicio,
    required DateTime fim,
  }) {
    return _colecao(usuarioId)
        .where('data', isGreaterThanOrEqualTo: formatarData(inicio))
        .where('data', isLessThan: formatarData(fim))
        .snapshots()
        .map((s) {
      final docs = [...s.docs]..sort((a, b) {
          final porData = (b['data'] as String).compareTo(a['data'] as String);
          return porData != 0 ? porData : (b['criado_em'] as String).compareTo(a['criado_em'] as String);
        });
      return [for (final d in docs) deDocumento(d)];
    });
  }
}
