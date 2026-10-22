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
      readableModules.contains('eventos')) {
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
  if (readableModules.contains('eventos')) {
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
