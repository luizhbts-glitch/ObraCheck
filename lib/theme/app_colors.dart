import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardSemNC,
    required this.cardSemNCText,
    required this.cardNCAberta,
    required this.cardNCAbertaText,
    required this.cardBackground,
    required this.cardBackgroundText,
    required this.primaryAction,
    required this.selected,
    required this.selectedText,
    required this.danger,
    required this.warning,
    required this.success,
    required this.disabled,
    required this.disabledText,
    required this.projectCardBackground,
    required this.projectAvatarBackground,
    required this.projectAvatarTextPrimary,
    required this.projectAvatarTextAccent,
    required this.statusOk,
    required this.statusNc,
    required this.statusDraft,
    required this.statusPending,
    required this.fvsOkContainer,
    required this.fvsOkForeground,
    required this.fvsOkBorder,
    required this.fvsNokContainer,
    required this.fvsNokForeground,
    required this.fvsNokBorder,
    required this.fvsXoContainer,
    required this.fvsXoForeground,
    required this.fvsXoBorder,
    required this.fvsNoneContainer,
    required this.fvsNoneForeground,
    required this.fvsNoneBorder,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;

  final Color cardSemNC;
  final Color cardSemNCText;
  final Color cardNCAberta;
  final Color cardNCAbertaText;
  final Color cardBackground;
  final Color cardBackgroundText;
  final Color primaryAction;
  final Color selected;
  final Color selectedText;
  final Color danger;
  final Color warning;
  final Color success;
  final Color disabled;
  final Color disabledText;
  final Color projectCardBackground;
  final Color projectAvatarBackground;
  final Color projectAvatarTextPrimary;
  final Color projectAvatarTextAccent;
  final Color statusOk;
  final Color statusNc;
  final Color statusDraft;
  final Color statusPending;
  final Color fvsOkContainer;
  final Color fvsOkForeground;
  final Color fvsOkBorder;
  final Color fvsNokContainer;
  final Color fvsNokForeground;
  final Color fvsNokBorder;
  final Color fvsXoContainer;
  final Color fvsXoForeground;
  final Color fvsXoBorder;
  final Color fvsNoneContainer;
  final Color fvsNoneForeground;
  final Color fvsNoneBorder;

  factory AppColors.light() {
    return const AppColors(
      background: Color(0xFFF3F6FB),
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFEAF0FA),
      border: Color(0xFFD4DEEA),
      borderStrong: Color(0xFF9FB1C8),
      textPrimary: Color(0xFF0F1E33),
      textSecondary: Color(0xFF4C617D),
      cardSemNC: Color(0xFFE1F8EB),
      cardSemNCText: Color(0xFF0E7A39),
      cardNCAberta: Color(0xFFFFF0BF),
      cardNCAbertaText: Color(0xFF8A5A00),
      cardBackground: Color(0xFFE7EDF6),
      cardBackgroundText: Color(0xFF51637E),
      primaryAction: Color(0xFFD62828),
      selected: Color(0xFF1E66F5),
      selectedText: Color(0xFFFFFFFF),
      danger: Color(0xFFD32F2F),
      warning: Color(0xFFE6A700),
      success: Color(0xFF1B8E46),
      disabled: Color(0xFFD5DCE6),
      disabledText: Color(0xFF71829B),
      projectCardBackground: Color(0xFFFFFFFF),
      projectAvatarBackground: Color(0xFFF1F3F5),
      projectAvatarTextPrimary: Color(0xFF6B7280),
      projectAvatarTextAccent: Color(0xFFDC2626),
      statusOk: Color(0xFF1B8E46),
      statusNc: Color(0xFFD32F2F),
      statusDraft: Color(0xFFB77900),
      statusPending: Color(0xFFB45309),
      fvsOkContainer: Color(0xFFEAF7EC),
      fvsOkForeground: Color(0xFF2E7D32),
      fvsOkBorder: Color(0xFF9FD2A6),
      fvsNokContainer: Color(0xFFFFEBEE),
      fvsNokForeground: Color(0xFFC62828),
      fvsNokBorder: Color(0xFFE5A6A6),
      fvsXoContainer: Color(0xFFFFF4E0),
      fvsXoForeground: Color(0xFFB26A00),
      fvsXoBorder: Color(0xFFE8C89A),
      fvsNoneContainer: Color(0xFFF1F1F1),
      fvsNoneForeground: Color(0xFF757575),
      fvsNoneBorder: Color(0xFFD0D0D0),
    );
  }

  factory AppColors.dark() {
    return const AppColors(
      // Camadas de fundo — hierarquia clara sem azul excessivo
      background: Color(0xFF111318),
      surface: Color(0xFF1B2030),
      surfaceAlt: Color(0xFF242A3A),
      border: Color(0xFF2C3347),
      borderStrong: Color(0xFF424E66),
      textPrimary: Color(0xFFEDF2FF),
      textSecondary: Color(0xFF8995B0),

      // Status cards
      cardSemNC: Color(0xFF0D2A1E),
      cardSemNCText: Color(0xFF6CE9B8),
      cardNCAberta: Color(0xFF281E00),
      cardNCAbertaText: Color(0xFFFBBF24),
      cardBackground: Color(0xFF1B2030),
      cardBackgroundText: Color(0xFFA4B4CC),

      // Ações e estados
      primaryAction: Color(0xFFE84040),
      selected: Color(0xFF5B9BF5),
      selectedText: Color(0xFF080E1A),
      danger: Color(0xFFF47171),
      warning: Color(0xFFF5C037),
      success: Color(0xFF40C88C),
      disabled: Color(0xFF242A3A),
      disabledText: Color(0xFF5E6E8A),

      // Projeto / avatar
      projectCardBackground: Color(0xFF1B2030),
      projectAvatarBackground: Color(0xFF262D3E),
      projectAvatarTextPrimary: Color(0xFFC8D0E0),
      projectAvatarTextAccent: Color(0xFFE84040),

      // Labels de status
      statusOk: Color(0xFF40C88C),
      statusNc: Color(0xFFF47171),
      statusDraft: Color(0xFFF5C037),
      statusPending: Color(0xFFF5A645),

      // FVS — conforme
      fvsOkContainer: Color(0xFF0D2A1E),
      fvsOkForeground: Color(0xFF6CE9B8),
      fvsOkBorder: Color(0xFF2A8C5D),

      // FVS — não conforme
      fvsNokContainer: Color(0xFF2A1015),
      fvsNokForeground: Color(0xFFFFAAB5),
      fvsNokBorder: Color(0xFFE85050),

      // FVS — conforme após correção
      fvsXoContainer: Color(0xFF281E00),
      fvsXoForeground: Color(0xFFFCD34D),
      fvsXoBorder: Color(0xFFC47D00),

      // FVS — sem marcação
      fvsNoneContainer: Color(0xFF1B2030),
      fvsNoneForeground: Color(0xFF8995B0),
      fvsNoneBorder: Color(0xFF2C3347),
    );
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? cardSemNC,
    Color? cardSemNCText,
    Color? cardNCAberta,
    Color? cardNCAbertaText,
    Color? cardBackground,
    Color? cardBackgroundText,
    Color? primaryAction,
    Color? selected,
    Color? selectedText,
    Color? danger,
    Color? warning,
    Color? success,
    Color? disabled,
    Color? disabledText,
    Color? projectCardBackground,
    Color? projectAvatarBackground,
    Color? projectAvatarTextPrimary,
    Color? projectAvatarTextAccent,
    Color? statusOk,
    Color? statusNc,
    Color? statusDraft,
    Color? statusPending,
    Color? fvsOkContainer,
    Color? fvsOkForeground,
    Color? fvsOkBorder,
    Color? fvsNokContainer,
    Color? fvsNokForeground,
    Color? fvsNokBorder,
    Color? fvsXoContainer,
    Color? fvsXoForeground,
    Color? fvsXoBorder,
    Color? fvsNoneContainer,
    Color? fvsNoneForeground,
    Color? fvsNoneBorder,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cardSemNC: cardSemNC ?? this.cardSemNC,
      cardSemNCText: cardSemNCText ?? this.cardSemNCText,
      cardNCAberta: cardNCAberta ?? this.cardNCAberta,
      cardNCAbertaText: cardNCAbertaText ?? this.cardNCAbertaText,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBackgroundText: cardBackgroundText ?? this.cardBackgroundText,
      primaryAction: primaryAction ?? this.primaryAction,
      selected: selected ?? this.selected,
      selectedText: selectedText ?? this.selectedText,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      disabled: disabled ?? this.disabled,
      disabledText: disabledText ?? this.disabledText,
      projectCardBackground: projectCardBackground ?? this.projectCardBackground,
      projectAvatarBackground: projectAvatarBackground ?? this.projectAvatarBackground,
      projectAvatarTextPrimary: projectAvatarTextPrimary ?? this.projectAvatarTextPrimary,
      projectAvatarTextAccent: projectAvatarTextAccent ?? this.projectAvatarTextAccent,
      statusOk: statusOk ?? this.statusOk,
      statusNc: statusNc ?? this.statusNc,
      statusDraft: statusDraft ?? this.statusDraft,
      statusPending: statusPending ?? this.statusPending,
      fvsOkContainer: fvsOkContainer ?? this.fvsOkContainer,
      fvsOkForeground: fvsOkForeground ?? this.fvsOkForeground,
      fvsOkBorder: fvsOkBorder ?? this.fvsOkBorder,
      fvsNokContainer: fvsNokContainer ?? this.fvsNokContainer,
      fvsNokForeground: fvsNokForeground ?? this.fvsNokForeground,
      fvsNokBorder: fvsNokBorder ?? this.fvsNokBorder,
      fvsXoContainer: fvsXoContainer ?? this.fvsXoContainer,
      fvsXoForeground: fvsXoForeground ?? this.fvsXoForeground,
      fvsXoBorder: fvsXoBorder ?? this.fvsXoBorder,
      fvsNoneContainer: fvsNoneContainer ?? this.fvsNoneContainer,
      fvsNoneForeground: fvsNoneForeground ?? this.fvsNoneForeground,
      fvsNoneBorder: fvsNoneBorder ?? this.fvsNoneBorder,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardSemNC: Color.lerp(cardSemNC, other.cardSemNC, t)!,
      cardSemNCText: Color.lerp(cardSemNCText, other.cardSemNCText, t)!,
      cardNCAberta: Color.lerp(cardNCAberta, other.cardNCAberta, t)!,
      cardNCAbertaText: Color.lerp(cardNCAbertaText, other.cardNCAbertaText, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBackgroundText: Color.lerp(cardBackgroundText, other.cardBackgroundText, t)!,
      primaryAction: Color.lerp(primaryAction, other.primaryAction, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      selectedText: Color.lerp(selectedText, other.selectedText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      projectCardBackground: Color.lerp(projectCardBackground, other.projectCardBackground, t)!,
      projectAvatarBackground: Color.lerp(projectAvatarBackground, other.projectAvatarBackground, t)!,
      projectAvatarTextPrimary: Color.lerp(projectAvatarTextPrimary, other.projectAvatarTextPrimary, t)!,
      projectAvatarTextAccent: Color.lerp(projectAvatarTextAccent, other.projectAvatarTextAccent, t)!,
      statusOk: Color.lerp(statusOk, other.statusOk, t)!,
      statusNc: Color.lerp(statusNc, other.statusNc, t)!,
      statusDraft: Color.lerp(statusDraft, other.statusDraft, t)!,
      statusPending: Color.lerp(statusPending, other.statusPending, t)!,
      fvsOkContainer: Color.lerp(fvsOkContainer, other.fvsOkContainer, t)!,
      fvsOkForeground: Color.lerp(fvsOkForeground, other.fvsOkForeground, t)!,
      fvsOkBorder: Color.lerp(fvsOkBorder, other.fvsOkBorder, t)!,
      fvsNokContainer: Color.lerp(fvsNokContainer, other.fvsNokContainer, t)!,
      fvsNokForeground: Color.lerp(fvsNokForeground, other.fvsNokForeground, t)!,
      fvsNokBorder: Color.lerp(fvsNokBorder, other.fvsNokBorder, t)!,
      fvsXoContainer: Color.lerp(fvsXoContainer, other.fvsXoContainer, t)!,
      fvsXoForeground: Color.lerp(fvsXoForeground, other.fvsXoForeground, t)!,
      fvsXoBorder: Color.lerp(fvsXoBorder, other.fvsXoBorder, t)!,
      fvsNoneContainer: Color.lerp(fvsNoneContainer, other.fvsNoneContainer, t)!,
      fvsNoneForeground: Color.lerp(fvsNoneForeground, other.fvsNoneForeground, t)!,
      fvsNoneBorder: Color.lerp(fvsNoneBorder, other.fvsNoneBorder, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
