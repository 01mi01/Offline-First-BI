import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/date_range_filter.dart';
import '../../application/event_provider.dart';
import '../../application/location_provider.dart';
import '../../application/location_options.dart';
import '../../application/record_search.dart';
import '../../application/status_filter.dart';
import '../../models/event_model.dart';
import '../../models/location_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/event_dialog.dart';
import '../dialogs/location_dialog.dart';
import '../widgets/screen_header.dart';
import '../widgets/status_badge.dart';
import '../../config/date_formatters.dart';
import '../widgets/app_controls.dart';
import '../widgets/flat_list.dart';
import '../widgets/app_group.dart';
import '../widgets/app_sheet.dart';
import '../widgets/record_detail.dart';
import '../widgets/record_list.dart';
import '../widgets/profile_button.dart';
import '../widgets/filter_panel.dart';
import '../widgets/empty_state.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: ScreenScaffold(
        title: 'Eventos',
        actions: const [ProfileButton()],
        bottom: const AppTabSwitcher(labels: ['Eventos', 'Ubicaciones']),
        body: const TabBarView(children: [_EventsTab(), _LocationsTab()]),
      ),
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
    final dates = ref.watch(eventDateFilterProvider);
    final country = ref.watch(eventCountryFilterProvider);
    final city = ref.watch(eventCityFilterProvider);
    final query = ref.watch(eventListQueryProvider);
    final locationById = {for (final l in locations) l.id: l};
    // Un evento de varios días entra si alguno de sus días cae en el rango.
    // País y ciudad se miden contra la ubicación del evento.
    final visible = ref
        .watch(eventSearchIndexProvider)
        .search(query)
        .where(
          (e) =>
              status.matches(e.isActive) &&
              dates.overlaps(e.startDate, e.endDate) &&
              locationMatches(
                locationById[e.locationId],
                country: country,
                city: city,
              ),
        )
        .toList();
    final countries = countryOptions(locations);
    final cities = cityOptions(locations, country: country);

    final fields = <FilterField>[
      FilterDropdown<String?>(
        label: 'País',
        options: [
          const FilterOption<String?>(null, 'Todos los países'),
          for (final c in countries) FilterOption<String?>(c, c),
        ],
        current: country,
        defaultValue: null,
        onApply: (value) {
          ref.read(eventCountryFilterProvider.notifier).state = value;
          if (city != null &&
              !cityOptions(locations, country: value).contains(city)) {
            ref.read(eventCityFilterProvider.notifier).state = null;
          }
        },
      ),
      FilterDropdown<String?>(
        label: 'Ciudad',
        options: [
          const FilterOption<String?>(null, 'Todas las ciudades'),
          for (final c in cities) FilterOption<String?>(c, c),
        ],
        current: city,
        defaultValue: null,
        onApply: (value) =>
            ref.read(eventCityFilterProvider.notifier).state = value,
      ),
      FilterDropdown<StatusFilter>(
        label: 'Estado',
        options: [
          for (final s in StatusFilter.values)
            FilterOption(s, statusFilterLabel(s)),
        ],
        current: status,
        defaultValue: StatusFilter.all,
        onApply: (value) =>
            ref.read(eventStatusFilterProvider.notifier).state = value,
      ),
      FilterDates(
        current: dates,
        onApply: (value) =>
            ref.read(eventDateFilterProvider.notifier).state = value,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'events_tab_fab',
        onPressed: () => _showDialog(context, null),
      ),
      body: Column(
        children: [
          FilterArea(
            search: AppSearchBar(
              initialText: query,
              hintText: 'Buscar evento',
              onChanged: (value) =>
                  ref.read(eventListQueryProvider.notifier).state = value,
            ),
            fields: fields,
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.events.isEmpty
                ? Center(
                    child: AppEmptyState.list(
                      plural: 'eventos',
                      icon: Icons.event_rounded,
                      actionLabel: 'Nuevo evento',
                      onAction: () => _showDialog(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState.noMatch(),
                  )
                : AppGroupListView(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final event = visible[index];
                      final location = locations
                          .where((l) => l.id == event.locationId)
                          .firstOrNull;
                      return _EventRow(
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
    showAppSheet<void>(context, builder: (_) => EventDialog(event: event));
  }
}

// Tab de ubicaciones
class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationProvider);
    final status = ref.watch(locationStatusFilterProvider);
    final country = ref.watch(locationCountryFilterProvider);
    final city = ref.watch(locationCityFilterProvider);
    final query = ref.watch(locationListQueryProvider);
    final visible = ref
        .watch(locationSearchIndexProvider)
        .search(query)
        .where(
          (l) =>
              status.matches(l.isActive) &&
              locationMatches(l, country: country, city: city),
        )
        .toList();
    final countries = countryOptions(state.locations);
    final cities = cityOptions(state.locations, country: country);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FlatFab(
        heroTag: 'locations_tab_fab',
        onPressed: () => _showDialog(context, null),
      ),
      body: Column(
        children: [
          FilterArea(
            search: AppSearchBar(
              initialText: query,
              hintText: 'Buscar ubicación',
              onChanged: (value) =>
                  ref.read(locationListQueryProvider.notifier).state = value,
            ),
            fields: [
              FilterDropdown<String?>(
                label: 'País',
                options: [
                  const FilterOption<String?>(null, 'Todos los países'),
                  for (final c in countries) FilterOption<String?>(c, c),
                ],
                current: country,
                defaultValue: null,
                onApply: (value) {
                  ref.read(locationCountryFilterProvider.notifier).state =
                      value;
                  if (city != null &&
                      !cityOptions(state.locations, country: value)
                          .contains(city)) {
                    ref.read(locationCityFilterProvider.notifier).state = null;
                  }
                },
              ),
              FilterDropdown<String?>(
                label: 'Ciudad',
                options: [
                  const FilterOption<String?>(null, 'Todas las ciudades'),
                  for (final c in cities) FilterOption<String?>(c, c),
                ],
                current: city,
                defaultValue: null,
                onApply: (value) =>
                    ref.read(locationCityFilterProvider.notifier).state = value,
              ),
              FilterDropdown<StatusFilter>(
                label: 'Estado',
                options: statusFilterOptions(feminine: true),
                current: status,
                defaultValue: StatusFilter.all,
                onApply: (value) =>
                    ref.read(locationStatusFilterProvider.notifier).state =
                        value,
              ),
            ],
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.locations.isEmpty
                ? Center(
                    child: AppEmptyState.list(
                      plural: 'ubicaciones',
                      icon: Icons.place_rounded,
                      actionLabel: 'Nueva ubicación',
                      onAction: () => _showDialog(context, null),
                    ),
                  )
                : visible.isEmpty
                ? const SingleChildScrollView(
                    child: AppEmptyState.noMatch(),
                  )
                : AppGroupListView(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final loc = visible[index];
                      return _LocationRow(
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
    showAppSheet<void>(context, builder: (_) => LocationDialog(location: location));
  }
}

// Fecha de un evento: un día, o el rango de inicio a fin.
String _eventDates(EventModel event) => event.endDate != null
    ? '${formatDate(event.startDate)} — ${formatDate(event.endDate!)}'
    : formatDate(event.startDate);

// Fila de evento
class _EventRow extends StatelessWidget {
  final EventModel event;
  final LocationModel? location;
  final VoidCallback onEdit;

  const _EventRow({
    required this.event,
    required this.location,
    required this.onEdit,
  });

  void _showDetail(BuildContext context) {
    final loc = location;
    final notes = event.notes;
    showAppSheet<void>(
      context,
      builder: (_) => RecordDetailSheet(
        title: 'Detalle del evento',
        onEdit: onEdit,
        children: [
          RecordHeadline(
            title: event.name,
            pill: StatusBadge.forState(isActive: event.isActive),
          ),
          AppSection(
            children: [
              AppValueRow(label: 'Fecha', value: _eventDates(event)),
              if (loc != null)
                AppValueRow(
                  label: 'Ubicación',
                  value: locationLabelWithZone(loc),
                ),
              if (notes != null && notes.isNotEmpty)
                AppValueRow(label: 'Notas', value: notes),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final notes = event.notes;
    return RecordRow(
      title: event.name,
      details: [
        RecordLine(_eventDates(event)),
        if (loc != null) RecordLine(locationLabelWithZone(loc)),
        if (notes != null && notes.isNotEmpty) RecordLine(notes, maxLines: 1),
      ],
      pill: StatusBadge.forState(isActive: event.isActive),
      onTap: () => _showDetail(context),
    );
  }
}

// Fila de ubicación
class _LocationRow extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onEdit;

  const _LocationRow({required this.location, required this.onEdit});

  void _showDetail(BuildContext context) {
    final zone = location.description;
    showAppSheet<void>(
      context,
      builder: (_) => RecordDetailSheet(
        title: 'Detalle de la ubicación',
        onEdit: onEdit,
        children: [
          RecordHeadline(
            title: locationLabel(location),
            pill: StatusBadge.forState(
              isActive: location.isActive,
              activeLabel: 'Activa',
              inactiveLabel: 'Inactiva',
            ),
          ),
          AppSection(
            children: [
              AppValueRow(label: 'Ciudad', value: location.city),
              AppValueRow(label: 'País', value: location.country),
              if (zone != null && zone.isNotEmpty)
                AppValueRow(label: 'Descripción', value: zone),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone = location.description;
    return RecordRow(
      title: locationLabel(location),
      details: [if (zone != null && zone.isNotEmpty) RecordLine(zone, maxLines: 1)],
      pill: StatusBadge.forState(
        isActive: location.isActive,
        activeLabel: 'Activa',
        inactiveLabel: 'Inactiva',
      ),
      onTap: () => _showDetail(context),
    );
  }
}
