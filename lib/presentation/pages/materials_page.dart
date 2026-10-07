import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../application/product_provider.dart';
import '../../application/search_filter.dart';
import '../../application/status_filter.dart';
import '../../application/unit_provider.dart';
import '../../models/material_model.dart';
import '../../models/product_material_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/unit_quantity_input.dart';
import '../widgets/status_badge.dart';

// Página de Materiales: lista de materiales y registro de uso por producto,
// como dos tabs internos. Se llega aquí desde la tarjeta "Materiales" del
// tab "Inventario" de la navegación inferior.
class MaterialsPage extends ConsumerWidget {
  const MaterialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Materiales',
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
              Tab(text: 'Materiales'),
              Tab(text: 'Registro de uso'),
            ],
          ),
        ),
        body: const TabBarView(children: [MaterialsListTab(), MaterialsUsageTab()]),
      ),
    );
  }
}

// Tab de lista de materiales, sin AppBar propia (la aporta MaterialsPage).
class MaterialsListTab extends ConsumerWidget {
  const MaterialsListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(materialProvider);
    final units = ref.watch(unitProvider).units;
    final status = ref.watch(materialStatusFilterProvider);
    final query = ref.watch(materialListQueryProvider);
    // Búsqueda por nombre (sin distinguir tildes) y filtro por estado.
    final visible = filterByQuery<MaterialModel>(
      state.materials.where((m) => status.matches(m.isActive)),
      query,
      (m) => m.name,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // Tag único: evita colisiones de Hero cuando varias pestañas con FAB
        // conviven montadas a la vez bajo el shell de navegación inferior.
        heroTag: 'materials_list_tab_fab',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _showDialog(context, null),
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      body: Column(
        children: [
          // El buscador (por nombre) comparte el ancho con el filtro de estado.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: CatalogSearchField(
                    initialText: query,
                    hintText: 'Buscar material',
                    onChanged: (value) =>
                        ref.read(materialListQueryProvider.notifier).state =
                            value,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                StatusFilterChip(
                  value: status,
                  onChanged: (value) =>
                      ref.read(materialStatusFilterProvider.notifier).state =
                          value,
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.materials.isEmpty
                ? Center(
                    child: Text(
                      'No se registraron materiales',
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
                      final m = visible[index];
                      return _MaterialCard(
                        material: m,
                        unitName: units
                            .where((u) => u.id == m.unitId)
                            .firstOrNull
                            ?.name,
                        onEdit: () => _showDialog(context, m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, MaterialModel? material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MaterialDialog(material: material),
    );
  }
}

// Tab de registro de uso de materiales por producto. Se usa como sub-tab
// dentro del tab "Inventario" de la navegación inferior; no tiene AppBar propia.
class MaterialsUsageTab extends ConsumerStatefulWidget {
  const MaterialsUsageTab({super.key});

  @override
  ConsumerState<MaterialsUsageTab> createState() => _MaterialsUsageTabState();
}

class _MaterialsUsageTabState extends ConsumerState<MaterialsUsageTab> {
  int? _selectedProductId;
  List<ProductMaterialModel> _usageLog = [];
  bool _loading = false;

  Future<void> _loadUsageLog(int productId) async {
    setState(() => _loading = true);
    final log = await ref
        .read(materialProvider.notifier)
        .getMaterialsForProduct(productId);
    if (mounted) {
      setState(() {
        _usageLog = log;
        _loading = false;
      });
    }
  }

  void _showRegisterSheet() {
    if (_selectedProductId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RegisterUsageSheet(
        productId: _selectedProductId!,
        onRegistered: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  void _showEditSheet(ProductMaterialModel entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditUsageSheet(
        entry: entry,
        onEdited: () => _loadUsageLog(_selectedProductId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref
        .watch(productProvider)
        .products
        .where((p) => p.isActive)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _selectedProductId != null
          ? FloatingActionButton(
              // Tag único: evita colisiones de Hero cuando varias pestañas
              // con FAB conviven montadas a la vez bajo el shell de
              // navegación inferior.
              heroTag: 'materials_usage_tab_fab',
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              onPressed: _showRegisterSheet,
              child: const Icon(Icons.add, color: AppColors.surface),
            )
          : null,
      body: Column(
        children: [
          // Selector de producto: búsqueda por nombre, sin lista hasta escribir.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: SearchablePickerField<int>(
              label: 'Producto',
              searchHint: 'Buscar producto',
              value: _selectedProductId,
              options: [
                for (final p in products) PickerOption<int>(p.id, p.name),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedProductId = val;
                  _usageLog = [];
                });
                if (val != null) _loadUsageLog(val);
              },
            ),
          ),

          if (_selectedProductId == null)
            Expanded(
              child: Center(
                child: Text(
                  'Selecciona un producto para ver\nel registro de uso de materiales',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_usageLog.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Sin registros de uso',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s16 + 56 + AppSpacing.s16,
                ),
                itemCount: _usageLog.length,
                itemBuilder: (context, index) {
                  final entry = _usageLog[index];
                  return Container(
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.materialName,
                                      style: Theme.of(context).textTheme
                                          .displayMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: entry.isCanceled
                                                ? AppColors.textSecondary
                                                : AppColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                  if (entry.isCanceled) ...[
                                    const SizedBox(width: AppSpacing.s8),
                                    const StatusBadge.canceled(label: 'Cancelado'),
                                  ],
                                ],
                              ),
                              // Cantidad y precio son dos piezas que no se
                              // parten por dentro: si no caben juntas, el
                              // precio completo pasa a la línea de abajo.
                              Wrap(
                                spacing: AppSpacing.s16,
                                children: [
                                  for (final piece in [
                                    'Cantidad: ${formatNumber(entry.quantityUsed)} ${unitLabel(entry.materialUnitName, entry.quantityUsed)}',
                                    'Bs. ${entry.pricePerUnit.toStringAsFixed(2)} / ${entry.materialUnitName}',
                                  ])
                                    Text(
                                      piece,
                                      softWrap: false,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Un registro cancelado es solo historial: sin acciones.
                        if (!entry.isCanceled) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            tooltip: 'Editar registro',
                            onPressed: () => _showEditSheet(entry),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Hoja para registrar nuevo uso de material
class _RegisterUsageSheet extends ConsumerStatefulWidget {
  final int productId;
  final VoidCallback onRegistered;

  const _RegisterUsageSheet({
    required this.productId,
    required this.onRegistered,
  });

  @override
  ConsumerState<_RegisterUsageSheet> createState() =>
      _RegisterUsageSheetState();
}

class _RegisterUsageSheetState extends ConsumerState<_RegisterUsageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  int? _selectedMaterialId;
  double _fractionQuantity = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_clearError);
  }

  // Un aviso de error (p. ej. "Selecciona una cantidad") desaparece en cuanto
  // la persona cambia la cantidad o el material.
  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final material = ref
        .read(materialProvider)
        .materials
        .where((m) => m.id == _selectedMaterialId)
        .firstOrNull;
    final unit = material != null
        ? ref
              .read(unitProvider)
              .units
              .where((u) => u.id == material.unitId)
              .firstOrNull
        : null;
    final usesFractions = unit != null && isFractionFriendlyUnitType(unit.type);

    if (_selectedMaterialId == null) {
      setState(() => _error = 'Selecciona un material');
      return;
    }
    if (!usesFractions && !_formKey.currentState!.validate()) return;

    final quantity = usesFractions
        ? _fractionQuantity
        : double.tryParse(_quantityController.text.trim()) ?? 0;

    if (quantity <= 0) {
      setState(() => _error = 'Selecciona una cantidad');
      return;
    }
    if (material != null && quantity > material.stock) {
      setState(
        () => _error =
            'Cantidad máxima disponible: ${formatNumber(material.stock)}',
      );
      return;
    }

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .registerUsage(
          productId: widget.productId,
          materialId: _selectedMaterialId!,
          quantityUsed: quantity,
        );

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo materiales activos con stock mayor a 0
    final materials = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.isActive && m.stock > 0)
        .toList();
    final units = ref.watch(unitProvider).units;
    final selectedMaterial = _selectedMaterialId != null
        ? materials.where((m) => m.id == _selectedMaterialId).firstOrNull
        : null;
    final selectedUnit = selectedMaterial != null
        ? units.where((u) => u.id == selectedMaterial.unitId).firstOrNull
        : null;

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
                'Registrar el uso de un material',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Selector de material con stock visible
              // Buscar y elegir por nombre, igual que el producto: escala con
              // la cantidad de materiales y no lista nada hasta escribir.
              SearchablePickerField<int>(
                label: 'Material',
                searchHint: 'Buscar material',
                value: _selectedMaterialId,
                options: [
                  for (final m in materials) PickerOption<int>(m.id, m.name),
                ],
                onChanged: (val) => setState(() {
                  _selectedMaterialId = val;
                  _error = null;
                }),
              ),
              // Muestra el stock disponible del material seleccionado
              if (selectedMaterial != null) ...[
                const SizedBox(height: AppSpacing.s6),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.s4),
                  child: Text(
                    'Stock disponible: ${formatNumber(selectedMaterial.stock)}${selectedUnit != null ? ' ${unitLabel(selectedUnit.name, selectedMaterial.stock)}' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),

              // Cantidad: para unidades tipo envase (contenedor, paquete, rollo, tira) se
              // ofrecen fracciones simples en vez de pedir un decimal exacto;
              // para unidades "por pieza" (unidad genérica) se exige un entero.
              if (selectedUnit != null &&
                  isFractionFriendlyUnitType(selectedUnit.type))
                FractionQuantityPicker(
                  unit: selectedUnit.name,
                  value: _fractionQuantity,
                  onChanged: (v) => setState(() {
                    _fractionQuantity = v;
                    _error = null;
                  }),
                  label: 'Cantidad utilizada',
                )
              else if (selectedUnit != null &&
                  isDiscreteUnit(selectedUnit.type, selectedUnit.name))
                WholeNumberQuantityField(
                  controller: _quantityController,
                  labelText: 'Cantidad utilizada (${selectedUnit.name})',
                )
              else
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: selectedUnit != null
                        ? 'Cantidad utilizada (${selectedUnit.name})'
                        : 'Cantidad utilizada',
                    hintText: '0',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    final qty = double.tryParse(v);
                    if (qty == null || qty <= 0) return 'Cantidad inválida';
                    return null;
                  },
                ),
              const SizedBox(height: AppSpacing.s12),

              // Error del servidor
              if (_error != null)
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
                          _error!,
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

              const SizedBox(height: AppSpacing.s24),

              // Botones cancelar y registrar
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
                      onPressed: _register,
                      child: Text(
                        'Registrar',
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

// Hoja para editar cantidad de un registro de uso existente
class _EditUsageSheet extends ConsumerStatefulWidget {
  final ProductMaterialModel entry;
  final VoidCallback onEdited;

  const _EditUsageSheet({required this.entry, required this.onEdited});

  @override
  ConsumerState<_EditUsageSheet> createState() => _EditUsageSheetState();
}

class _EditUsageSheetState extends ConsumerState<_EditUsageSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late double _fractionQuantity;
  String? _error;

  bool get _usesFractions =>
      isFractionFriendlyUnitType(widget.entry.materialUnitType);

  bool get _isDiscrete => isDiscreteUnit(
    widget.entry.materialUnitType,
    widget.entry.materialUnitName,
  );

  @override
  void initState() {
    super.initState();
    // Precarga la cantidad actual formateada
    _quantityController = TextEditingController(
      text: formatNumber(widget.entry.quantityUsed),
    );
    _fractionQuantity = widget.entry.quantityUsed;
    _quantityController.addListener(_clearError);
  }

  // Un aviso de error (p. ej. "Selecciona una cantidad") desaparece en cuanto
  // la persona cambia la cantidad o el material.
  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Cancela el registro de uso (no lo borra): devuelve la cantidad al stock
  // del material y deja el registro en el historial marcado como cancelado.
  // Solo se ofrece dentro de este formulario de edición.
  Future<void> _cancelUsage() async {
    final entry = widget.entry;
    final confirmed = await confirmCancellation(
      context,
      title: '¿Cancelar registro de uso?',
      message:
          'Se devolverá ${formatNumber(entry.quantityUsed)} '
          '${unitLabel(entry.materialUnitName, entry.quantityUsed)} de '
          '"${entry.materialName}" al stock.',
      confirmLabel: 'Cancelar registro',
    );
    if (!confirmed || !mounted) return;
    final error = await ref.read(materialProvider.notifier).cancelUsage(entry.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.onEdited();
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (!_usesFractions && !_formKey.currentState!.validate()) return;

    final newQuantity = _usesFractions
        ? _fractionQuantity
        : double.tryParse(_quantityController.text.trim()) ?? 0;

    if (_usesFractions && newQuantity <= 0) {
      setState(() => _error = 'Selecciona una cantidad');
      return;
    }

    setState(() => _error = null);

    final error = await ref
        .read(materialProvider.notifier)
        .editUsage(recordId: widget.entry.id, newQuantity: newQuantity);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onEdited();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula stock disponible para validación
    final material = ref
        .watch(materialProvider)
        .materials
        .where((m) => m.id == widget.entry.materialId)
        .firstOrNull;

    // Stock disponible = stock actual + cantidad original del registro
    final availableStock = (material?.stock ?? 0) + widget.entry.quantityUsed;

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
                'Editar registro de uso',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              // Muestra el material que se está editando
              Text(
                widget.entry.materialName,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Campo de cantidad: fracciones simples para unidades tipo
              // envase, número decimal para el resto.
              if (_usesFractions) ...[
                FractionQuantityPicker(
                  unit: widget.entry.materialUnitName,
                  value: _fractionQuantity,
                  onChanged: (v) {
                    setState(() {
                      _fractionQuantity = v;
                      _error = null;
                    });
                  },
                  label: 'Nueva cantidad',
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  'Máximo disponible: ${formatNumber(availableStock)} ${unitLabel(widget.entry.materialUnitName, availableStock)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ] else if (_isDiscrete)
                WholeNumberQuantityField(
                  controller: _quantityController,
                  labelText: 'Nueva cantidad (${widget.entry.materialUnitName})',
                  helperText:
                      'Máximo disponible: ${formatNumber(availableStock)} ${unitLabel(widget.entry.materialUnitName, availableStock)}',
                  extraValidator: (qty) => qty > availableStock
                      ? 'Máximo: ${formatNumber(availableStock)}'
                      : null,
                )
              else
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nueva cantidad (${widget.entry.materialUnitName})',
                    hintText: '0',
                    helperText:
                        'Máximo disponible: ${formatNumber(availableStock)} ${unitLabel(widget.entry.materialUnitName, availableStock)}',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    final qty = double.tryParse(v);
                    if (qty == null || qty <= 0) return 'Cantidad inválida';
                    if (qty > availableStock) {
                      return 'Máximo: ${formatNumber(availableStock)}';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: AppSpacing.s12),

              // Error del servidor
              if (_error != null)
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
                          _error!,
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

              const SizedBox(height: AppSpacing.s24),

              // Botones cancelar y guardar
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
                        'Guardar',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),

              // Cancelar el registro: solo aquí, al final del formulario.
              const SizedBox(height: AppSpacing.s12),
              TextButton.icon(
                onPressed: _cancelUsage,
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 20,
                ),
                label: const Text(
                  'Cancelar registro',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tarjeta de material en la lista
class _MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final String? unitName;
  final VoidCallback onEdit;

  const _MaterialCard({
    required this.material,
    required this.unitName,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  material.name,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (material.description != null &&
                    material.description!.isNotEmpty)
                  Text(
                    material.description!,
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s2,
                  children: [
                    Text(
                      'Stock: ${formatNumber(material.stock)}${unitName != null ? ' ${unitLabel(unitName!, material.stock)}' : ''}',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'Bs. ${material.pricePerUnit.toStringAsFixed(2)}${unitName != null ? ' / $unitName' : ''}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                StatusBadge.forState(
isActive: material.isActive,
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
    );
  }
}
