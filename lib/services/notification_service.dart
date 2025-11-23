import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/address.dart';
import '../data/models/parcel.dart';
import '../data/teryt_data.dart';
import 'gml_service.dart';

class NotificationService {
  NotificationService(this.gmlService);

  final GmlService gmlService;

  Future<void> generateNotifications({
    required List<Parcel> parcels,
    required String notificationType,
    required String kergId,
    required DateTime date,
    required String surveyorName,
    required String surveyorLicense,
    required String place,
    required String meetingPlace,
    required String senderCompany,
    required String senderName,
    required String senderAddressLine1,
    required String senderAddressLine2,
    required String senderPhone,
    required String recipientName,
    required String recipientAddressLine1,
    required String recipientAddressLine2,
    required String rodoAdministrator,
    required String rodoContact,
    String? powiatManual,
  }) async {
    final pdf = await _buildPdf(
      parcels: parcels,
      notificationType: notificationType,
      kergId: kergId,
      date: date,
      surveyorName: surveyorName,
      surveyorLicense: surveyorLicense,
      place: place,
      meetingPlace: meetingPlace,
      senderCompany: senderCompany,
      senderName: senderName,
      senderAddressLine1: senderAddressLine1,
      senderAddressLine2: senderAddressLine2,
      senderPhone: senderPhone,
      recipientName: recipientName,
      recipientAddressLine1: recipientAddressLine1,
      recipientAddressLine2: recipientAddressLine2,
      rodoAdministrator: rodoAdministrator,
      rodoContact: rodoContact,
      powiatManual: powiatManual,
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  Future<Uint8List> _buildPdf({
    required List<Parcel> parcels,
    required String notificationType,
    required String kergId,
    required DateTime date,
    required String surveyorName,
    required String surveyorLicense,
    required String place,
    required String meetingPlace,
    required String senderCompany,
    required String senderName,
    required String senderAddressLine1,
    required String senderAddressLine2,
    required String senderPhone,
    required String recipientName,
    required String recipientAddressLine1,
    required String recipientAddressLine2,
    required String rodoAdministrator,
    required String rodoContact,
    String? powiatManual,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final List<_RecipientPage> recipients = [];

    for (final parcel in parcels) {
      final terytCode = parcel.idDzialki.split('.').first.replaceAll('_', '');
      final wojewodztwoCode = terytCode.substring(0, 2);
      final powiatCode = terytCode.substring(0, 4);

      final obreb = parcel.obrebNazwa ?? '-';
      final gmina = parcel.jednostkaNazwa ?? '-';
      final powiat = powiatManual?.isNotEmpty == true ? powiatManual! : (powiaty[powiatCode] ?? '-');
      final wojewodztwo = wojewodztwa[wojewodztwoCode] ?? '-';

      final owners = gmlService.getSubjectsForParcel(parcel);
      if (owners.isEmpty) {
        recipients.add(
          _RecipientPage(
            parcel: parcel,
            ownerName: recipientName,
            address: _addressFromForm(recipientAddressLine1, recipientAddressLine2),
            obreb: obreb,
            gmina: gmina,
            powiat: powiat,
            wojewodztwo: wojewodztwo,
          ),
        );
        continue;
      }

      for (final entry in owners) {
        final subject = entry.value;
        if (subject == null) continue;
        final addresses = gmlService.getAddressesForSubject(subject);
        if (addresses.isEmpty) {
          recipients.add(
            _RecipientPage(
              parcel: parcel,
              ownerName: subject.name,
              address: _addressFromForm(recipientAddressLine1, recipientAddressLine2),
              obreb: obreb,
              gmina: gmina,
              powiat: powiat,
              wojewodztwo: wojewodztwo,
            ),
          );
        } else {
          for (final addr in addresses) {
            recipients.add(
              _RecipientPage(
                parcel: parcel,
                ownerName: subject.name,
                address: addr,
                obreb: obreb,
                gmina: gmina,
                powiat: powiat,
                wojewodztwo: wojewodztwo,
              ),
            );
          }
        }
      }
    }

    final meetingDateStr = DateFormat('yyyy-MM-dd').format(date);
    final meetingTimeStr = DateFormat('HH:mm').format(date);

    for (final rec in recipients) {
      // strona 1
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildHeader(
              senderCompany: senderCompany,
              senderName: senderName,
              senderAddressLine1: senderAddressLine1,
              senderAddressLine2: senderAddressLine2,
              senderPhone: senderPhone,
              recipientName: rec.ownerName,
              recipientAddressLine1: _line1(rec.address),
              recipientAddressLine2: _line2(rec.address),
              place: place,
              date: date,
              kergId: kergId,
            ),
            pw.SizedBox(height: 20),
            _buildTitle(_notificationTitle(notificationType)),
            pw.SizedBox(height: 14),
            pw.Text(
              'Na podstawie art. 39 ust. 3 ustawy z dnia 17 maja 1989 r. Prawo geodezyjne '
              'i kartograficzne (t.j. Dz. U. z 2021 r. poz. 1990) uprzejmie zawiadamiam, że w dniu '
              '$meetingDateStr o godzinie $meetingTimeStr '
              'zostaną przeprowadzone czynności $notificationType dotyczące granic nieruchomości oznaczonej '
              'w ewidencji gruntów jako działka ${rec.parcel.pelnyNumerDzialki}, położonej w obrębie ${rec.obreb}, '
              'gmina ${rec.gmina}, powiat ${rec.powiat}, województwo ${rec.wojewodztwo}.',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Miejsce spotkania: $meetingPlace', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 10),
            pw.Text(
              'Czynności prowadzone będą w obecności zainteresowanych stron. Prosimy o zabranie dokumentów '
              'tożsamości oraz – w przypadku reprezentacji – stosownych pełnomocnictw.',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 14),
            _buildListSection('Działki objęte postępowaniem', [rec.parcel.pelnyNumerDzialki]),
            pw.SizedBox(height: 18),
            _buildSignature(surveyorName, surveyorLicense, kergId),
            pw.SizedBox(height: 20),
            _buildPouczenie(const pw.TextStyle(fontSize: 11)),
          ],
        ),
      );

      // strona 2 - RODO
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildRodo(
              rodoAdministrator: rodoAdministrator,
              rodoContact: rodoContact,
              kergId: kergId,
              paragraph: const pw.TextStyle(fontSize: 11),
              senderAddressLine1: senderAddressLine1,
              senderAddressLine2: senderAddressLine2,
            ),
          ],
        ),
      );
    }

    return doc.save();
  }

  Address _addressFromForm(String line1, String line2) {
    String? ulica;
    String? numer;
    String? kod;
    String? miejscowosc;
    if (line1.trim().isNotEmpty) {
      final parts = line1.split(' ');
      if (parts.length > 1) {
        numer = parts.removeLast();
        ulica = parts.join(' ');
      } else {
        ulica = line1;
      }
    }
    if (line2.trim().isNotEmpty) {
      final parts = line2.split(' ');
      if (parts.isNotEmpty) {
        kod = parts.first;
        miejscowosc = parts.skip(1).join(' ').trim();
      }
    }
    return Address(
      gmlId: 'manual',
      ulica: ulica,
      numerPorzadkowy: numer,
      kodPocztowy: kod,
      miejscowosc: miejscowosc,
    );
  }

  String _line1(Address? address) {
    if (address == null) return '';
    final street = [
      address.ulica,
      address.numerPorzadkowy,
    ].where((e) => e?.trim().isNotEmpty == true).join(' ');
    return street;
  }

  String _line2(Address? address) {
    if (address == null) return '';
    final city = [
      address.kodPocztowy,
      address.miejscowosc,
    ].where((e) => e?.trim().isNotEmpty == true).join(' ');
    return city;
  }

  pw.Widget _buildHeader({
    required String senderCompany,
    required String senderName,
    required String senderAddressLine1,
    required String senderAddressLine2,
    required String senderPhone,
    required String recipientName,
    required String recipientAddressLine1,
    required String recipientAddressLine2,
    required String place,
    required DateTime date,
    required String kergId,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(senderCompany, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(senderName),
              if (senderAddressLine1.isNotEmpty) pw.Text(senderAddressLine1),
              if (senderAddressLine2.isNotEmpty) pw.Text(senderAddressLine2),
              if (senderPhone.isNotEmpty) pw.Text(senderPhone),
              pw.Text('(nadawca)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(recipientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (recipientAddressLine1.isNotEmpty) pw.Text(recipientAddressLine1),
              if (recipientAddressLine2.isNotEmpty) pw.Text(recipientAddressLine2),
              pw.SizedBox(height: 4),
              pw.Text('(adresat)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 12),
              pw.Text('$place, dnia ${DateFormat('yyyy-MM-dd').format(date)}'),
              pw.Text('ID: KERG $kergId'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTitle(String title) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'ZAWIADOMIENIE',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'o $title',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildListSection(String heading, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(heading, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items.map((e) => pw.Text('- $e')).toList(),
        )
      ],
    );
  }

  pw.Widget _buildSignature(String surveyorName, String surveyorLicense, String kergId) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Geodeta Uprawniony'),
            pw.Text(surveyorName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('upr. nr $surveyorLicense'),
            pw.Text('KERG: $kergId', style: const pw.TextStyle(fontSize: 10)),
          ],
        )
      ],
    );
  }

  pw.Widget _buildPouczenie(pw.TextStyle style) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text('POUCZENIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Zawiadomieni właściciele (władający) gruntami proszeni są o przybycie w oznaczonym terminie ze wszelkimi dokumentami, '
          'jakie mogą być potrzebne przy przyjmowaniu granic ich gruntów oraz dokumentami tożsamości. '
          'W imieniu osób nieobecnych mogą występować odpowiednio upoważnieni pełnomocnicy. '
          'W przypadku współwłasności, współużytkowania wieczystego, małżeńskiej wspólności ustawowej – uczestnikami postępowania są wszystkie strony. '
          'Zgodnie z art. 39 ust.3 oraz art. 32 ust. 3 ustawy z dnia 17 maja 1989 r. Prawo geodezyjne i kartograficzne '
          '(t.j. Dz.U. 2021 poz. 1990) nieusprawiedliwione niestawiennictwo stron nie wstrzymuje czynności geodety.',
          style: style,
        ),
      ],
    );
  }

  pw.Widget _buildRodo({
    required String rodoAdministrator,
    required String rodoContact,
    required String kergId,
    required pw.TextStyle paragraph,
    required String senderAddressLine1,
    required String senderAddressLine2,
  }) {
    final address = [
      if (senderAddressLine1.isNotEmpty) senderAddressLine1,
      if (senderAddressLine2.isNotEmpty) senderAddressLine2,
    ].join(', ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Klauzula informacyjna dotycząca przetwarzania danych osobowych',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('1. Administratorem danych jest $rodoAdministrator ($address).', style: paragraph),
        pw.Text('2. Kontakt z inspektorem ochrony danych: $rodoContact.', style: paragraph),
        pw.Text('3. Dane przetwarzane są na podstawie art. 6 ust.1 RODO w celu realizacji prac geodezyjnych KERG $kergId.', style: paragraph),
        pw.Text(
          '4. Odbiorcami danych mogą być organy publiczne, jednostki lub inne podmioty uprawnione do ich pozyskania na podstawie przepisów prawa.',
          style: paragraph,
        ),
        pw.Text('5. Dane przechowywane będą przez okres wymagany przepisami prawa.', style: paragraph),
        pw.Text(
          '6. Osobie, której dane dotyczą, przysługuje prawo dostępu, sprostowania, usunięcia, ograniczenia przetwarzania, przenoszenia danych, sprzeciwu oraz cofnięcia zgody.',
          style: paragraph,
        ),
        pw.Text('7. Przysługuje prawo wniesienia skargi do Prezesa UODO.', style: paragraph),
        pw.Text(
          '8. Podanie danych jest obowiązkowe w zakresie wynikającym z przepisów prawa; w pozostałym zakresie dobrowolne, lecz niezbędne do realizacji celu.',
          style: paragraph,
        ),
        pw.Text('9. Dane nie będą podlegały profilowaniu ani zautomatyzowanemu podejmowaniu decyzji.', style: paragraph),
      ],
    );
  }

  String _notificationTitle(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('wznowienie')) return 'wznowieniu znaków granicznych';
    if (lower.contains('ustalenie')) return 'ustaleniu przebiegu granic';
    if (lower.contains('rozgraniczenie')) return 'rozgraniczeniu nieruchomości';
    return type;
  }
}

class _RecipientPage {
  _RecipientPage({
    required this.parcel,
    required this.ownerName,
    required this.address,
    required this.obreb,
    required this.gmina,
    required this.powiat,
    required this.wojewodztwo,
  });

  final Parcel parcel;
  final String ownerName;
  final Address? address;
  final String obreb;
  final String gmina;
  final String powiat;
  final String wojewodztwo;
}
