// Modelo de estado de filtros para el módulo de reportes
class ReportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? categoryId;
  final int? productId;
  final int? eventId;
  final int? locationId;
  final int? clientId;
  final int? supplierId;

  const ReportFilters({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.productId,
    this.eventId,
    this.locationId,
    this.clientId,
    this.supplierId,
  });

  bool get hasActive =>
      startDate != null ||
      endDate != null ||
      categoryId != null ||
      productId != null ||
      eventId != null ||
      locationId != null ||
      clientId != null ||
      supplierId != null;

  ReportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? productId,
    int? eventId,
    int? locationId,
    int? clientId,
    int? supplierId,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearCategory = false,
    bool clearProduct = false,
    bool clearEvent = false,
    bool clearLocation = false,
    bool clearClient = false,
    bool clearSupplier = false,
  }) {
    return ReportFilters(
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      productId: clearProduct ? null : productId ?? this.productId,
      eventId: clearEvent ? null : eventId ?? this.eventId,
      locationId: clearLocation ? null : locationId ?? this.locationId,
      clientId: clearClient ? null : clientId ?? this.clientId,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilters &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          categoryId == other.categoryId &&
          productId == other.productId &&
          eventId == other.eventId &&
          locationId == other.locationId &&
          clientId == other.clientId &&
          supplierId == other.supplierId;

  @override
  int get hashCode => Object.hash(
    startDate,
    endDate,
    categoryId,
    productId,
    eventId,
    locationId,
    clientId,
    supplierId,
  );
}
