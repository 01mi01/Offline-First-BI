import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/event_provider.dart';
import '../../application/location_provider.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';
import 'location_dialog.dart';
import '../../config/date_formatters.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/focus_utils.dart';
import '../widgets/transaction_date_field.dart';

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
      initialDate: _startDate ?? DateTime.now(),
      firstDate: transactionFirstDate,
      lastDate: transactionLastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      // Elegir la fecha resuelve el aviso "Selecciona la fecha de inicio"
      setState(() {
        _startDate = picked;
        _saveError = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    dismissKeyboard();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? transactionFirstDate,
      lastDate: transactionLastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
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
            'El evento "${_nameController.text.trim()}" no estará disponible para nuevos registros.',
        confirmLabel: 'Desactivar',
        dismissLabel: 'Cancelar',
      );
      if (!confirm) return;
    }
    setState(() => _isActive = value);
  }

  void _showAddLocationSheet() {
    dismissKeyboard();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LocationDialog(
        onSaved: (locationId) {
          setState(() => _selectedLocationId = locationId);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      setState(() => _saveError = 'Selecciona la fecha de inicio');
      return;
    }
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
        .where((l) => l.isActive)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: AppSpacing.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s32,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar evento' : 'Nuevo evento',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Nombre del evento
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del evento',
                  hintText: 'Ej: Feria, exposición, etc.',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Ubicación con opción de crear nueva
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      value: _selectedLocationId,
                      decoration: const InputDecoration(labelText: 'Ubicación'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sin ubicación'),
                        ),
                        ...locations.map(
                          (l) => DropdownMenuItem(
                            value: l.id,
                            child: Text('${l.city}, ${l.country}'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedLocationId = val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  GestureDetector(
                    onTap: _showAddLocationSheet,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_location_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Fecha de inicio
              GestureDetector(
                onTap: _pickStartDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Text(
                        _startDate != null
                            ? 'Inicio: ${_formatDate(_startDate!)}'
                            : 'Fecha de inicio',
                        style: TextStyle(
                          color: _startDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Fecha de fin
              GestureDetector(
                onTap: _pickEndDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Text(
                            _endDate != null
                                ? 'Fin: ${_formatDate(_endDate!)}'
                                : 'Fecha de fin (opcional)',
                            style: TextStyle(
                              color: _endDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (_endDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _endDate = null);
                          },
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Notas
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Observaciones opcionales',
                ),
                maxLines: 3,
              ),

              // Toggle activo/inactivo solo en edición
              if (isEditing) ...[
                const SizedBox(height: AppSpacing.s16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evento activo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isActive
                                ? 'Visible en el sistema'
                                : 'Oculto en el sistema',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: _onToggleActive,
                        activeColor: AppColors.primary,
                        inactiveTrackColor: AppColors.border,
                        inactiveThumbColor: AppColors.surface,
                        trackOutlineColor: MaterialStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_saveError != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(
                        isEditing ? 'Guardar' : 'Crear',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
