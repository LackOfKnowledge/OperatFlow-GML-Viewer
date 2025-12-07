import 'package:flutter/material.dart';
import '../../../data/models/address.dart';
import '../../../data/models/boundary_point.dart';
import '../../../data/models/building.dart';
import '../../../data/models/land_use.dart';
import '../../../data/models/legal_basis.dart';
import '../../../data/models/parcel.dart';
import '../../../data/models/premises.dart';
import '../../../data/models/subject.dart';
import '../../../repositories/gml_repository.dart';

enum ParcelDetailView { parcel, parties, points, buildings }

class ParcelDetailsPanel extends StatelessWidget {
  final Parcel parcel;
  final GmlRepository gmlRepository;
  final ParcelDetailView view;

  const ParcelDetailsPanel({
    super.key,
    required this.parcel,
    required this.gmlRepository,
    this.view = ParcelDetailView.parcel,
  });

  @override
  Widget build(BuildContext context) {
    final addresses = gmlRepository.getAddressesForParcel(parcel);
    final owners = gmlRepository.getSubjectsForParcel(parcel);
    final points = gmlRepository.getPointsForParcel(parcel);
    final buildings = gmlRepository.getBuildingsForParcel(parcel);
    final premises = gmlRepository.getPremisesForParcel(parcel);
    final legalBases = gmlRepository.getLegalBasesForParcel(parcel);
    final useContours = gmlRepository.getLandUseContours(parcel);
    final classContours = gmlRepository.getClassificationContours(parcel);

    final children = <Widget>[];

    if (view == ParcelDetailView.parcel) {
      children.addAll([
        _section(
          context,
          title: 'Dzialka',
          children: [
            _kv('Identyfikator', parcel.idDzialki),
            _kv('Numer dzialki', parcel.numerDzialki),
            _kv('KW', parcel.numerKW ?? '-'),
            _kv('Rodzaj dzialki', parcel.rodzajDzialkiLabel ?? parcel.rodzajDzialkiCode ?? '-'),
            _kv('Pow. ewidencyjna', parcel.pole?.toString() ?? '-'),
            _kv('Pow. z geometrii', parcel.poleGeometryczne?.toString() ?? '-'),
            _kv('Jednostka ewid.', '${parcel.jednostkaNazwa ?? '-'} [${parcel.jednostkaId ?? '-'}]'),
            _kv('Obreb', _formatObreb(parcel)),
          ],
        ),
        _section(
          context,
          title: 'Adresy nieruchomosci',
          children: addresses.isNotEmpty
              ? addresses.map((a) => Text(a.toSingleLine())).toList()
              : [const Text('Brak adresow')],
        ),
        if (useContours.isNotEmpty || parcel.uzytki.isNotEmpty)
          _section(
            context,
            title: 'Kontury uzytkow',
            children: [
              ...parcel.uzytki.map(_landUseRow),
              ...useContours.map(_landUseRow),
            ],
          ),
        if (classContours.isNotEmpty)
          _section(
            context,
            title: 'Kontury klasouzytkow',
            children: classContours.map(_landUseRow).toList(),
          ),
      ]);
    }

    if (view == ParcelDetailView.parties) {
      children.addAll([
        _section(
          context,
          title: 'Adresy nieruchomosci',
          children: addresses.isNotEmpty
              ? addresses.map((a) => Text(a.toSingleLine())).toList()
              : [const Text('Brak adresow')],
        ),
        _section(
          context,
          title: 'Podmioty i udzialy',
          children: owners.isNotEmpty
              ? owners
                  .map((entry) {
                    final subject = entry.value;
                    final shareText =
                        '${entry.key.share}${entry.key.rightTypeLabel != null ? ' (${entry.key.rightTypeLabel})' : ''}';
                    return _kv(subject?.name ?? 'Nieznany podmiot', shareText);
                  })
                  .toList()
              : [const Text('Brak podmiotow')],
        ),
        _section(
          context,
          title: 'Adresy podmiotow',
          children: owners
              .map((entry) {
                final subject = entry.value;
                final subjectAddresses =
                    subject != null ? gmlRepository.getAddressesForSubject(subject) : const <Address>[];
                if (subject == null || subjectAddresses.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _kv(
                  subject.name,
                  subjectAddresses.map((a) => a.toSingleLine()).join('\n'),
                );
              })
              .where((w) => w is! SizedBox)
              .toList(),
        ),
        if (legalBases.isNotEmpty)
          _section(
            context,
            title: 'Podstawy prawne',
            children: legalBases
                .map((l) => _kv(
                      l.number ?? l.gmlId,
                      '${l.type} ${l.documentTypeLabel ?? l.documentTypeCode ?? ''} ${l.date ?? ''} ${l.description ?? ''}',
                    ))
                .toList(),
          ),
      ]);
    }

    if (view == ParcelDetailView.points) {
      children.add(
        _section(
          context,
          title: 'Punkty graniczne',
          children: [
            if (points.isEmpty) const Text('Brak punktow'),
            if (points.isNotEmpty)
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  _tableHeader(['Id', 'Nr', 'SPD', 'ISD', 'STB', 'Operat']),
                  ...points.map(_pointRow),
                ],
              ),
          ],
        ),
      );
    }

    if (view == ParcelDetailView.buildings) {
      if (buildings.isNotEmpty) {
        children.add(
          _section(
            context,
            title: 'Budynki',
            children: buildings
                .map((b) => _kv(
                      b.buildingId ?? b.gmlId,
                      [
                        if (b.number != null) 'nr ${b.number}',
                        if (b.functionCode != null) 'funkcja ${b.functionCode}',
                        if (b.floors != null) 'kond. ${b.floors}',
                        if (b.usableArea != null) 'Pu ${b.usableArea}',
                      ].where((e) => e.isNotEmpty).join(', '),
                    ))
                .toList(),
          ),
        );
      }
      if (premises.isNotEmpty) {
        children.add(
          _section(
            context,
            title: 'Lokale',
            children: premises
                .map((l) => _kv(
                      l.premisesId ?? l.gmlId,
                      [
                        if (l.number != null) 'nr ${l.number}',
                        if (l.typeCode != null) 'rodzaj ${l.typeCode}',
                        if (l.floor != null) 'kond. ${l.floor}',
                        if (l.usableArea != null) 'Pu ${l.usableArea}',
                      ].where((e) => e.isNotEmpty).join(', '),
                    ))
                .toList(),
          ),
        );
      }
      if (buildings.isEmpty && premises.isEmpty) {
        children.add(_section(context, title: 'Budynki i lokale', children: const [Text('Brak danych')]));
      }
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _section(BuildContext context, {required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...children.map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: w)).toList(),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? '-' : value)),
      ],
    );
  }

  Widget _landUseRow(LandUse use) {
    final parts = [use.ofu, use.ozu, if (use.ozk != null) use.ozk!].where((s) => s.isNotEmpty).join(' / ');
    final pow = use.powierzchnia != null ? '${use.powierzchnia}' : '-';
    return _kv(parts, 'Pow: $pow');
  }

  TableRow _tableHeader(List<String> cells) {
    return TableRow(
      children: cells
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  c,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ))
          .toList(),
    );
  }

  TableRow _pointRow(BoundaryPoint p) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.displayFullId)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.displayNumer)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.spd ?? '-')),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.isd ?? '-')),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.stb ?? '-')),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.operat ?? '-')),
      ],
    );
  }

  String _formatObreb(Parcel parcel) {
    final reg = RegExp(r'^\d+_\d\.(\d{4})');
    final match = reg.firstMatch(parcel.idDzialki);
    final obrebNumber = match != null ? match.group(1) : parcel.obrebId ?? '-';
    final name = parcel.obrebNazwa ?? '';
    if (name.isNotEmpty) {
      return '$name ${obrebNumber ?? ''}'.trim();
    }
    return obrebNumber ?? '-';
  }
}
