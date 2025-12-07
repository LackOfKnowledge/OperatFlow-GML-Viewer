import 'package:xml/xml.dart';

/// Base contract for single-feature parsers used by [GmlRepository].
abstract class GmlFeatureParser<T> {
  String get featureName;
  T? parse(XmlElement element);
}
