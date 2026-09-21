void main() {
  final d = DateTime.tryParse("2026-09-20T18:30:00.000Z")?.toLocal();
  print(d);
}
