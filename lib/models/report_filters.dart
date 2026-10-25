import 'date_preset.dart';
import 'purchase_kind.dart';

class ReportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? categoryId;
  final int? productId;
  final int? eventId;
  final int? locationId;
  final int? clientId;
  final int? supplierId;
  final String? priceType;
  final String? country;
  final String? city;
  final PurchaseKind purchaseKind;
  final DatePreset? datePreset;

  const ReportFilters({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.productId,
    this.eventId,
    this.locationId,
    this.clientId,
    this.supplierId,
    this.priceType,
    this.country,
    this.city,
    this.purchaseKind = PurchaseKind.all,
    this.datePreset,
  });

  DateTime? get effectiveEndDate => endDate ?? startDate;

  ReportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? productId,
    int? eventId,
    int? locationId,
    int? clientId,
    int? supplierId,
    String? priceType,
    String? country,
    String? city,
    PurchaseKind? purchaseKind,
    DatePreset? datePreset,
    bool clearDatePreset = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearCategory = false,
    bool clearProduct = false,
    bool clearEvent = false,
    bool clearLocation = false,
    bool clearClient = false,
    bool clearSupplier = false,
    bool clearPriceType = false,
    bool clearCountry = false,
    bool clearCity = false,
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
      priceType: clearPriceType ? null : priceType ?? this.priceType,
      country: clearCountry ? null : country ?? this.country,
      city: clearCity ? null : city ?? this.city,
      purchaseKind: purchaseKind ?? this.purchaseKind,
      datePreset: clearDatePreset ? null : datePreset ?? this.datePreset,
    );
  }

  ReportFilters refreshedFor(DateTime today) {
    final preset = datePreset;
    if (preset == null) return this;
    final day = DateTime(today.year, today.month, today.day);
    return copyWith(startDate: preset.start(day), endDate: day);
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
          supplierId == other.supplierId &&
          priceType == other.priceType &&
          country == other.country &&
          city == other.city &&
          purchaseKind == other.purchaseKind &&
          datePreset == other.datePreset;

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
    priceType,
    country,
    city,
    purchaseKind,
    datePreset,
  );
}
