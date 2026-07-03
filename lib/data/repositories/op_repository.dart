import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';

class NovaOrdemDTO {
  final String produto;
  final int qtd;
  final String responsavel;
  final String prazo;
  final String prioridade;

  const NovaOrdemDTO({
    required this.produto,
    required this.qtd,
    required this.responsavel,
    required this.prazo,
    this.prioridade = 'Media',
  });
}

abstract class OpRepository {
  Future<List<OrdemProducao>> fetchOrdens();
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas();
  Future<OrdemProducao> criarOrdem(NovaOrdemDTO dto);
  Future<void> avancarStatus(String numero, {int quantidadeArmazenada = 0});
  Future<void> voltarStatus(String numero);
  Future<void> cancelarOrdem(String numero);
  Future<List<Responsavel>> fetchResponsaveis();
  Future<List<String>> fetchProdutos();
}
