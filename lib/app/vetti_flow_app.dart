import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/auth/login_page.dart';

class VettiFlowApp extends StatelessWidget {
  const VettiFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VettiFlow 1.0',
      theme: AppTheme.light,
      home: const LoginPage(),
    );
  }
}
