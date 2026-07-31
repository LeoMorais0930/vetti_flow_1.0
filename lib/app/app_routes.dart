import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';
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

Map<String, WidgetBuilder> vettiFlowRoutes() {
  return {
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
    FilaProtheusPage.rota: (context) => const FilaProtheusPage(),
    '/tv': (context) => const VettiFlowTvPage(),
  };
}
