class AppDateUtils {
  const AppDateUtils._();

  static DateTime normalizeLocalDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime getTodayDate() {
    return normalizeLocalDate(DateTime.now());
  }

  static bool isFutureDate(DateTime date) {
    final normalizedDate = normalizeLocalDate(date);
    final today = getTodayDate();
    return normalizedDate.isAfter(today);
  }

  static String formatDateBr(DateTime date) {
    final normalized = normalizeLocalDate(date);
    final day = normalized.day.toString().padLeft(2, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final year = normalized.year.toString();
    return '$day/$month/$year';
  }
}
