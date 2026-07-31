import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final OpRepository _repository;

  DashboardCubit(this._repository) : super(const DashboardState());

  Future<void> loadOrdens() async {
    final ordens = await _repository.fetchOrdens();
    final armazenadas = await _repository.fetchOrdensArmazenadas();
    final responsaveis = await _repository.fetchResponsaveis();
    final disponiveis = await _repository.fetchOrdensDisponiveis();
    emit(
      state.copyWith(
        ordens: ordens,
        armazenadas: armazenadas,
        responsaveis: responsaveis,
        ordensDisponiveis: disponiveis,
      ),
    );
  }

  void setViewMode(ViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  void toggleStatusFilter(StatusOP status) {
    emit(
      state.copyWith(
        filtroStatus: () => state.filtroStatus == status ? null : status,
      ),
    );
  }

  void setFiltroPeriodo(String value) {
    emit(state.copyWith(filtroPeriodo: value));
  }

  void setFiltroResponsavel(String value) {
    emit(state.copyWith(filtroResponsavel: value));
  }

  void setFiltroProduto(String value) {
    emit(state.copyWith(filtroProduto: value));
  }

  void setBusca(String value) {
    emit(state.copyWith(busca: value));
  }

  void limparFiltros() {
    emit(
      state.copyWith(
        filtroPeriodo: 'todos',
        filtroResponsavel: 'todos',
        filtroProduto: 'todos',
        filtroStatus: () => null,
        busca: '',
      ),
    );
  }

  void openOP(String numero) {
    emit(state.copyWith(selectedOP: () => numero, confirmCancel: false));
  }

  void closeOP() {
    emit(state.copyWith(selectedOP: () => null, confirmCancel: false));
  }

  Future<void> advanceOP({int quantidadeArmazenada = 0}) async {
    final op = state.selectedOP;
    if (op == null) return;
    await _repository.avancarStatus(
      op,
      quantidadeArmazenada: quantidadeArmazenada,
    );
    final ordens = await _repository.fetchOrdens();
    final armazenadas = await _repository.fetchOrdensArmazenadas();
    final disponiveis = await _repository.fetchOrdensDisponiveis();
    emit(
      state.copyWith(
        ordens: ordens,
        armazenadas: armazenadas,
        ordensDisponiveis: disponiveis,
      ),
    );
  }

  Future<void> regressOP() async {
    final op = state.selectedOP;
    if (op == null) return;
    await _repository.voltarStatus(op);
    final ordens = await _repository.fetchOrdens();
    final armazenadas = await _repository.fetchOrdensArmazenadas();
    final disponiveis = await _repository.fetchOrdensDisponiveis();
    emit(
      state.copyWith(
        ordens: ordens,
        armazenadas: armazenadas,
        ordensDisponiveis: disponiveis,
      ),
    );
  }

  void askCancel() {
    emit(state.copyWith(confirmCancel: true));
  }

  void cancelCancelation() {
    emit(state.copyWith(confirmCancel: false));
  }

  Future<void> cancelOP() async {
    final op = state.selectedOP;
    if (op == null) return;
    await _repository.cancelarOrdem(op);
    final ordens = await _repository.fetchOrdens();
    final armazenadas = await _repository.fetchOrdensArmazenadas();
    final disponiveis = await _repository.fetchOrdensDisponiveis();
    emit(
      state.copyWith(
        ordens: ordens,
        armazenadas: armazenadas,
        ordensDisponiveis: disponiveis,
        selectedOP: () => null,
        confirmCancel: false,
      ),
    );
  }

  void openNovaOP() {
    emit(state.copyWith(novaOPOpen: true));
  }

  void closeNovaOP() {
    emit(state.copyWith(novaOPOpen: false));
  }

  /// Traz uma OP do Protheus para o fluxo. O VettiFlow não cria OPs.
  Future<void> adotarOP(AdocaoOrdemDTO dto) async {
    await _repository.adotarOrdem(dto);
    final ordens = await _repository.fetchOrdens();
    final armazenadas = await _repository.fetchOrdensArmazenadas();
    final disponiveis = await _repository.fetchOrdensDisponiveis();
    emit(
      state.copyWith(
        ordens: ordens,
        armazenadas: armazenadas,
        ordensDisponiveis: disponiveis,
        novaOPOpen: false,
      ),
    );
  }

  void openFiltros() {
    emit(state.copyWith(filtrosOpen: true));
  }

  void closeFiltros() {
    emit(state.copyWith(filtrosOpen: false));
  }
}
