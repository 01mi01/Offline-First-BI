import '../../application/location_options.dart';
import '../../models/category_model.dart';
import '../../models/client_model.dart';
import '../../models/event_model.dart';
import '../../models/location_model.dart';
import '../../models/material_model.dart';
import '../../models/product_model.dart';
import '../../models/supplier_model.dart';
import '../../models/unit_model.dart';
import 'searchable_picker.dart';

List<PickerOption<int>> locationPickerOptions(
  Iterable<LocationModel> locations, {
  String? noneLabel,
  int? keepId,
  bool onlyActive = true,
}) => [
  if (noneLabel != null) PickerOption<int>(null, noneLabel),
  for (final l in locations)
    if (!onlyActive || l.isActive || l.id == keepId)
      PickerOption<int>(
        l.id,
        locationLabel(l),
        subtitle: locationZone(l),
        selectedLabel: locationLabelWithZone(l),
        searchText: locationSearchText(l),
      ),
];

List<PickerOption<int>> eventPickerOptions(
  Iterable<EventModel> events,
  Iterable<LocationModel> locations, {
  String? noneLabel,
  int? keepId,
  bool onlyActive = true,
}) {
  final byId = {for (final l in locations) l.id: l};
  return [
    if (noneLabel != null) PickerOption<int>(null, noneLabel),
    for (final e in events)
      if (!onlyActive || e.isActive || e.id == keepId)
        PickerOption<int>(
          e.id,
          e.name,
          searchText: [
            e.notes,
            if (byId[e.locationId] != null)
              locationSearchText(byId[e.locationId]!),
          ].whereType<String>().join(' '),
        ),
  ];
}

List<PickerOption<int>> clientPickerOptions(
  Iterable<ClientModel> clients, {
  String? noneLabel,
}) => [
  if (noneLabel != null) PickerOption<int>(null, noneLabel),
  for (final c in clients)
    PickerOption<int>(c.id, c.name, searchText: c.contactInfo),
];

List<PickerOption<int>> supplierPickerOptions(
  Iterable<SupplierModel> suppliers, {
  String? noneLabel,
}) => [
  if (noneLabel != null) PickerOption<int>(null, noneLabel),
  for (final s in suppliers)
    PickerOption<int>(s.id, s.name, searchText: s.contactInfo),
];

List<PickerOption<int>> productPickerOptions(
  Iterable<ProductModel> products,
  Iterable<CategoryModel> categories, {
  String? noneLabel,
}) {
  final names = {for (final c in categories) c.id: c.name};
  return [
    if (noneLabel != null) PickerOption<int>(null, noneLabel),
    for (final p in products)
      PickerOption<int>(
        p.id,
        p.name,
        searchText: [
          p.description,
          names[p.categoryId],
        ].whereType<String>().join(' '),
      ),
  ];
}

List<PickerOption<int>> materialPickerOptions(
  Iterable<MaterialModel> materials,
  Iterable<UnitModel> units, {
  String? noneLabel,
}) {
  final names = {for (final u in units) u.id: u.name};
  return [
    if (noneLabel != null) PickerOption<int>(null, noneLabel),
    for (final m in materials)
      PickerOption<int>(
        m.id,
        m.name,
        searchText: [
          m.description,
          names[m.unitId],
        ].whereType<String>().join(' '),
      ),
  ];
}
