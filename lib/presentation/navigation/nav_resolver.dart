enum NavGroupId { home, inventario, ventasCompras, contactos, reportes }

List<NavGroupId> resolveVisibleGroups(List<String> readableModules) {
  final groups = <NavGroupId>[NavGroupId.home];

  if (readableModules.contains('inventario') ||
      readableModules.contains('materiales')) {
    groups.add(NavGroupId.inventario);
  }
  if (readableModules.contains('ventas') ||
      readableModules.contains('compras')) {
    groups.add(NavGroupId.ventasCompras);
  }
  if (readableModules.contains('clientes') ||
      readableModules.contains('proveedores') ||
      readableModules.contains('eventos') ||
      readableModules.contains('ubicaciones')) {
    groups.add(NavGroupId.contactos);
  }
  if (readableModules.contains('reportes') ||
      readableModules.contains('business_intelligence')) {
    groups.add(NavGroupId.reportes);
  }

  return groups;
}

enum InventarioCard { productos, categorias, materiales }

List<InventarioCard> resolveInventarioCards(List<String> readableModules) {
  final cards = <InventarioCard>[];
  if (readableModules.contains('inventario')) {
    cards.addAll([InventarioCard.productos, InventarioCard.categorias]);
  }
  if (readableModules.contains('materiales')) {
    cards.add(InventarioCard.materiales);
  }
  return cards;
}

enum VentasComprasCard { ventas, compras }

List<VentasComprasCard> resolveVentasComprasCards(
  List<String> readableModules,
) {
  final cards = <VentasComprasCard>[];
  if (readableModules.contains('ventas')) cards.add(VentasComprasCard.ventas);
  if (readableModules.contains('compras')) cards.add(VentasComprasCard.compras);
  return cards;
}

enum ContactosCard { clientes, proveedores, eventos }

List<ContactosCard> resolveContactosCards(List<String> readableModules) {
  final cards = <ContactosCard>[];
  if (readableModules.contains('clientes')) cards.add(ContactosCard.clientes);
  if (readableModules.contains('proveedores')) {
    cards.add(ContactosCard.proveedores);
  }
  if (readableModules.contains('eventos') ||
      readableModules.contains('ubicaciones')) {
    cards.add(ContactosCard.eventos);
  }
  return cards;
}

enum ReportesCard { reportes, businessIntelligence }

List<ReportesCard> resolveReportesCards(List<String> readableModules) {
  final cards = <ReportesCard>[];
  if (readableModules.contains('reportes')) cards.add(ReportesCard.reportes);
  if (readableModules.contains('business_intelligence')) {
    cards.add(ReportesCard.businessIntelligence);
  }
  return cards;
}

const int maxVisibleNavTabs = 5;

bool _readsContacts(List<String> readable) =>
    readable.contains('clientes') || readable.contains('proveedores');

String _joinParts(List<String> parts) => parts.join(' y ');

String navTabLabel(NavGroupId group, List<String> readable) {
  switch (group) {
    case NavGroupId.home:
      return 'Inicio';
    case NavGroupId.inventario:
      return 'Inventario';
    case NavGroupId.ventasCompras:
      return readable.contains('ventas') ? 'Ventas' : 'Compras';
    case NavGroupId.contactos:
      if (_readsContacts(readable)) return 'Contactos';
      return readable.contains('eventos') ? 'Eventos' : 'Ubicaciones';
    case NavGroupId.reportes:
      return readable.contains('reportes') ? 'Reportes' : 'BI';
  }
}

String ventasComprasTitle(List<String> readable) => _joinParts([
  if (readable.contains('ventas')) 'Ventas',
  if (readable.contains('compras')) 'Compras',
]);

String eventosUbicacionesLabel(List<String> readable) => _joinParts([
  if (readable.contains('eventos')) 'Eventos',
  if (readable.contains('ubicaciones')) 'Ubicaciones',
]);

String contactosTitle(List<String> readable) {
  final events = readable.contains('eventos')
      ? 'Eventos'
      : readable.contains('ubicaciones')
      ? 'Ubicaciones'
      : null;
  return _joinParts([
    if (_readsContacts(readable)) 'Contactos',
    if (events != null) events,
  ]);
}

String reportesTitle(List<String> readable) => _joinParts([
  if (readable.contains('reportes')) 'Reportes',
  if (readable.contains('business_intelligence')) 'Business Intelligence',
]);
