enum Campus { sgw, loyola }

Campus? parseCampus(String input) {
  final s = input.trim().toLowerCase();
  if (s == 'sgw' || s.contains('sir george')) return Campus.sgw;
  if (s == 'loyola') return Campus.loyola;
  return null;
}