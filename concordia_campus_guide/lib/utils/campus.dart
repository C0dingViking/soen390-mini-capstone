enum Campus { sgw, loyola }

Campus? parseCampus(String input) {
  final s = input.trim().toLowerCase();
  if (s == 'sgw' || s.contains('sir george') || s.contains('williams')) return Campus.sgw;
  if (s == 'loyola' || s == 'loy') return Campus.loyola;
  return null;
}