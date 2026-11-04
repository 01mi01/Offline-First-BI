import '../config/date_formatters.dart';
import '../models/event_model.dart';
import '../models/location_model.dart';

String eventLabel(EventModel e) => '${e.name} (${e.startDate.year})';

String eventSubtitle(EventModel e, LocationModel? location) {
  final date = formatDate(e.startDate);
  return location == null ? date : '$date · ${location.city}';
}
