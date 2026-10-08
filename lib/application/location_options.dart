import '../models/location_model.dart';

// Opciones de los filtros "País" y "Ciudad" (Reportes, Business Intelligence
// y Ubicaciones): salen de las ubicaciones existentes, sin repetir y en orden
// alfabético. Las ciudades se acotan al país elegido.
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

// Cómo se muestra una ubicación: "Ciudad, País" como línea principal y la zona
// (la descripción) aparte, o pegada después cuando solo cabe una línea.
String locationLabel(LocationModel l) => '${l.city}, ${l.country}';

String? locationZone(LocationModel l) {
  final zone = l.description?.trim();
  return zone == null || zone.isEmpty ? null : zone;
}

String locationLabelWithZone(LocationModel l) {
  final zone = locationZone(l);
  return zone == null ? locationLabel(l) : '${locationLabel(l)} · $zone';
}

// Texto sobre el que buscan todos los buscadores de ubicaciones: ciudad, país y
// descripción.
String locationSearchText(LocationModel l) =>
    '${l.city} ${l.country} ${l.description ?? ''}';

// ¿La ubicación cumple el país y la ciudad elegidos? Sin ubicación (null) solo
// pasa cuando no hay ningún país ni ciudad elegidos.
bool locationMatches(LocationModel? location, {String? country, String? city}) {
  if (country == null && city == null) return true;
  if (location == null) return false;
  if (country != null && location.country != country) return false;
  if (city != null && location.city != city) return false;
  return true;
}
