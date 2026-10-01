import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/event_provider.dart';
import '../../application/location_provider.dart';
import '../../application/status_filter.dart';
import '../../models/event_model.dart';
import '../../models/location_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/event_dialog.dart';
import '../dialogs/location_dialog.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/status_badge.dart';
import '../../config/date_formatters.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Eventos',
          showBack: true,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Eventos'),
              Tab(text: 'Ubicaciones'),
            ],
          ),
        ),
        body: const TabBarView(children: [_EventsTab(), _LocationsTab()]),
      ),
    );
  }
}

// Fila superior con el filtro de estado, alineado a la derecha.
class _StatusFilterRow extends StatelessWidget {
  final Widget child;

  const _StatusFilterRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [child]),
    );
  }
}

// Tab de eventos
class _EventsTab extends ConsumerWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventProvider);
    final locations = ref.watch(locationProvider).locations;
    final status = ref.watch(eventStatusFilterProvider);
    final visible = state.events.where((e) => status.matches(e.isActive)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'events_tab_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          _StatusFilterRow(
            child: StatusFilterChip(
              value: status,
              onChanged: (value) =>
                  ref.read(eventStatusFilterProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.events.isEmpty
                ? Center(
                    child: Text(
                      'No se registraron eventos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: AppSpacing.listWithFab,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final event = visible[index];
                      final location = locations
                          .where((l) => l.id == event.locationId)
                          .firstOrNull;
                      return _EventCard(
                        event: event,
                        location: location,
                        onEdit: () => _showDialog(context, event),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, EventModel? event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EventDialog(event: event),
    );
  }
}

// Tab de ubicaciones
class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationProvider);
    final status = ref.watch(locationStatusFilterProvider);
    final visible = state.locations
        .where((l) => status.matches(l.isActive))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'locations_tab_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          _StatusFilterRow(
            child: StatusFilterChip(
              feminine: true,
              value: status,
              onChanged: (value) =>
                  ref.read(locationStatusFilterProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.locations.isEmpty
                ? Center(
                    child: Text(
                      'No se registraron ubicaciones',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: AppSpacing.listWithFab,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final loc = visible[index];
                      return _LocationCard(
                        location: loc,
                        onEdit: () => _showDialog(context, loc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, LocationModel? location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LocationDialog(location: location),
    );
  }
}

// Tarjeta de evento
class _EventCard extends StatelessWidget {
  final EventModel event;
  final LocationModel? location;
  final VoidCallback onEdit;

  const _EventCard({
    required this.event,
    required this.location,
    required this.onEdit,
  });

  String _formatDate(DateTime date) => formatDate(date);

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: AppColors.surface,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s24,
                    AppSpacing.s24,
                    AppSpacing.s24,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      0,
                      AppSpacing.s24,
                      AppSpacing.s24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.endDate != null
                              ? '${_formatDate(event.startDate)} — ${_formatDate(event.endDate!)}'
                              : _formatDate(event.startDate),
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (location != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: AppSpacing.s2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${location!.city}, ${location!.country}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                        ],
                        if (event.notes != null && event.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            event.notes!,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    event.endDate != null
                        ? '${_formatDate(event.startDate)} — ${_formatDate(event.endDate!)}'
                        : _formatDate(event.startDate),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (location != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${location!.city}, ${location!.country}',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                  ],
                  if (event.notes != null && event.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      event.notes!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),
                  StatusBadge.forState(
                    isActive: event.isActive,
                    activeLabel: 'Activo',
                    inactiveLabel: 'Inactivo',
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta de ubicación
class _LocationCard extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onEdit;

  const _LocationCard({required this.location, required this.onEdit});

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: AppColors.surface,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s24,
                    AppSpacing.s24,
                    AppSpacing.s24,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${location.city}, ${location.country}',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      0,
                      AppSpacing.s24,
                      AppSpacing.s24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge.forState(
isActive: location.isActive,
activeLabel: 'Activa',
inactiveLabel: 'Inactiva',
),
                        if (location.description != null &&
                            location.description!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            location.description!,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${location.city}, ${location.country}',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  if (location.description != null &&
                      location.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      location.description!,
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),
                  StatusBadge.forState(
isActive: location.isActive,
activeLabel: 'Activa',
inactiveLabel: 'Inactiva',
),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
