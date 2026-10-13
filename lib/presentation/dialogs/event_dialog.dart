import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/event_provider.dart';
import '../../application/location_options.dart';
import '../../application/location_provider.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';
import 'location_dialog.dart';
import '../../config/date_formatters.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/focus_utils.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/transaction_date_field.dart';
import '../../config/app_clock.dart';
import '../../application/form_validation.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_style.dart';
import '../widgets/form_widgets.dart';

class EventDialog extends ConsumerStatefulWidget {
  final EventModel? event;

  const EventDialog({super.key, this.event});

  @override
  ConsumerState<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  int? _selectedLocationId;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _isActive;
  String? _saveError;
  // Tras un intento de guardar sin fecha de inicio se marca el campo.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _notesController = TextEditingController(text: widget.event?.notes ?? '');
    _selectedLocationId = widget.event?.locationId;
    _startDate = widget.event?.startDate;
    _endDate = widget.event?.endDate;
    _isActive = widget.event?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    dismissKeyboard();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? appNow(),
      firstDate: transactionFirstDate,
      lastDate: transactionLastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.cyanDark)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    dismissKeyboard();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? appNow(),
      firstDate: _startDate ?? transactionFirstDate,
      lastDate: transactionLastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.cyanDark)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  String _formatDate(DateTime date) => formatDate(date);

  // Desactivar un evento (no se borra): deja de ofrecerse al registrar
  // ventas y compras, pero sigue en el historial y en los reportes.
  Future<void> _onToggleActive(bool value) async {
    if (!value) {
      final confirm = await confirmCancellation(
        context,
        title: '¿Desactivar evento?',
        message:
            'El evento no estará disponible para nuevos registros.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (!confirm) return;
    }
    setState(() => _isActive = value);
  }

  void _showAddLocationSheet() {
    dismissKeyboard();
    showAppSheet<void>(
      context,
      builder: (_) => LocationDialog(
        onSaved: (locationId) {
          setState(() => _selectedLocationId = locationId);
        },
      ),
    );
  }

  // La fecha de fin no puede ser anterior a la de inicio (se avisa en cuanto
  // pasa, también si se cambia el inicio después de elegir el fin).
  String? get _endDateError {
    final start = _startDate;
    final end = _endDate;
    if (start != null && end != null && end.isBefore(start)) {
      return 'La fecha de fin no puede ser anterior a la de inicio';
    }
    return null;
  }

  String? get _startDateError =>
      _submitted && _startDate == null ? 'Selecciona la fecha de inicio' : null;

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _submitted = true);
    if (!valid || _startDate == null || _endDateError != null) return;
    setState(() => _saveError = null);

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

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final locations = ref
        .watch(locationProvider)
        .locations
        .where((l) => l.isActive || l.id == _selectedLocationId)
        .toList();

    return FormSheet(
      title: isEditing ? 'Editar evento' : 'Nuevo evento',
      formKey: _formKey,
      actions: FormActions(
        onSecondary: () => Navigator.pop(context),
        primaryLabel: isEditing ? 'Guardar' : 'Crear',
        onPrimary: _save,
      ),
      children: [
        // Nombre del evento
        LabeledField(
          label: 'Nombre del evento',
          builder: (_) => TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Ej: Feria, exposición, etc.',
            ),
            validator: validateName,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Ubicación, con opción de crear una nueva. Búsqueda en línea: el botón
        // va en la fila del campo y los resultados se abren debajo.
        SearchablePickerField<int>(
          label: 'Ubicación',
          searchHint: 'Buscar ubicación',
          value: _selectedLocationId,
          options: [
            const PickerOption<int>(null, 'Sin ubicación'),
            for (final l in locations)
              PickerOption<int>(
                l.id,
                locationLabel(l),
                subtitle: locationZone(l),
                selectedLabel: locationLabelWithZone(l),
              ),
          ],
          onChanged: (val) => setState(() => _selectedLocationId = val),
          labelAction: FormAddButton(onPressed: _showAddLocationSheet),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Fechas
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

        // Notas
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

        // Estado: solo al editar
        if (isEditing) ...[
          const SizedBox(height: AppSpacing.s16),
          AppToggleRow(
            title: 'Evento activo',
            subtitle: _isActive ? 'Visible en el sistema' : 'Oculto en el sistema',
            value: _isActive,
            onChanged: _onToggleActive,
          ),
        ],

        if (_saveError != null) FormErrorText(_saveError!),
      ],
    );
  }
}
