import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:gmlviewer/gml_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parse sample GML and link data', () async {
    final file = File('test/sample.gml');
    final Uint8List bytes = await file.readAsBytes();

    final service = GmlService();
    await service.parseGml(bytes);

    expect(service.parcels.length, 1);

    final parcel = service.parcels.first;
    expect(parcel.idDzialki, '221208_2.0026.60/5');
    expect(parcel.jrgId, 'JRG.1');
    expect(parcel.pointRefs, ['P.1', 'P.2']);

    final points = service.getPointsForParcel(parcel);
    expect(points.length, 2);
    expect(points.first.numer, '101');
    expect(points.first.isd, 'PZG');

    final subjectsWithShares = service.getSubjectsForParcel(parcel);
    expect(subjectsWithShares.length, 2);

    final firstSubject = subjectsWithShares.first.value;
    expect(firstSubject?.name, 'Jan Kowalski');
  });

  test('parse sample_v2 GML with alternate field names', () async {
    final file = File('test/sample_v2.gml');
    final Uint8List bytes = await file.readAsBytes();

    final service = GmlService();
    await service.parseGml(bytes);

    expect(service.parcels.length, 1);

    final parcel = service.parcels.first;
    expect(parcel.idDzialki, '221208_2.0026.60/6');
    expect(parcel.jrgId, 'JRG.2');

    final points = service.getPointsForParcel(parcel);
    expect(points.length, 1);
    final point = points.first;
    expect(point.numer, '340');
    expect(point.operat, 'P.2212.2002.1003');
    expect(point.x, '6042040.56');
    expect(point.y, '6433056.02');

    final subjectsWithShares = service.getSubjectsForParcel(parcel);
    expect(subjectsWithShares.length, 1);
    final subject = subjectsWithShares.first.value;
    expect(subject?.name, 'Czesław Bazyk');
    expect(subjectsWithShares.first.key.share, '3/4');
  });
}
