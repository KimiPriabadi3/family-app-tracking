/// How much a status is still worth believing. A status set this morning must
/// not look identical to one set a minute ago, so it fades as it ages and, past
/// half a day, says outright that nobody has updated it.
enum Freshness { fresh, recent, aging, stale }

Freshness freshnessOf(DateTime? stampedAt) {
  if (stampedAt == null) return Freshness.stale;
  final age = DateTime.now().difference(stampedAt);
  if (age.inMinutes < 45) return Freshness.fresh;
  if (age.inHours < 4) return Freshness.recent;
  if (age.inHours < 12) return Freshness.aging;
  return Freshness.stale;
}

extension FreshnessX on Freshness {
  double get inkOpacity {
    switch (this) {
      case Freshness.fresh:
        return 1;
      case Freshness.recent:
        return 0.9;
      case Freshness.aging:
        return 0.72;
      case Freshness.stale:
        return 0.55;
    }
  }

  bool get isStale => this == Freshness.stale;
}
