import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';

class VettiFlowApp extends StatelessWidget {
  const VettiFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductionFlowStore>(
          create: (_) => ProductionFlowStore(),
        ),
        ChangeNotifierProvider<OperatorAssignmentStore>(
          create: (_) => OperatorAssignmentStore(),
        ),
        RepositoryProvider<OpRepository>(
          create: (context) =>
              FlowOpRepository(context.read<ProductionFlowStore>()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VettiFlow 1.0',
        theme: AppTheme.light,
        initialRoute: '/login',
        routes: vettiFlowRoutes(),
      ),
    );
  }
}
