import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/auth/widgets/login_brand_panel.dart';
import 'package:vetti_flow_1_0/ui/auth/widgets/login_form_panel.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<OpRepository>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => DashboardCubit(repo),
          child: const DashboardPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 920;

            if (!isDesktop) {
              return _MobileLoginLayout(
                formKey: _formKey,
                userController: _userController,
                passwordController: _passwordController,
                onSubmit: _submit,
              );
            }

            return _DesktopLoginLayout(
              formKey: _formKey,
              userController: _userController,
              passwordController: _passwordController,
              onSubmit: _submit,
            );
          },
        ),
      ),
    );
  }
}

class _DesktopLoginLayout extends StatelessWidget {
  const _DesktopLoginLayout({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 26, 30, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1196),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Flexible(
                flex: 558,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LoginBrandPanel(),
                ),
              ),
              const Spacer(flex: 144),
              Flexible(
                flex: 325,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LoginFormPanel(
                    formKey: formKey,
                    userController: userController,
                    passwordController: passwordController,
                    onSubmit: onSubmit,
                  ),
                ),
              ),
              const Spacer(flex: 169),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileLoginLayout extends StatelessWidget {
  const _MobileLoginLayout({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        children: [
          const SizedBox(height: 320, child: LoginBrandPanel(compact: true)),
          const SizedBox(height: 36),
          LoginFormPanel(
            formKey: formKey,
            userController: userController,
            passwordController: passwordController,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}
