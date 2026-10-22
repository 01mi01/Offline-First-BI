import '../models/location_model.dart';

List<String> countryOptions(Iterable<LocationModel> locations) {
  final countries = {for (final l in locations) l.country}.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return countries;
}

List<String> cityOptions(Iterable<LocationModel> locations, {String? country}) {
  final cities = {
    for (final l in locations)
      if (country == null || l.country == country) l.city,
  }.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return cities;
}

String locationLabel(LocationModel l) => '${l.city}, ${l.country}';

String? locationZone(LocationModel l) {
  final zone = l.description?.trim();
  return zone == null || zone.isEmpty ? null : zone;
}

String locationLabelWithZone(LocationModel l) {
  final zone = locationZone(l);
  return zone == null ? locationLabel(l) : '${locationLabel(l)} · $zone';
}

String locationSearchText(LocationModel l) =>
    '${l.city} ${l.country} ${l.description ?? ''}';

bool locationMatches(LocationModel? location, {String? country, String? city}) {
  if (country == null && city == null) return true;
  if (location == null) return false;
  if (country != null && location.country != country) return false;
  if (city != null && location.city != city) return false;
  return true;
}
