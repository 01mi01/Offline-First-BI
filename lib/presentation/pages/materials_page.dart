import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/material_provider.dart';
import '../../application/product_provider.dart';
import '../../models/material_model.dart';
import '../../models/product_material_model.dart';
import '../../theme/app_theme.dart';
import '../dialogs/material_dialog.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/unit_quantity_input.dart';

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
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.materials.isEmpty
          ? Center(
              child: Text(
                'No hay materiales registrados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.s16),
              itemCount: state.materials.length,
              itemBuilder: (context, index) {
                final m = state.materials[index];
                return _MaterialCard(
                  material: m,
                  onEdit: () => _showDialog(context, m),
                );
              },
            ),
    );
  }

  void _showDialog(BuildContext context, MaterialModel? material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          // Selector de producto
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedProductId,
                  isExpanded: true,
                  hint: const Text('Selecciona un producto'),
                  items: products
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProductId = val;
                      _usageLog = [];
                    });
                    if (val != null) _loadUsageLog(val);
                  },
                ),
              ),
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
                  AppSpacing.s16,
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
                              Text(
                                entry.materialName,
                                style: Theme.of(context).textTheme
                                    .displayMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              Text(
                                'Cantidad: ${formatNumber(entry.quantityUsed)}  •  Bs. ${entry.pricePerUnit.toStringAsFixed(2)}/u',
                                style: Theme.of(context).textTheme
                                    .labelMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        // Botón editar registro
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () => _showEditSheet(entry),
                        ),
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
    final usesFractions =
        material != null && isFractionFriendlyUnit(material.unit);

    if (!usesFractions && !_formKey.currentState!.validate()) return;
    if (_selectedMaterialId == null) return;

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

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: AppSpacing.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s32,
      ),
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
            DropdownButtonFormField<int>(
              value: _selectedMaterialId,
              decoration: const InputDecoration(labelText: 'Material'),
              items: materials
                  .map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedMaterialId = val),
              validator: (v) => v == null ? 'Selecciona un material' : null,
            ),
            // Muestra el stock disponible del material seleccionado
            if (_selectedMaterialId != null) ...[
              const SizedBox(height: AppSpacing.s6),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s4),
                child: Text(
                  'Stock disponible: ${formatNumber(materials.where((m) => m.id == _selectedMaterialId).first.stock)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),

            // Cantidad: para unidades tipo envase (botella, bolsa...) se
            // ofrecen fracciones simples en vez de pedir un decimal exacto.
            if (_selectedMaterialId != null &&
                isFractionFriendlyUnit(
                  materials
                      .where((m) => m.id == _selectedMaterialId)
                      .first
                      .unit,
                ))
              FractionQuantityPicker(
                unit: materials
                    .where((m) => m.id == _selectedMaterialId)
                    .first
                    .unit,
                value: _fractionQuantity,
                onChanged: (v) => setState(() => _fractionQuantity = v),
                label: 'Cantidad utilizada',
              )
            else
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _selectedMaterialId != null
                      ? 'Cantidad utilizada (${materials.where((m) => m.id == _selectedMaterialId).first.unit})'
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
  bool _hasChanges = false;

  bool get _usesFractions => isFractionFriendlyUnit(widget.entry.materialUnit);

  @override
  void initState() {
    super.initState();
    // Precarga la cantidad actual formateada
    _quantityController = TextEditingController(
      text: formatNumber(widget.entry.quantityUsed),
    );
    _fractionQuantity = widget.entry.quantityUsed;
    _quantityController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final changed = _usesFractions
        ? _fractionQuantity != widget.entry.quantityUsed
        : _quantityController.text.trim() !=
              formatNumber(widget.entry.quantityUsed);
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
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
                unit: widget.entry.materialUnit,
                value: _fractionQuantity,
                onChanged: (v) {
                  setState(() => _fractionQuantity = v);
                  _checkChanges();
                },
                label: 'Nueva cantidad',
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                'Máximo disponible: ${formatNumber(availableStock)}',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ] else
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nueva cantidad (${widget.entry.materialUnit})',
                  hintText: '0',
                  helperText:
                      'Máximo disponible: ${formatNumber(availableStock)}',
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
                    onPressed: _hasChanges ? _save : null,
                    child: Text(
                      'Guardar',
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
    );
  }
}

// Tarjeta de material en la lista
class _MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onEdit;

  const _MaterialCard({required this.material, required this.onEdit});

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
                Row(
                  children: [
                    Text(
                      'Stock: ${formatNumber(material.stock)}',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Bs. ${material.pricePerUnit.toStringAsFixed(2)}/u',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: material.isActive
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    material.isActive ? 'Activo' : 'Inactivo',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: material.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
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
