import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';

/// Uma OP do Protheus ainda não trazida para o fluxo do VettiFlow.
class OrdemDisponivel {
  const OrdemDisponivel({
    required this.numero,
    required this.numeroLegivel,
    required this.produtoCodigo,
    required this.produto,
    required this.quantidade,
    this.previsao,
  });

  /// B1_COD do produto da OP, para filtrar a busca por código.
  final String produtoCodigo;

  /// Número em formato legível: `015942-01-001`.
  final String numeroLegivel;

  /// Número no formato do Protheus (número + item + sequência).
  final String numero;

  /// "código - descrição" do produto da OP.
  final String produto;

  final int quantidade;

  /// Previsão de término (C2_DATPRF), em dd/MM/yyyy.
  final String? previsao;

  String get label => '$numero · $produto';
}

/// Dados que o VettiFlow acrescenta ao adotar uma OP do Protheus.
///
/// Responsável e prioridade não vêm do ERP: a prioridade da SC2 é `500` em
/// todas as OPs deste ambiente, sem informação útil. São atributos do fluxo,
/// e portanto do VettiFlow.
class AdocaoOrdemDTO {
  const AdocaoOrdemDTO({
    required this.numero,
    required this.responsavel,
    this.prioridade = 'Media',
  });

  /// Número da OP no Protheus, o mesmo de [OrdemDisponivel.numero].
  final String numero;

  final String responsavel;
  final String prioridade;
}

abstract class OpRepository {
  Future<List<OrdemProducao>> fetchOrdens();
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas();

  /// OPs em aberto no Protheus que ainda não entraram no fluxo.
  Future<List<OrdemDisponivel>> fetchOrdensDisponiveis();

  /// Traz uma OP do Protheus para o fluxo. O VettiFlow não cria OPs.
  Future<OrdemProducao> adotarOrdem(AdocaoOrdemDTO dto);

  Future<void> avancarStatus(String numero, {int quantidadeArmazenada = 0});
  Future<void> voltarStatus(String numero);
  Future<void> cancelarOrdem(String numero);
  Future<List<Responsavel>> fetchResponsaveis();
}
