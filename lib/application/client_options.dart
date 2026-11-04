import '../models/client_model.dart';
import 'form_validation.dart';

const int clientPickerContactLength = 40;
const int clientShortContactLength = 20;

String? clientContactLine(
  ClientModel client, {
  int maxLength = clientPickerContactLength,
  bool firstLineOnly = false,
}) {
  var text = client.contactInfo?.trim();
  if (text == null || text.isEmpty) return null;
  text = firstLineOnly
      ? text.split(RegExp(r'[\r\n]+')).first
      : text.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' · ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength).trimRight()}…';
}

String? clientShortContact(ClientModel client) => clientContactLine(
  client,
  maxLength: clientShortContactLength,
  firstLineOnly: true,
);

String clientSelectedLabel(ClientModel client) {
  final contact = clientShortContact(client);
  return contact == null ? client.name : '${client.name} · $contact';
}

bool clientNameIsShared(ClientModel client, Iterable<ClientModel> all) {
  final name = comparableName(client.name);
  return all.any((o) => o.id != client.id && comparableName(o.name) == name);
}

String clientNameText(ClientModel client, Iterable<ClientModel> all) =>
    clientNameIsShared(client, all) ? clientSelectedLabel(client) : client.name;
