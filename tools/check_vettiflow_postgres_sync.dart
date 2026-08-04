import 'dart:io';

import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';

Future<void> main() async {
  final password = Platform.environment['VETTIFLOW_PG_PASSWORD'];
  if (password == null || password.isEmpty) {
    throw StateError('Defina VETTIFLOW_PG_PASSWORD antes de rodar o check.');
  }

  final products = PostgresProtheusProductRepository(password: password);
  final database = PostgresProductionFlowDatabase(password: password);

  final lookup = await products.lookupByCode('730-0863');
  if (lookup == null) {
    throw StateError('Produto 730-0863 nao encontrado na SB1.');
  }
  if (!lookup.isReleasedBySmd) {
    throw StateError('Produto 730-0863 nao encontrou OP SMD vinculada.');
  }
  final stockShortages = lookup.stockShortagesFor(1);
  if (stockShortages.isNotEmpty) {
    stdout.writeln(
      'OK: validacao de estoque detectou bloqueio em ${stockShortages.first.label}.',
    );
  }
  final suggestions = await products.searchProducts('central');
  if (suggestions.every((product) => product.code != '730-0863')) {
    throw StateError('Autocomplete nao encontrou a central na SB1.');
  }

  final now = DateTime.now();
  final order = ProductionOrderFlow(
    number: 'OP-CHECK-${now.microsecondsSinceEpoch}',
    productCode: lookup.product.code,
    productName: lookup.product.description,
    quantity: 1,
    currentStage: ProductionStage.warehouse,
    status: ProductionRunStatus.waiting,
    priority: 'Media',
    createdAt: now,
    updatedAt: now,
    responsavel: 'Check',
    prazo: '31/07/2026',
  );
  final catalogItem = ProductionCatalogItem(
    code: lookup.product.code,
    name: lookup.product.description,
    defaultQuantity: 1,
    components: lookup.toProductionComponents(),
  );

  await database.saveOrder(order, catalogItem, eventType: 'check');
  await database.deleteOrder(order.number);

  stdout.writeln('OK: SB1, estrutura e sync vettiflow.* responderam.');
  exit(0);
}
