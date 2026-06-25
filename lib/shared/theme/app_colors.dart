import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0077BD);
  static const primaryDark = Color(0xFF004064);
  static const background = Color(0xFFEFF4F8);
  static const pageBackground = Color(0xFFF3F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const field = Color(0xFFFFFFFF);
  static const border = Color(0xFFD7E4EC);
  static const text = Color(0xFF162C3A);
  static const title = Color(0xFF003D60);
  static const muted = Color(0xFF5F7183);
  static const label = Color(0xFF5D6F80);
  static const smallText = Color(0xFF6B7C8E);
  static const iconMuted = Color(0xFF7B93A4);
  static const buttonSoft = Color(0xFFBDD9EA);
  static const green = Color(0xFF209F58);
  static const orange = Color(0xFFD97706);
  static const orangeText = Color(0xFFB96300);

  static const textStrong = text;
  static const textSecondary = label;
  static const textMuted = muted;
  static const textWeak = smallText;
  static const textCode = Color(0xFF334B5D);

  static const borderLight = Color(0xFFE4EDF4);
  static const borderField = Color(0xFFD8E6EE);

  static const bgHeader = Color(0xFFF8FBFD);
  static const bgButton = Color(0xFFF6F9FB);
  static const bgHover = Color(0xFFEAF7FF);
  static const bgSegment = Color(0xFFEEF5F9);
  static const bgProgress = Color(0xFFE9F0F5);

  static const danger = Color(0xFFD45B5B);
  static const dangerBg = Color(0xFFFFF0F0);

  static const dotAAbrir = muted;
  static const dotNaoIniciada = iconMuted;
  static const dotAndamento = primary;
  static const dotFinalizada = green;

  static const statusAAbrir = muted;
  static const statusNaoIniciada = smallText;
  static const statusAndamento = primary;
  static const statusFinalizada = green;

  static const bgAAbrir = Color(0xFFEFF3F7);
  static const bgNaoIniciada = Color(0xFFF8FBFD);
  static const bgAndamento = Color(0xFFE7F4FB);
  static const bgFinalizada = Color(0xFFE7F6EC);

  static const barGreen = green;
  static const barYellow = orange;
  static const barGray = iconMuted;
}
