import 'package:flutter/material.dart';
import '../../application/module_permission_provider.dart';
import '../../models/access_control.dart';
import '../widgets/module_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/date_range_filter.dart';
import '../../application/event_provider.dart';
import '../../application/location_provider.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';
import 'location_dialog.dart';
import '../../config/date_formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/discard_guard.dart';
import '../widgets/live_validation.dart';
import '../widgets/single_flight.dart';
import '../widgets/date_pickers.dart';
import '../widgets/focus_utils.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/transaction_date_field.dart';
import '../../config/app_clock.dart';
import '../../application/form_validation.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';
import '../widgets/picker_options.dart';

class EventDialog extends ConsumerStatefulWidget {
  final EventModel? event;

  const EventDialog({super.key, this.event});

  @override
  ConsumerState<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<EventDialog>
    with SingleFlight<EventDialog>, LiveValidation<EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  int? _selectedLocationId;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _isActive;
  String? _saveError;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _notesController = TextEditingController(text: widget.event?.notes ?? '');
    _selectedLocationId = widget.event?.locationId;
    _startDate = widget.event?.startDate;
    _endDate = widget.event?.endDate;
    _isActive = widget.event?.isActive ?? true;
    _initialSignature = _signature();
  }

  @override
  GlobalKey<FormState> get validationKey => _formKey;

  @override
  String valuesSnapshot() => _signature();

  @override
  void clearMessages() {_saveError = null;}

  String _signature() => [
    _nameController.text,
    _notesController.text,
    _selectedLocationId,
    _startDate,
    _endDate,
    _isActive,
  ].join('\u0000');

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    dismissKeyboard();
    final picked = await showAppDatePicker(
      context,
      initialDate: _startDate ?? appNow(),
      firstDate: transactionFirstDate,
      lastDate: transactionLastDate,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    dismissKeyboard();
    final start = _startDate;
    var initial = _endDate ?? start ?? appNow();
    if (start != null && dateOnly(initial).isBefore(dateOnly(start))) {
      initial = start;
    }
    final picked = await showAppDatePicker(
      context,
      initialDate: initial,
      firstDate: start ?? transactionFirstDate,
      lastDate: transactionLastDate,
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  String _formatDate(DateTime date) => formatDate(date);

  Future<void> _onToggleActive(bool value) async {
    final confirm = await confirmCancellation(
      context,
      title: value ? 'Activar el evento' : 'Desactivar el evento',
      message: value
          ? 'El evento volverá a estar disponible para nuevos registros.'
          : 'El evento no estará disponible para nuevos registros.',
      confirmLabel: value ? 'Activar' : 'Desactivar',
      confirmKind: value ? AppButtonKind.primary : AppButtonKind.destructive,
    );
    if (!confirm) return;
    setState(() => _isActive = value);
  }

  void _showAddLocationSheet() {
    dismissKeyboard();
    showFormSheet<void>(
      context,
      builder: (_) => LocationDialog(
        from: AppModule.eventos,
        onSaved: (locationId) {
          setState(() => _selectedLocationId = locationId);
        },
      ),
    );
  }

  String? get _endDateError {
    final start = _startDate;
    final end = _endDate;
    if (start != null && end != null && end.isBefore(start)) {
      return 'La fecha de fin no puede ser anterior a la de inicio';
    }
    return null;
  }

  String? get _startDateError =>
      submitAttempted && _startDate == null ? 'Selecciona la fecha de inicio' : null;

  Future<void> _save() async {
    if (widget.event != null &&
        !ref.read(accessControlProvider).canUpdate(AppModule.eventos)) {
      final error = await ref
          .read(eventProvider.notifier)
          .setActive(widget.event!.id, _isActive);
      if (!mounted) return;
      if (error != null) {
        setState(() => _saveError = error);
        return;
      }
      Navigator.pop(context);
      return;
    }
    final valid = validateForm();
    if (!valid || _startDate == null || _endDateError != null) return;
    setState(() => _saveError = null);

    try {
      await ref
          .read(eventProvider.notifier)
          .save(
            id: widget.event?.id,
            name: _nameController.text.trim(),
            locationId: _selectedLocationId,
            startDate: _startDate!,
            endDate: _endDate,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            isActive: _isActive,
          );
    } on AccessDeniedException catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _signature() != _initialSignature,
      onValuesChanged: syncValues,
      changes: Listenable.merge([
        _nameController,
        _notesController,
      ]),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isEditing = widget.event != null;
    final access = ref.watch(accessControlProvider);
    final locked = isEditing && !access.canUpdate(AppModule.eventos);
    final locations = ref
        .watch(locationProvider)
        .locations
        .where((l) => l.isActive || l.id == _selectedLocationId)
        .toList();

    return FormSheet(
      locked: locked,
      lockedNotice: deactivateOnlyNotice,
      title: isEditing ? 'Editar evento' : 'Nuevo evento',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.maybePop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: () => runOnce(_save),
        busy: inFlight,
      ),
      children: [
        LabeledField(
          label: 'Nombre del evento',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Nombre del evento',
            ),
            validator: validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        SearchablePickerField<int>(
          label: 'Ubicación',
          searchHint: 'Buscar ubicación',
          value: _selectedLocationId,
          options: locationPickerOptions(
            locations,
            noneLabel: 'Sin ubicación',
            onlyActive: false,
          ),
          onChanged: (val) => setState(() => _selectedLocationId = val),
          labelAction: access.canQuickAdd(AppModule.ubicaciones, AppModule.eventos)
              ? FormAddButton(
                  label: 'Nueva ubicación',
                  onPressed: _showAddLocationSheet,
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.s16),

        AppDateField(
          label: 'Fecha de inicio',
          hint: 'Seleccionar fecha',
          valueText: _startDate == null ? null : _formatDate(_startDate!),
          errorText: _startDateError,
          onTap: _pickStartDate,
        ),
        const SizedBox(height: AppSpacing.s16),
        AppDateField(
          label: 'Fecha de fin (opcional)',
          hint: 'Seleccionar fecha',
          valueText: _endDate == null ? null : _formatDate(_endDate!),
          errorText: _endDateError,
          onTap: _pickEndDate,
          onClear: () => setState(() => _endDate = null),
        ),
        const SizedBox(height: AppSpacing.s16),

        LabeledField(
          label: 'Notas',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _notesController,
            decoration: const InputDecoration(
              hintText: 'Observaciones opcionales',
            ),
            maxLines: 3,
            validator: validateOptionalText,
          ),
        ),

        if (isEditing && access.canDeactivate(AppModule.eventos)) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Evento activo',
            subtitle: _isActive
                ? 'Disponible en el sistema'
                : 'No disponible en el sistema',
            value: _isActive,
            onChanged: _onToggleActive,
          ),
        ],

        if (_saveError != null) FormErrorText(_saveError!),
      ],
    );
  }
}
