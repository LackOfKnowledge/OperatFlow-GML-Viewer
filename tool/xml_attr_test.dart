import 'package:xml/xml.dart';

void main() {
  const xmlString = '''
<root xmlns:xlink="http://www.w3.org/1999/xlink">
  <egb:JRG2 xlink:href="#JRG.1" xmlns:egb="ewidencjaGruntowIBudynkow:1.0" />
</root>
''';

  final document = XmlDocument.parse(xmlString);
  final elementByQualified = document.findAllElements('egb:JRG2').first;
  final elementByLocal = document.descendants
      .whereType<XmlElement>()
      .firstWhere((e) => e.name.local == 'JRG2');

  final attr1 = elementByQualified.getAttribute('xlink:href');
  final attr2 = elementByQualified.getAttribute(
    'href',
    namespace: 'http://www.w3.org/1999/xlink',
  );

  print('qualified == local? ${identical(elementByQualified, elementByLocal)}');
  print('attr1 (xlink:href): $attr1');
  print('attr2 (href ns=xlink): $attr2');

  const gmlString = '''
<gml:FeatureCollection 
    xmlns:egb="ewidencjaGruntowIBudynkow:1.0" 
    xmlns:gml="http://www.opengis.net/gml/3.2" 
    xmlns:xlink="http://www.w3.org/1999/xlink">
  <gml:featureMember>
    <egb:Foo />
  </gml:featureMember>
</gml:FeatureCollection>
''';

  final gmlDoc = XmlDocument.parse(gmlString);
  final fmsByNs =
      gmlDoc.findAllElements('featureMember', namespace: 'http://www.opengis.net/gml/3.2');
  final fmsByQualified = gmlDoc.findAllElements('gml:featureMember');

  print('featureMembers by ns: ${fmsByNs.length}');
  print('featureMembers by qualified: ${fmsByQualified.length}');
}
