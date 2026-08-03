import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';

/// Persistência de mentira, igual à de `pending_mutation_test.dart` — guarda
/// em memória para exercitar o store sem depender de `localStorage`.
class _MemoryPersistence implements LocalJsonPersistence {
  _MemoryPersistence();

  String? payload;

  @override
  String get key => 'teste';

  @override
  String? read() => payload;

  @override
  void write(String value) => payload = value;

  @override
  void listen(void Function(String?) onChange) {}
}

PendingMutationStore _store() =>
    PendingMutationStore(persistence: _MemoryPersistence());

/// A OP real usada no plano de correção: `01427301001`, componente
/// `400-076`, saindo do almox. `03`. Números conferidos na SB2/SD4 em
/// 03/08/2026 — saldo 3.796, empenhado total 1.700, dos quais 1.500 são desta
/// mesma OP.
const _op = '01427301001';
const _produto = '400-076';
const _local = '03';

const _baseCatalogo = [
  SaldoArmazem(filial: '04', local: _local, saldo: 3796, empenhado: 1700),
];

const _baseOp = [
  ProtheusEmpenho(
    filial: '04',
    op: _op,
    produto: _produto,
    local: _local,
    quantidade: 1500,
  ),
];

/// A reserva do disponível por armazém não pode contar a própria OP duas
/// vezes: o `B2_QEMP` do Protheus já inclui o que ela reservou.
///
/// Bug real, achado batendo o app contra a SB2 em 03/08/2026: 184 das 1.610
/// linhas de empenho da filial 04 (11%) apareciam com "falta material" sem
/// ser verdade, porque o disponível descontava o próprio empenho da OP.
void main() {
  group('disponivelPara não desconta o empenho da própria OP duas vezes', () {
    test('sem fila: soma de volta o que a OP já reservou', () {
      final store = _store();

      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: _local,
        baseCatalogo: _baseCatalogo,
        op: _op,
        baseOp: _baseOp,
      );

      // 3796 - 1700 + 1500 (reserva desta OP, somada de volta) = 3596.
      // Sem a correção o valor seria 2096, o "alerta falso" do bug.
      expect(disponivel, 3596);
    });

    test('sem op informada, comporta-se como abertura de OP nova', () {
      final store = _store();

      // Abrir OP nova não tem reserva própria para somar de volta — o
      // disponível é só saldo menos empenhado, igual a saldosEfetivos.
      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: _local,
        baseCatalogo: _baseCatalogo,
      );

      expect(disponivel, 2096);
    });

    test('editar a própria OP de novo, com mutação já na fila, não soma duas vezes', () {
      final store = _store();
      // Uma edição anterior desta mesma OP já está na fila, aumentando de
      // 1500 para 1800 no mesmo almoxarifado.
      store.enqueue(
        (id, agora) => EmpenhoMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          op: _op,
          operacao: EmpenhoOperacao.alterar,
          produto: _produto,
          produtoDescricao: 'TAMPA',
          local: _local,
          quantidade: 1800,
          quantidadeAnterior: 1500,
          localAnterior: _local,
        ),
      );

      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: _local,
        baseCatalogo: _baseCatalogo,
        op: _op,
        baseOp: _baseOp,
      );

      // A mutação da própria OP é excluída da projeção (excluirOp), e o que
      // volta é sempre a reserva REAL (SD4, 1500) — não a projetada — porque
      // o B2_QEMP no Protheus só muda quando a mutação for aplicada de
      // verdade. Resultado igual ao caso "sem fila": 3596.
      expect(disponivel, 3596);
    });
  });

  group('empenho de outra OP reserva saldo antes de chegar ao Protheus', () {
    test('empenho pendente de outra OP tira do disponível', () {
      final store = _store();
      store.enqueue(
        (id, agora) => EmpenhoMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Vera',
          op: '01427401001', // outra OP, mesmo produto e local
          operacao: EmpenhoOperacao.incluir,
          produto: _produto,
          produtoDescricao: 'TAMPA',
          local: _local,
          quantidade: 400,
        ),
      );

      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: _local,
        baseCatalogo: _baseCatalogo,
        op: _op,
        baseOp: _baseOp,
      );

      // 3596 (como antes) menos os 400 que a outra OP acabou de reservar.
      expect(disponivel, 3196);
    });

    test(
      'excluir um empenho pendente de outra OP devolve o saldo reservado',
      () {
        final store = _store();
        store.enqueue(
          (id, agora) => EmpenhoMutation(
            id: id,
            filial: '04',
            criadoEm: agora,
            autor: 'Vera',
            op: '01427401001',
            operacao: EmpenhoOperacao.excluir,
            produto: _produto,
            produtoDescricao: 'TAMPA',
            local: _local,
            quantidade: 0,
            quantidadeAnterior: 300,
            localAnterior: _local,
          ),
        );

        final disponivel = store.disponivelPara(
          produto: _produto,
          filial: '04',
          local: _local,
          baseCatalogo: _baseCatalogo,
          op: _op,
          baseOp: _baseOp,
        );

        // Excluir libera: 3596 + 300 que deixaram de estar reservados.
        expect(disponivel, 3896);
      },
    );

    test('empenho pendente que muda de armazém move o comprometido junto', () {
      final store = _store();
      store.enqueue(
        (id, agora) => EmpenhoMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Vera',
          op: '01427401001',
          operacao: EmpenhoOperacao.alterar,
          produto: _produto,
          produtoDescricao: 'TAMPA',
          local: '10',
          quantidade: 200,
          quantidadeAnterior: 200,
          localAnterior: _local,
        ),
      );

      final noLocalAntigo = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: _local,
        baseCatalogo: _baseCatalogo,
        op: _op,
        baseOp: _baseOp,
      );
      final noLocalNovo = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: '10',
        baseCatalogo: _baseCatalogo,
        op: _op,
        baseOp: _baseOp,
      );

      // Saiu do 03 (libera 200) e entrou no 10 (reserva 200), que não tinha
      // posição na base — nasce zerado, como o Protheus faria.
      expect(noLocalAntigo, 3796);
      expect(noLocalNovo, -200);
    });
  });

  group('transferência e empenho pendentes juntos, no mesmo produto', () {
    test('uma transferência move saldo e um empenho de outra OP reserva', () {
      final store = _store();
      store.enqueue(
        (id, agora) => TransferenciaMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          produto: _produto,
          produtoDescricao: 'TAMPA',
          quantidade: 500,
          localOrigem: _local,
          localDestino: '10',
        ),
      );
      store.enqueue(
        (id, agora) => EmpenhoMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Vera',
          op: '01427401001',
          operacao: EmpenhoOperacao.incluir,
          produto: _produto,
          produtoDescricao: 'TAMPA',
          local: '10',
          quantidade: 100,
        ),
      );

      final noDestino = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: '10',
        baseCatalogo: _baseCatalogo,
        op: _op,
        baseOp: _baseOp,
      );

      // Chegaram 500 de saldo, e uma outra OP já reservou 100 deles.
      expect(noDestino, 400);
    });
  });

  group('sem posição no armazém — distinto de saldo zero', () {
    test('produto sem nenhuma linha SB2 no local devolve null', () {
      final store = _store();

      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: '99', // armazém sem posição nenhuma para este produto
        baseCatalogo: _baseCatalogo,
      );

      expect(disponivel, isNull);
    });

    test('posição real zerada continua devolvendo zero, não null', () {
      final store = _store();
      const baseComZero = [
        SaldoArmazem(filial: '04', local: '05', saldo: 0, empenhado: 0),
      ];

      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: '05',
        baseCatalogo: baseComZero,
      );

      expect(disponivel, 0);
    });

    test(
      'armazém sem posição na base, mas que vai receber uma transferência, deixa de ser null',
      () {
        final store = _store();
        store.enqueue(
          (id, agora) => TransferenciaMutation(
            id: id,
            filial: '04',
            criadoEm: agora,
            autor: 'Bryan',
            produto: _produto,
            produtoDescricao: 'TAMPA',
            quantidade: 120,
            localOrigem: _local,
            localDestino: '99',
          ),
        );

        final disponivel = store.disponivelPara(
          produto: _produto,
          filial: '04',
          local: '99',
          baseCatalogo: _baseCatalogo,
        );

        expect(disponivel, 120);
      },
    );
  });

  group('saldo negativo sobrevive à projeção', () {
    test('disponível negativo não é escondido nem zerado', () {
      final store = _store();
      const baseNegativa = [
        SaldoArmazem(filial: '04', local: _local, saldo: 100, empenhado: 500),
      ];

      final disponivel = store.disponivelPara(
        produto: _produto,
        filial: '04',
        local: _local,
        baseCatalogo: baseNegativa,
      );

      expect(disponivel, -400);
    });
  });

  group('mutações continuam sempre com a filial 04', () {
    // A Vetti passou a operar só a filial 04 em 03/08/2026 — não é mais uma
    // escolha do operador. O contrato de que toda mutação carrega a filial
    // que a criou continua valendo; quem decide qual filial vai é a
    // FilialStore (ver filial_isolamento_test.dart e filial_store.dart), e
    // hoje ela só oferece '04'.
    test('empenho gravado na fila carrega a filial de quem o criou', () {
      final store = _store();
      final m = store.enqueue(
        (id, agora) => EmpenhoMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          op: _op,
          operacao: EmpenhoOperacao.incluir,
          produto: _produto,
          produtoDescricao: 'TAMPA',
          local: _local,
          quantidade: 100,
        ),
      );

      expect(m.filial, '04');
    });

    test('transferência gravada na fila carrega a filial de quem a criou', () {
      final store = _store();
      final m = store.enqueue(
        (id, agora) => TransferenciaMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          produto: _produto,
          produtoDescricao: 'TAMPA',
          quantidade: 50,
          localOrigem: _local,
          localDestino: '10',
        ),
      );

      expect(m.filial, '04');
    });
  });
}
