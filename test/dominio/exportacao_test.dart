import 'package:controle_gastos/dados/exportacao.dart';
import 'package:controle_gastos/dominio/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gera CSV no formato do Excel brasileiro, escapando texto', () {
    final csv = gerarCsv(
      lancamentos: [
        Lancamento(id: 'a', contaId: 'c1', categoriaId: 'k1', valorCentavos: 123456, data: DateTime(2026, 10, 5), compraId: 'a'),
        Lancamento(
          id: 'b', contaId: 'c1', categoriaId: 'k1', valorCentavos: 3333, data: DateTime(2026, 11, 5),
          compraId: 'x', descricao: 'TV; "sala"', parcelaNum: 2, parcelasTotal: 3,
        ),
      ],
      nomeCategoria: {'k1': 'Casa'},
      nomeConta: {'c1': 'Nubank'},
    );
    expect(
      csv,
      'data;valor;categoria;conta;descricao;parcela\r\n'
      '2026-10-05;1234,56;Casa;Nubank;;\r\n'
      '2026-11-05;33,33;Casa;Nubank;"TV; ""sala""";2/3\r\n',
    );
  });
}
