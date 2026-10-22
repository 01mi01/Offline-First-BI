import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_bi/presentation/navigation/main_navigation_page.dart';
import 'package:offline_first_bi/presentation/navigation/nav_resolver.dart';
import 'package:offline_first_bi/presentation/widgets/kpi_grid.dart';
import 'package:offline_first_bi/presentation/widgets/record_list.dart';
import 'package:offline_first_bi/theme/app_theme.dart';

Widget _host(double textScale, Widget child) {
  return MaterialApp(
    theme: lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  for (final scale in [1.3, 2.0]) {
    testWidgets('bottom bar does not overflow at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.875;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: MainBottomBar(
              groups: NavGroupId.values,
              selectedIndex: 0,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Inventario'), findsOneWidget);
    });

    testWidgets('report KPI cards grow with text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.875;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          scale,
          const AppKpiGrid(
            cardHeight: 136,
            items: [
              AppKpi(
                key: 'a',
                label: 'Ingresos',
                value: 'Bs. 7293.00',
                icon: Icons.trending_up_rounded,
                color: AppColors.cyanDark,
              ),
              AppKpi(
                key: 'b',
                label: 'Ventas',
                value: '107',
                icon: Icons.point_of_sale_rounded,
                color: AppColors.cyanDark,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final a = tester.getSize(find.byKey(const ValueKey('home-kpi-a')));
      final b = tester.getSize(find.byKey(const ValueKey('home-kpi-b')));
      expect(a.height, b.height);
      expect(a.height, greaterThanOrEqualTo(136));
    });
  }

  testWidgets('row title with suffix wraps instead of truncating', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.875;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        1.3,
        const SizedBox(
          width: 200,
          child: RecordRow(
            title: 'Tote bag beige grande',
            titleSuffix: '+1 más',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text('Tote bag beige grande'));
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(title.maxLines, isNull);
    expect(find.text('+1 más'), findsOneWidget);
  });
}
