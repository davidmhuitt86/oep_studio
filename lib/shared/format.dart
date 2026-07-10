/// Formats a [DateTime] as `YYYY-MM-DD HH:MM` (local time) — used
/// anywhere Studio displays a timestamp, without pulling in the
/// `intl` package for a single format.
String formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}
