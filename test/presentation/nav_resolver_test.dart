import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/navigation/nav_resolver.dart';

void main() {
  group('resolveVisibleGroups', () {
    test('full access shows every group', () {
      final groups = resolveVisibleGroups([
        'inventario',
        'materiales',
        'ventas',
        'compras',
        'clientes',
        'proveedores',
        'eventos',
        'reportes',
        'business_intelligence',
      ]);

      expect(groups, [
        NavGroupId.home,
        NavGroupId.inventario,
        NavGroupId.ventasCompras,
        NavGroupId.contactos,
        NavGroupId.reportes,
      ]);
    });

    test('zero module access still shows only Home', () {
      expect(resolveVisibleGroups([]), [NavGroupId.home]);
    });

    test('single-module access shows only Home and that group', () {
      expect(resolveVisibleGroups(['ventas']), [
        NavGroupId.home,
        NavGroupId.ventasCompras,
      ]);
    });

    test('materiales alone (no inventario) still shows the Inventario group', () {
      expect(resolveVisibleGroups(['materiales']), [
        NavGroupId.home,
        NavGroupId.inventario,
      ]);
    });

    test('proveedores alone (no clientes) still shows the Contactos group', () {
      expect(resolveVisibleGroups(['proveedores']), [
        NavGroupId.home,
        NavGroupId.contactos,
      ]);
    });

    test('business_intelligence alone (no reportes) still shows the Reportes group', () {
      expect(resolveVisibleGroups(['business_intelligence']), [
        NavGroupId.home,
        NavGroupId.reportes,
      ]);
    });
  });

  group('resolveInventarioCards', () {
    test('both inventario and materiales readable yields all three cards', () {
      expect(
        resolveInventarioCards(['inventario', 'materiales']),
        [
          InventarioCard.productos,
          InventarioCard.categorias,
          InventarioCard.materiales,
        ],
      );
    });

    test('only inventario readable yields productos/categorias only', () {
      expect(resolveInventarioCards(['inventario']), [
        InventarioCard.productos,
        InventarioCard.categorias,
      ]);
    });

    test('only materiales readable yields materiales only', () {
      expect(resolveInventarioCards(['materiales']), [
        InventarioCard.materiales,
      ]);
    });

    test('neither readable yields an empty list', () {
      expect(resolveInventarioCards([]), isEmpty);
    });
  });

  group('resolveVentasComprasCards', () {
    test('both readable yields both cards', () {
      expect(
        resolveVentasComprasCards(['ventas', 'compras']),
        [VentasComprasCard.ventas, VentasComprasCard.compras],
      );
    });

    test('only compras readable yields only compras', () {
      expect(
        resolveVentasComprasCards(['compras']),
        [VentasComprasCard.compras],
      );
    });

    test('neither readable yields an empty list', () {
      expect(resolveVentasComprasCards([]), isEmpty);
    });
  });

  group('resolveContactosCards', () {
    test('clientes and proveedores each yield their own independent card', () {
      expect(
        resolveContactosCards(['clientes', 'proveedores']),
        [ContactosCard.clientes, ContactosCard.proveedores],
      );
    });

    test('proveedores alone yields only the proveedores card, not clientes', () {
      expect(
        resolveContactosCards(['proveedores']),
        [ContactosCard.proveedores],
      );
    });

    test('clientes alone yields only the clientes card, not proveedores', () {
      expect(
        resolveContactosCards(['clientes']),
        [ContactosCard.clientes],
      );
    });

    test('eventos alone yields only the eventos card', () {
      expect(resolveContactosCards(['eventos']), [ContactosCard.eventos]);
    });

    test('none readable yields an empty list', () {
      expect(resolveContactosCards([]), isEmpty);
    });
  });

  group('resolveReportesCards', () {
    test('both readable yields both cards', () {
      expect(
        resolveReportesCards(['reportes', 'business_intelligence']),
        [ReportesCard.reportes, ReportesCard.businessIntelligence],
      );
    });

    test('only reportes readable yields only reportes', () {
      expect(resolveReportesCards(['reportes']), [ReportesCard.reportes]);
    });

    test('neither readable yields an empty list', () {
      expect(resolveReportesCards([]), isEmpty);
    });
  });

}
