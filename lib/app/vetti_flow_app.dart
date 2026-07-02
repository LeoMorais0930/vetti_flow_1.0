import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/auth/login_page.dart';
import 'package:vetti_flow_1_0/ui/closing/closing_page.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/dashboard_page.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_page.dart';
import 'package:vetti_flow_1_0/ui/firmware/firmware_page.dart';
import 'package:vetti_flow_1_0/ui/soldering/soldering_page.dart';
import 'package:vetti_flow_1_0/ui/support/support_page.dart';
import 'package:vetti_flow_1_0/ui/testing/testing_page.dart';
import 'package:vetti_flow_1_0/ui/tv/vetti_flow_tv_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_page.dart';

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
        routes: {
          '/login': (context) => const LoginPage(),
          '/dashboard': (context) => BlocProvider(
            create: (context) => DashboardCubit(context.read<OpRepository>()),
            child: const DashboardPage(),
          ),
          '/expedicao': (context) => const ExpeditionPage(),
          '/fechamento': (context) => const ClosingPage(),
          '/firmware': (context) => const FirmwarePage(),
          '/soldagem': (context) => const SolderingPage(),
          '/suporte': (context) => const SupportPage(),
          '/teste': (context) => const TestingPage(),
          '/almoxarifado': (context) => const WarehousePage(),
          '/tv': (context) => const VettiFlowTvPage(),
        },
      ),
    );
  }
}
