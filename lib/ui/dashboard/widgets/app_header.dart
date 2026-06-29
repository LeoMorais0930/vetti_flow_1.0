import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback onNovaOP;

  const AppHeader({super.key, required this.onNovaOP});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Painel de Produção',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Terça-feira, 24 de junho de 2026',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/login'),
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          _NovaOPButton(onPressed: onNovaOP),
        ],
      ),
    );
  }
}

class _NovaOPButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NovaOPButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Text('+', style: TextStyle(fontSize: 17)),
      label: const Text('Nova OP'),
    );
  }
}
