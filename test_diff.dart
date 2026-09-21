void main() {
  final now = DateTime.now();
  final dt = DateTime.parse("2026-09-20T18:30:00.000Z").toLocal();
  print(now);
  print(dt);
  print(now.difference(dt).inMinutes);
}
