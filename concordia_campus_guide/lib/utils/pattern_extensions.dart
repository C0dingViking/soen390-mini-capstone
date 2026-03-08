extension PatternFirstMatch on Pattern {
  Match? firstMatchOf(final String input, [final int start = 0]) {
    final matches = allMatches(input, start);
    return matches.isEmpty ? null : matches.first;
  }
}
