import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/application/database_provider.dart';
import 'package:offline_first_bi/config/date_formatters.dart';
import 'package:offline_first_bi/data/db/app_database.dart';
import 'package:offline_first_bi/data/repositories/category_repository.dart';
import 'package:offline_first_bi/data/repositories/event_repository.dart';
import 'package:offline_first_bi/data/repositories/sale_repository.dart';
import 'package:offline_first_bi/presentation/pages/categories_page.dart';
import 'package:offline_first_bi/presentation/pages/events_page.dart';
import 'package:offline_first_bi/presentation/pages/sales_page.dart';
import 'package:offline_first_bi/presentation/widgets/status_badge.dart';
import 'package:offline_first_bi/theme/app_theme.dart';
import 'package:drift/drift.dart' show Value;

// Un solo formato de fecha (dd/MM/aaaa) y etiquetas de estado legibles.

// Contraste WCAG entre dos colores opacos.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

// El fondo de la etiqueta es translúcido: se compone sobre la superficie.
Color _over(Color translucent, Color base) => Color.alphaBlend(translucent, base);

void main() {
  group('date format', () {
    test('formatDate is dd/MM/yyyy with zero padding', () {
      expect(formatDate(DateTime(2026, 9, 29)), '29/09/2026');
      expect(formatDate(DateTime(2024, 1, 5)), '05/01/2024');
    });

    test('formatDateTime appends HH:mm (24 h)', () {
      expect(formatDateTime(DateTime(2026, 9, 29, 16, 32)), '29/09/2026 16:32');
      expect(formatDateTime(DateTime(2024, 1, 5, 9, 5)), '05/01/2024 09:05');
    });

    test('formatDateForFileName is yyyy-MM-dd (sortable, no slashes)', () {
      expect(formatDateForFileName(DateTime(2026, 9, 29)), '2026-09-29');
      expect(formatDateForFileName(DateTime(2024, 1, 5)), '2024-01-05');
    });
  });

  group('screens show dates in that one format', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: lightTheme, home: page),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sales list: "15/01/2024 09:05", not "15 Ene 2024 ..."', (tester) async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          categoryId: 1,
          name: 'Collar',
          priceA: 10,
          priceB: 10,
          stock: const Value(5),
        ),
      );
      await SaleRepository(db).createSale(
        clientId: null,
        locationId: null,
        eventId: null,
        totalAmount: 10,
        discount: 0,
        finalAmount: 10,
        date: DateTime(2024, 1, 15, 9, 5),
        items: [
          {'productId': 1, 'quantity': 1, 'unitPrice': 10.0},
        ],
      );

      await pumpPage(tester, const SalesPage());

      expect(find.text('15/01/2024 09:05'), findsOneWidget);
      expect(find.textContaining('Ene'), findsNothing);
    });

    testWidgets('events list: a single day and a range use dd/MM/yyyy', (tester) async {
      final repository = EventRepository(db);
      await repository.save(name: 'Feria', startDate: DateTime(2024, 3, 5));
      await repository.save(
        name: 'Expo',
        startDate: DateTime(2024, 4, 5),
        endDate: DateTime(2024, 4, 7),
      );

      await pumpPage(tester, const EventsPage());

      expect(find.text('05/03/2024'), findsOneWidget);
      expect(find.text('05/04/2024 — 07/04/2024'), findsOneWidget);
      expect(find.textContaining('Mar'), findsNothing);
    });
  });

  group('status badge contrast', () {
    final surface = AppColors.surface;
    final background = AppColors.background;

    for (final positive in [true, false]) {
      final label = positive ? 'Activo / success' : 'Inactivo / canceled / error';

      test('$label: text meets WCAG AA (4.5:1) on its own tinted background', () {
        for (final base in [surface, background]) {
          final bg = _over(StatusBadge.backgroundColor(positive), base);
          expect(
            contrast(StatusBadge.textColor(positive), bg),
            greaterThanOrEqualTo(4.5),
            reason: '$label sobre $base',
          );
        }
      });
    }

    test('the badge green is a darker shade of the palette green; the red is the single app red', () {
      // Mismo tono que success, solo más oscuro (como primaryDark).
      final hsl = HSLColor.fromColor;
      expect((hsl(AppColors.successDark).hue - hsl(AppColors.success).hue).abs(), lessThan(20));
      expect(hsl(AppColors.successDark).lightness, lessThan(hsl(AppColors.success).lightness));
    });

    test('control: the previous colors did NOT reach 4.5:1 (this is what was fixed)', () {
      final oldGreen = contrast(
        AppColors.success,
        _over(AppColors.success.withOpacity(0.1), surface),
      );
      // El rojo brillante anterior de la aplicación (ya no se usa en ninguna parte).
      const brightRed = Color(0xFFFF3B30);
      final oldRed = contrast(
        brightRed,
        _over(brightRed.withOpacity(0.1), surface),
      );
      expect(oldGreen, lessThan(4.5));
      expect(oldRed, lessThan(4.5));
    });

    group('in the real lists', () {
      late AppDatabase db;

      setUp(() {
        db = AppDatabase.forTesting(NativeDatabase.memory());
      });

      tearDown(() async {
        await db.close();
      });

      testWidgets('categories: "Activa" / "Inactiva" use the accessible colors', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = CategoryRepository(db);
        await repository.save(name: 'Bisutería');
        await repository.save(name: 'Vieja', isActive: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(theme: lightTheme, home: const CategoriesPage()),
          ),
        );
        await tester.pumpAndSettle();

        Color? colorOf(String text) => tester
            .widget<Text>(find.text(text).first)
            .style
            ?.color;

        expect(colorOf('Activa'), AppColors.successDark);
        expect(colorOf('Inactiva'), AppColors.error);
      });
    });
  });
}
