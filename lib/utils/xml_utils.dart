import 'package:xml/xml.dart';

String? stripHref(String? href) {
  if (href == null) return null;
  return href.startsWith('#') ? href.substring(1) : href;
}

extension XmlElementX on XmlElement {
  Iterable<XmlElement> findDescendantsByLocal(String localName) sync* {
    for (final node in descendants.whereType<XmlElement>()) {
      if (node.name.local == localName) yield node;
    }
  }

  XmlElement? firstDescendantByLocal(String localName, {String? namespace}) {
    for (final node in descendants.whereType<XmlElement>()) {
      final matchesName = node.name.local == localName;
      final matchesNs = namespace == null || node.name.namespaceUri == namespace;
      if (matchesName && matchesNs) return node;
    }
    return null;
  }

  String? textOf(String localName, {String? namespace}) {
    final el = firstDescendantByLocal(localName, namespace: namespace);
    final text = el?.innerText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  String? attributeValue(String localName, {String? namespace}) {
    for (final attr in attributes) {
      final matchesName = attr.name.local == localName;
      final matchesNs = namespace == null || attr.name.namespaceUri == namespace;
      if (matchesName && matchesNs) return attr.value;
    }
    return null;
  }
}

Map<String, String> collectUnknownAttributes(
  XmlElement element, {
  Set<String> knownLocals = const {},
  String prefix = '',
}) {
  final target = <String, String>{};
  void walk(XmlElement node, String currentPrefix) {
    final path = currentPrefix.isEmpty ? node.name.local : '$currentPrefix/${node.name.local}';
    for (final attr in node.attributes) {
      target.putIfAbsent('$path@${attr.name.local}', () => attr.value.trim());
    }

    final directText = node.children
        .whereType<XmlText>()
        .map((e) => e.text.trim())
        .where((t) => t.isNotEmpty)
        .join(' ');
    if (directText.isNotEmpty && !knownLocals.contains(node.name.local)) {
      target.putIfAbsent(path, () => directText);
    }

    final counters = <String, int>{};
    for (final child in node.children.whereType<XmlElement>()) {
      final idx = counters[child.name.local] ?? 0;
      counters[child.name.local] = idx + 1;
      walk(child, '$path/${child.name.local}[$idx]');
    }
  }

  walk(element, prefix);
  return target;
}

List<Map<String, double>> parsePolygon(XmlElement element, {String geometryLocalName = 'geometria'}) {
  final geometry = <Map<String, double>>[];
  final geomElement = element.firstDescendantByLocal(geometryLocalName);
  if (geomElement == null) return geometry;

  final posList = geomElement.findDescendantsByLocal('posList').firstOrNull;
  if (posList == null) return geometry;

  final coords = posList.innerText.trim().split(RegExp(r'\s+'));
  for (int i = 0; i < coords.length - 1; i += 2) {
    final val1 = double.tryParse(coords[i]);
    final val2 = double.tryParse(coords[i + 1]);
    if (val1 != null && val2 != null) {
      geometry.add({'x': val1, 'y': val2});
    }
  }
  return geometry;
}
