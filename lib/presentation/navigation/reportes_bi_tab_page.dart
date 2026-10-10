import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/module_permission_provider.dart';
import '../../theme/app_theme.dart';
import '../pages/business_intelligence_page.dart';
import '../pages/reports_page.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_list_row.dart';
import 'nav_resolver.dart';
import '../widgets/profile_button.dart';

// Tab "Reportes + Business Intelligence" de la navegación inferior: pantalla
// de aterrizaje con tarjetas (Reportes, Business Intelligence), mostrando
// solo las que el usuario puede leer.
class ReportesBiTabPage extends ConsumerWidget {
  const ReportesBiTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readableModules = ref.watch(readableModulesProvider);

    return readableModules.when(
      data: (modules) {
        final cards = resolveReportesCards(modules);

        return ScreenScaffold(
          title: 'Reportes y Business Intelligence',
          actions: const [ProfileButton()],
          body: cards.isEmpty
              ? Center(
                  child: Text(
                    'No tienes acceso a reportes ni business intelligence',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppHeader.sidePadding, 0, AppHeader.sidePadding, AppSpacing.s16),
                  children: [
                    AppListCard(
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          AppListRow(
                            icon: _iconFor(cards[i]),
                            iconColor: AppColors.cyanDark,
                            title: _labelFor(cards[i]),
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _pageFor(cards[i]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('No se pudo cargar Reportes')),
      ),
    );
  }
}

String _labelFor(ReportesCard card) {
  switch (card) {
    case ReportesCard.reportes:
      return 'Reportes';
    case ReportesCard.businessIntelligence:
      return 'Business Intelligence';
  }
}

IconData _iconFor(ReportesCard card) {
  switch (card) {
    case ReportesCard.reportes:
      return Icons.bar_chart_rounded;
    case ReportesCard.businessIntelligence:
      return Icons.insights_rounded;
  }
}

Widget _pageFor(ReportesCard card) {
  switch (card) {
    case ReportesCard.reportes:
      return const ReportsPage();
    case ReportesCard.businessIntelligence:
      return const BusinessIntelligencePage();
  }
}
