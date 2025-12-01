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

  Future<void> generateRenewalNotification({
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
    final pdf = await _buildRenewalPdf(
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

  Future<void> generateDemarcationNotification({
    required List<Parcel> parcels,
    required String caseNumber,
    required DateTime creationDate,
    required DateTime meetingDate,
    required String surveyorTitle,
    required String surveyorName,
    required String surveyorLicense,
    required String placeOfCreation,
    required String meetingPlace,
    required String companyName,
    required String companyAddressLine1,
    required String companyAddressLine2,
    required String companyPhone,
    required String companyEmail,
    required String companyRodo,
    required DateTime decisionDate,
    required String decisionNumber,
    required String authority,
    required String authorityName,
    required String inspectorEmail,
    required String inspectorPhone,
    String? powiatManual,
    String? recipientName,
    String? recipientAddressLine1,
    String? recipientAddressLine2,
  }) async {
    final pdf = await _buildDemarcationPdf(
      parcels: parcels,
      caseNumber: caseNumber,
      creationDate: creationDate,
      meetingDate: meetingDate,
      surveyorTitle: surveyorTitle,
      surveyorName: surveyorName,
      surveyorLicense: surveyorLicense,
      placeOfCreation: placeOfCreation,
      meetingPlace: meetingPlace,
      companyName: companyName,
      companyAddressLine1: companyAddressLine1,
      companyAddressLine2: companyAddressLine2,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyRodo: companyRodo,
      decisionDate: decisionDate,
      decisionNumber: decisionNumber,
      authority: authority,
      authorityName: authorityName,
      inspectorEmail: inspectorEmail,
      inspectorPhone: inspectorPhone,
      powiatManual: powiatManual,
      recipientName: recipientName ?? '',
      recipientAddressLine1: recipientAddressLine1 ?? '',
      recipientAddressLine2: recipientAddressLine2 ?? '',
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  Future<Uint8List> _buildDemarcationPdf({
    required List<Parcel> parcels,
    required String caseNumber,
    required DateTime creationDate,
    required DateTime meetingDate,
    required String surveyorTitle,
    required String surveyorName,
    required String surveyorLicense,
    required String placeOfCreation,
    required String meetingPlace,
    required String companyName,
    required String companyAddressLine1,
    required String companyAddressLine2,
    required String companyPhone,
    required String companyEmail,
    required String companyRodo,
    required DateTime decisionDate,
    required String decisionNumber,
    required String authority,
    required String authorityName,
    required String inspectorEmail,
    required String inspectorPhone,
    required String recipientName,
    required String recipientAddressLine1,
    required String recipientAddressLine2,
    String? powiatManual,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSerifRegular();
    final fontBold = await PdfGoogleFonts.notoSerifBold();
    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

    final List<_RecipientPage> recipients = [];
    if (parcels.isEmpty) return doc.save();
    
    final subjectParcel = parcels.first;
    final neighborParcels = parcels.length > 1 ? parcels.sublist(1) : <Parcel>[];

    void addRecipientsForParcel(Parcel parcel, {bool isSubject = false}) {
       final owners = gmlService.getSubjectsForParcel(parcel);
       if(owners.isEmpty && isSubject) {
          recipients.add(_RecipientPage(
            parcel: parcel,
            ownerName: recipientName,
            address: _addressFromForm(recipientAddressLine1, recipientAddressLine2),
            subjectParcelForText: isSubject ? null : subjectParcel,
          ));
          return;
       }

       for (final entry in owners) {
         final subject = entry.value;
         if (subject == null) continue;
         final addresses = gmlService.getAddressesForSubject(subject);
         if (addresses.isEmpty) {
           recipients.add(_RecipientPage(
             parcel: parcel,
             ownerName: subject.name,
             address: isSubject ? _addressFromForm(recipientAddressLine1, recipientAddressLine2) : null,
             subjectParcelForText: isSubject ? null : subjectParcel,
           ));
         } else {
           for (final addr in addresses) {
             recipients.add(_RecipientPage(
               parcel: parcel,
               ownerName: subject.name,
               address: addr,
               subjectParcelForText: isSubject ? null : subjectParcel,
             ));
           }
         }
       }
    }

    addRecipientsForParcel(subjectParcel, isSubject: true);
    for (final p in neighborParcels) {
      addRecipientsForParcel(p);
    }
    
    for (final rec in recipients) {
      // Page 1
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildDemarcationHeader(
              companyName: companyName,
              companyAddressLine1: companyAddressLine1,
            companyAddressLine2: companyAddressLine2,
            companyPhone: companyPhone,
            companyEmail: companyEmail,
            recipientName: rec.ownerName,
            recipientAddressLine1: _line1(rec.address),
            recipientAddressLine2: _line2(rec.address),
            place: placeOfCreation,
            date: creationDate,
            caseNumber: caseNumber,
          ),
            _buildDemarcationTitle(),
            _buildDemarcationBody(
              decisionDate: decisionDate,
              decisionNumber: decisionNumber,
              authority: authority,
              authorityName: authorityName,
              recipientName: rec.ownerName,
              meetingDate: meetingDate,
              meetingTime: meetingDate,
              meetingPlace: meetingPlace,
              parcel: rec.parcel,
              neighboringParcels: rec.isNeighbor
                  ? [rec.parcel.idDzialki]
                  : neighborParcels.map((e) => e.idDzialki).toList(),
              gmlService: gmlService,
              powiatManual: powiatManual,
            ),
            _buildDemarcationSignature(
                surveyorTitle, surveyorName, surveyorLicense),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1),
            _buildDemarcationPouczenie(),
          ],
        ),
      );

      // Page 2 - RODO
      doc.addPage(pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
                _buildDemarcationRodo(
                  companyRodo: companyRodo,
                  inspectorEmail: inspectorEmail,
                  inspectorPhone: inspectorPhone,
                  kergId: caseNumber,
                )
              ]));
    }

    return doc.save();
  }

  pw.Widget _buildDemarcationHeader({
    required String companyName,
    required String companyAddressLine1,
    required String companyAddressLine2,
    required String companyPhone,
    required String companyEmail,
    required String recipientName,
    required String recipientAddressLine1,
    required String recipientAddressLine2,
    required String place,
    required DateTime date,
    required String caseNumber,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('$place, dnia $dateStr'),
                pw.Text('Znak sprawy: $caseNumber'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 210,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text(companyAddressLine1),
                  pw.Text(companyAddressLine2),
                  pw.SizedBox(height: 8),
                  pw.Text('tel. $companyPhone', style: pw.TextStyle(fontSize: 11)),
                  pw.Text('email $companyEmail', style: pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(
              width: 210,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(recipientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(recipientAddressLine1),
                  pw.Text(recipientAddressLine2),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDemarcationTitle() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'WEZWANIE',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'do stawienia się w celu ustalenia granic',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
        ],
      ),
    );
  }
  pw.Widget _buildDemarcationBody({
    required DateTime decisionDate,
    required String decisionNumber,
    required String authority,
    required String authorityName,
    required String recipientName,
    required DateTime meetingDate,
    required DateTime meetingTime,
    required String meetingPlace,
    required Parcel parcel,
    required List<String> neighboringParcels,
    required GmlService gmlService,
    String? powiatManual,
  }) {
    final terytCode = parcel.idDzialki.split('.').first.replaceAll('_', '');
    final wojewodztwoCode = terytCode.substring(0, 2);
    final powiatCode = terytCode.substring(0, 4);

    final obreb = parcel.obrebNazwa ?? '-';
    final gmina = parcel.jednostkaNazwa ?? '-';
    final powiat = powiatManual?.isNotEmpty == true ? powiatManual! : (powiaty[powiatCode] ?? '-');
    final wojewodztwo = wojewodztwa[wojewodztwoCode] ?? '-';
    final neighboringIds = neighboringParcels.map((e) => e.split('.').last).join(', ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            children: [
              pw.TextSpan(text: 'Działając na podstawie postanowienia z dnia ${DateFormat('yyyy-MM-dd').format(decisionDate)} r. nr $decisionNumber wydanego przez $authority $authorityName oraz upoważnienia wydanego przez wymieniony organ, wzywam Panią/Pana '),
              pw.TextSpan(text: recipientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: ' do stawienia się w dniu ${DateFormat('yyyy-MM-dd').format(meetingDate)} r. o godz. ${DateFormat('HH:mm').format(meetingTime)} w $meetingPlace, w charakterze strony, w sprawie ustalenia przebiegu granic nieruchomości oznaczonej w ewidencji gruntów i budynków jako część działki nr ${parcel.numerDzialki.split('.').last}, położonej w obrębie $obreb, gmina $gmina, powiat $powiat, województwo $wojewodztwo, graniczącą z działkami: $neighboringIds.'),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            children: [
              pw.TextSpan(text: 'Postępowanie rozgraniczeniowe zostało wszczęte postanowieniem $authority $authorityName nr $decisionNumber z dnia ${DateFormat('yyyy-MM-dd').format(decisionDate)} r.'),
            ],
          ),
        ),
      ],
    );
  }
  pw.Widget _buildDemarcationSignature(String title, String name, String license) {
    final displayName = (title.trim().isNotEmpty ? '$title ' : '') + name;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(displayName.trim(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Nr upr. Zawod. $license'),
          pw.SizedBox(height: 24),
          pw.Text('.................................................', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('(podpis)', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
  pw.Widget _buildDemarcationPouczenie() {
    final style = const pw.TextStyle(fontSize: 11);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text('POUCZENIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13))),
        pw.SizedBox(height: 8),
        pw.Text(
          'Wezwani właściciele (władający) gruntami proszeni są o przybycie w oznaczonym terminie z wszelkimi dokumentami, jakie mogą być potrzebne przy ustaleniu granic ich gruntów oraz dokumentami tożsamości.',
          textAlign: pw.TextAlign.justify,
          style: style,
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'W imieniu osób nieobecnych mogą występować odpowiednio upoważnieni pełnomocnicy. W przypadku współwłasności, współużytkowania wieczystego, małżeńskiej wspólności ustawowej – uczestnikami postępowania są wszystkie strony.',
          textAlign: pw.TextAlign.justify,
          style: style,
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Zgodnie z art. 39 ust. 3 oraz art. 32 ust. 3 ustawy z dnia 17 maja 1989 r. Prawo geodezyjne i kartograficzne (t.j. Dz.U. 2021 poz. 1990) nieusprawiedliwione niestawiennictwo stron nie wstrzymuje czynności geodety.',
          textAlign: pw.TextAlign.justify,
          style: style,
        ),
      ],
    );
  }
  pw.Widget _buildDemarcationRodo({
    required String companyRodo,
    required String inspectorEmail,
    required String inspectorPhone,
    required String kergId,
  }) {
    final style = const pw.TextStyle(fontSize: 11, lineSpacing: 2);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('Klauzula informacyjna dotycząca przetwarzania danych osobowych',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 10),
        pw.Text(
          'Zgodnie z art. 13 ust. 1 i 2 Rozporządzenia Parlamentu Europejskiego i Rady (UE) 2016/679 z dnia 27 kwietnia 2016 r. w sprawie ochrony osób fizycznych w związku z przetwarzaniem danych osobowych i w sprawie uchylenia dyrektywy 95/46/WE (RODO) informuję, że:',
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 10),
        pw.ListView(
          spacing: 5,
          children: [
            pw.Text('1. Administratorem Pani/Pana danych osobowych jest $companyRodo.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('2. Kontakt z inspektorem ochrony danych osobowych: e-mail: $inspectorEmail, tel. $inspectorPhone.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('3. Pani/Pana dane osobowe będą przetwarzane na podstawie art. 6 ust. 1 RODO. Celem przetwarzania danych jest praca geodezyjna zarejestrowana w Wydziale Geodezji i Kartografii pod nr ID $kergId.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('4. Odbiorcą Pani/Pana danych mogą być organy publiczne, jednostki lub inne podmioty, którym ujawnia się dane osobowe.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('5. Dane udostępnione przez Panią/Pana nie będą podlegały udostępnieniu podmiotom trzecim. Odbiorcami danych będą tylko instytucje upoważnione z mocy prawa.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('6. Pani/Pana dane osobowe będą przechowywane przez czas określony zgodnie z przepisami prawa.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('7. Ma Pani/Pan prawo dostępu do treści swoich danych, prawo do ich sprostowania, a w przypadku pozyskiwania danych na podstawie zgody – prawo żądania ich usunięcia, prawo ograniczenia przetwarzania, prawo wniesienia sprzeciwu, a także prawo cofnięcia zgody na ich przetwarzanie.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('8. Przysługuje Pani/Panu również prawo wniesienia skargi do organu nadzorczego, jeżeli uzna Pani/Pan, że przetwarzanie danych odbywa się z naruszeniem przepisów RODO.', textAlign: pw.TextAlign.justify, style: style),
            pw.Text('9. Pani/Pana dane nie będą profilowane ani przetwarzane w sposób zautomatyzowany.', textAlign: pw.TextAlign.justify, style: style),
          ],
        ),
      ],
    );
  }
  Future<Uint8List> _buildRenewalPdf({
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
    final fontRegular = await PdfGoogleFonts.notoSerifRegular();
    final fontBold = await PdfGoogleFonts.notoSerifBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final List<_RecipientPage> recipients = [];
    if (parcels.isEmpty) return doc.save();

    final subjectParcel = parcels.first;
    final neighborParcels = parcels.length > 1 ? parcels.sublist(1) : <Parcel>[];

    // --- Funkcja pomocnicza do tworzenia odbiorców ---
    void addRecipientsForParcel(Parcel parcel, {Parcel? subjectForNeighbor}) {
      final terytCode = parcel.idDzialki.split('.').first.replaceAll('_', '');
      final wojewodztwoCode = terytCode.substring(0, 2);
      final powiatCode = terytCode.substring(0, 4);
      final obreb = parcel.obrebNazwa ?? '-';
      final gmina = parcel.jednostkaNazwa ?? '-';
      final powiat = powiatManual?.isNotEmpty == true ? powiatManual! : (powiaty[powiatCode] ?? '-');
      final wojewodztwo = wojewodztwa[wojewodztwoCode] ?? '-';

      final owners = gmlService.getSubjectsForParcel(parcel);
      if (owners.isEmpty && subjectForNeighbor == null) {
        recipients.add(_RecipientPage(
          parcel: parcel,
          ownerName: recipientName,
          address: _addressFromForm(recipientAddressLine1, recipientAddressLine2),
          obreb: obreb, gmina: gmina, powiat: powiat, wojewodztwo: wojewodztwo,
        ));
        return;
      }

      for (final entry in owners) {
        final subject = entry.value;
        if (subject == null) continue;
        final addresses = gmlService.getAddressesForSubject(subject);
        if (addresses.isEmpty) {
          recipients.add(_RecipientPage(
            parcel: parcel,
            ownerName: subject.name,
            address: subjectForNeighbor == null ? _addressFromForm(recipientAddressLine1, recipientAddressLine2) : null,
            obreb: obreb, gmina: gmina, powiat: powiat, wojewodztwo: wojewodztwo,
            subjectParcelForText: subjectForNeighbor,
          ));
        } else {
          for (final addr in addresses) {
            recipients.add(_RecipientPage(
              parcel: parcel,
              ownerName: subject.name,
              address: addr,
              obreb: obreb, gmina: gmina, powiat: powiat, wojewodztwo: wojewodztwo,
              subjectParcelForText: subjectForNeighbor,
            ));
          }
        }
      }
    }
    
    // --- Generowanie odbiorców ---
    addRecipientsForParcel(subjectParcel); // Dla działki przedmiotowej
    for (final p in neighborParcels) {
      addRecipientsForParcel(p, subjectForNeighbor: subjectParcel); // Dla działek sąsiednich
    }
    
    final meetingDateStr = DateFormat('yyyy-MM-dd').format(date);
    final meetingTimeStr = DateFormat('HH:mm').format(date);

    for (final rec in recipients) {
      final pw.RichText mainNotificationText;
      final notificationTypeLower = notificationType.toLowerCase();

      if (notificationTypeLower.contains('ustalenie')) {
        mainNotificationText = pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            children: [
              const pw.TextSpan(
                  text:
                      'Działając na podstawie § 32 ust. 1 rozporządzenia Ministra Rozwoju, Pracy i Technologii z dnia 27 lipca 2021 r. w sprawie ewidencji gruntów i budynków (Dz. U. z 2021 r. poz. 1390 ze zm.), zawiadamiam, że w dniu '),
              pw.TextSpan(
                  text: meetingDateStr,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ' o godzinie '),
              pw.TextSpan(
                  text: meetingTimeStr,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(
                  text:
                      ', na gruncie w miejscowości ${rec.gmina} (obręb: ${rec.obreb}), zostaną przeprowadzone czynności ustalenia przebiegu granic działek ewidencyjnych oznaczonych numerami: '),
              pw.TextSpan(
                  text: subjectParcel.numerDzialki.split('.').last,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ' z działkami sąsiednimi o numerach: '),
              pw.TextSpan(
                  text: neighborParcels
                      .map((p) => p.numerDzialki.split('.').last)
                      .join(', '),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      } else {
        // Wznowienie
        mainNotificationText = pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            children: [
              const pw.TextSpan(
                  text:
                      'Na podstawie art. 39 ust. 3 ustawy z dnia 17 maja 1989 r. Prawo geodezyjne i kartograficzne (t.j. Dz. U. z 2021 r. poz. 1990) uprzejmie zawiadamiam, że w dniu '),
              pw.TextSpan(
                  text: meetingDateStr,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ' o godzinie '),
              pw.TextSpan(
                  text: meetingTimeStr,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(
                  text:
                      ' zostaną przeprowadzone czynności $notificationType dotyczące granic nieruchomości oznaczonej w ewidencji gruntów jako działka '),
              pw.TextSpan(
                  text: (rec.isNeighbor
                          ? rec.subjectParcelForText!.numerDzialki
                          : rec.parcel.numerDzialki)
                      .split('.')
                      .last,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ', położonej w obrębie '),
              pw.TextSpan(
                  text: rec.obreb,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ', gmina '),
              pw.TextSpan(
                  text: rec.gmina,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ', powiat '),
              pw.TextSpan(
                  text: rec.powiat,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              const pw.TextSpan(text: ', województwo '),
              pw.TextSpan(
                  text: rec.wojewodztwo,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (rec.isNeighbor) ...[
                const pw.TextSpan(text: ', sąsiadująca z działką '),
                pw.TextSpan(
                    text: rec.parcel.numerDzialki.split('.').last,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
              const pw.TextSpan(text: '.'),
            ],
          ),
        );
      }

      // --- Strona 1 ---
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildHeaderAndRecipient(
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
            mainNotificationText,
            pw.SizedBox(height: 10),
            pw.Text('Miejsce spotkania: $meetingPlace', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 10),
            pw.Text(
              'Czynności prowadzone będą w obecności zainteresowanych stron. Prosimy o zabranie dokumentów tożsamości oraz – w przypadku reprezentacji – stosownych pełnomocnictw.',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 18),
            _buildSignature(surveyorName, surveyorLicense, kergId),
            pw.SizedBox(height: 20),
            _buildPouczenie(const pw.TextStyle(fontSize: 11)),
          ],
        ),
      );

      // --- Strona 2 - RODO ---
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildRodo(
              rodoAdministrator: rodoAdministrator, rodoContact: rodoContact, kergId: kergId,
              paragraph: const pw.TextStyle(fontSize: 11),
              senderAddressLine1: senderAddressLine1, senderAddressLine2: senderAddressLine2,
            ),
          ],
        ),
      );
    }

    return doc.save();
  }

  Address _addressFromForm(String line1, String line2) {
    String? ulica, numer, kod, miejscowosc;
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
    return Address(gmlId: 'manual', ulica: ulica, numerPorzadkowy: numer, kodPocztowy: kod, miejscowosc: miejscowosc);
  }

  String _line1(Address? address) {
    if (address == null) return '';
    return [address.ulica, address.numerPorzadkowy].where((e) => e?.trim().isNotEmpty == true).join(' ');
  }

  String _line2(Address? address) {
    if (address == null) return '';
    return [address.kodPocztowy, address.miejscowosc].where((e) => e?.trim().isNotEmpty == true).join(' ');
  }

  pw.Widget _buildHeaderAndRecipient({
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
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('$place, dnia $dateStr'),
                pw.Text('ID: $kergId'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(senderCompany,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(senderName),
                if (senderAddressLine1.isNotEmpty)
                  pw.Text(senderAddressLine1),
                if (senderAddressLine2.isNotEmpty)
                  pw.Text(senderAddressLine2),
                if (senderPhone.isNotEmpty) pw.Text(senderPhone),
                pw.Text('(nadawca)',
                    style:
                        const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(width: 20),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (recipientName.isNotEmpty ||
                    recipientAddressLine1.isNotEmpty ||
                    recipientAddressLine2.isNotEmpty) ...[
                  pw.Text(recipientName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if (recipientAddressLine1.isNotEmpty)
                    pw.Text(recipientAddressLine1),
                  if (recipientAddressLine2.isNotEmpty)
                    pw.Text(recipientAddressLine2),
                  pw.SizedBox(height: 4),
                  pw.Text('(adresat)',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700)),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTitle(String title) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text('ZAWIADOMIENIE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('o $title', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
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
          ],
        )
      ],
    );
  }

  pw.Widget _buildPouczenie(pw.TextStyle style) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text('POUCZENIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Text(
          'Zawiadomieni właściciele (władający) gruntami proszeni są o przybycie w oznaczonym terminie ze wszelkimi dokumentami, jakie mogą być potrzebne przy przyjmowaniu granic ich gruntów oraz dokumentami tożsamości. W imieniu osób nieobecnych mogą występować odpowiednio upoważnieni pełnomocnicy. W przypadku współwłasności, współużytkowania wieczystego, małżeńskiej wspólności ustawowej – uczestnikami postępowania są wszystkie strony. Zgodnie z art. 39 ust.3 oraz art. 32 ust. 3 ustawy z dnia 17 maja 1989 r. Prawo geodezyjne i kartograficzne (t.j. Dz.U. 2021 poz. 1990) nieusprawiedliwione niestawiennictwo stron nie wstrzymuje czynności geodety.',
          style: style,
          textAlign: pw.TextAlign.justify,
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
    final address = [if (senderAddressLine1.isNotEmpty) senderAddressLine1, if (senderAddressLine2.isNotEmpty) senderAddressLine2].join(', ');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Klauzula informacyjna dotycząca przetwarzania danych osobowych', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('1. Administratorem danych jest $rodoAdministrator ($address).', style: paragraph),
        pw.Text('2. Kontakt z inspektorem ochrony danych: $rodoContact.', style: paragraph),
        pw.Text('3. Dane przetwarzane są na podstawie art. 6 ust.1 RODO w celu realizacji prac geodezyjnych KERG $kergId.', style: paragraph),
        pw.Text('4. Odbiorcami danych mogą być organy publiczne, jednostki lub inne podmioty uprawnione do ich pozyskania na podstawie przepisów prawa.', style: paragraph),
        pw.Text('5. Dane przechowywane będą przez okres wymagany przepisami prawa.', style: paragraph),
        pw.Text('6. Osobie, której dane dotyczą, przysługuje prawo dostępu, sprostowania, usunięcia, ograniczenia przetwarzania, przenoszenia danych, sprzeciwu oraz cofnięcia zgody.', style: paragraph),
        pw.Text('7. Przysługuje prawo wniesienia skargi do Prezesa UODO.', style: paragraph),
        pw.Text('8. Podanie danych jest obowiązkowe w zakresie wynikającym z przepisów prawa; w pozostałym zakresie dobrowolne, lecz niezbędne do realizacji celu.', style: paragraph),
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

  Future<void> generateDeterminationProtocol({
    required List<Parcel> parcels,
    required String kergId,
    required DateTime date,
    required String place,
    required String surveyorName,
    required String surveyorLicense,
    required String companyName,
  }) async {
    final pdf = await _buildDeterminationProtocolPdf(
      parcels: parcels,
      kergId: kergId,
      date: date,
      place: place,
      surveyorName: surveyorName,
      surveyorLicense: surveyorLicense,
      companyName: companyName,
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  Future<Uint8List> _buildDeterminationProtocolPdf({
    required List<Parcel> parcels,
    required String kergId,
    required DateTime date,
    required String place,
    required String surveyorName,
    required String surveyorLicense,
    required String companyName,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSerifRegular();
    final fontBold = await PdfGoogleFonts.notoSerifBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    if (parcels.isEmpty) return doc.save();

    final subjectParcel = parcels.first;

    final participants = gmlService.getSubjectsForParcels(parcels);
    final points = gmlService.getPointsForParcel(subjectParcel);

    doc.addPage(pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            pw.Text('PROTOKÓŁ USTALENIA PRZEBIEGU GRANIC',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center),
            pw.Text('Działek ewidencyjnych',
                style: const pw.TextStyle(fontSize: 12),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 20),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Identyfikator zgłoszenia prac: $kergId'),
                  pw.Text(
                      'Data sporządzenia: ${DateFormat('yyyy-MM-dd').format(date)}'),
                ]),
            pw.SizedBox(height: 10),
            pw.Text('Miejscowość: $place'),
            pw.SizedBox(height: 20),

            // Section 1
            pw.Text('1. Oznaczenie nieruchomości',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
                'Jednostka ewidencyjna: ${subjectParcel.jednostkaId} - ${subjectParcel.jednostkaNazwa}'),
            pw.Text(
                'Obręb: ${subjectParcel.obrebId} - ${subjectParcel.obrebNazwa}'),
            pw.SizedBox(height: 5),
            pw.Text('Działki podlegające ustaleniu (przedmiotowe):'),
            pw.Text(parcels.map((p) => p.numerDzialki).join(', '),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),

            // Section 2
            pw.Text('2. Wykonawca prac geodezyjnych',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('Nazwa podmiotu: $companyName'),
            pw.Text(
                'Geodeta uprawniony: $surveyorName, nr upr. $surveyorLicense'),
            pw.SizedBox(height: 20),

            // Section 3
            pw.Text('3. Uczestnicy czynności (Strony)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: [
                'Lp.',
                'Imię i Nazwisko / Nazwa',
                'Właściciel dz. nr',
                'Rodzaj i nr dok. tożsamości',
                'Podpis'
              ],
              data: List.generate(
                  participants.length,
                  (index) => [
                        (index + 1).toString(),
                        participants[index].value?.name ?? '',
                        gmlService
                            .getParcelsForSubject(participants[index].value!)
                            .map((p) => p.numerDzialki.split('.').last)
                            .join(', '),
                        '',
                        ''
                      ]),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 10),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1),
              },
            ),
            pw.SizedBox(height: 20),

            // Section 4
            pw.Text('4. Opis przebiegu granic i sposób ich utrwalenia',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('Granice ustalono na podstawie:'),
            pw.Text('[ ] Zgodnego oświadczenia stron (§ 32 ust. 2 pkt 1 EGiB)'),
            pw.Text('[ ] Ostatniego spokojnego stanu posiadania (§ 32 ust. 2 pkt 2 EGiB)'),
            pw.Text('[ ] Analizy materiałów zasobu i wyników pomiaru (§ 32 ust. 3 EGiB)'),
            pw.SizedBox(height: 10),
            pw.Text('Szczegółowy opis punktów granicznych:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: [
                'Nr pkt',
                'Oznaczenie w terenie',
                'Źródło danych',
                'Opis położenia / Uwagi'
              ],
              data: List.generate(
                  points.length,
                  (index) => [
                        points[index].displayNumer,
                        points[index].stb ?? '',
                        '',
                        ''
                      ]),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
            ),
            pw.SizedBox(height: 20),

            // Section 5
            pw.Text('5. Oświadczenia stron',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
                'Strony obecne przy czynnościach oświadczają, że okazane granice są im znane i nie wnoszą do nich zastrzeżeń (chyba że wpisano inaczej poniżej).'),
            pw.Text(
                'Wyrażają zgodę na stabilizację punktów w sposób opisany w pkt 4.'),
            pw.SizedBox(height: 10),
            pw.Text('Uwagi i zastrzeżenia stron:'),
            pw.Container(
                height: 80,
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all())),
            pw.SizedBox(height: 20),

            // Section 6
            pw.Text('6. Szkic graniczny',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Container(
                height: 200,
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Center(child: pw.Text('Miejsce na szkic'))),
            pw.SizedBox(height: 40),

            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(children: [
                    pw.Text('..................................................'),
                    pw.Text('(Podpis Geodety)',
                        style: const pw.TextStyle(fontSize: 10))
                  ])
                ])
          ];
        }));

    return doc.save();
  }

  Future<void> generateRenewalProtocol({
    required List<Parcel> parcels,
    required String kergId,
    required DateTime date,
    required String docSource,
    required String surveyorName,
    required String surveyorLicense,
  }) async {
    final pdf = await _buildRenewalProtocolPdf(
      parcels: parcels,
      kergId: kergId,
      date: date,
      docSource: docSource,
      surveyorName: surveyorName,
      surveyorLicense: surveyorLicense,
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  Future<Uint8List> _buildRenewalProtocolPdf({
    required List<Parcel> parcels,
    required String kergId,
    required DateTime date,
    required String docSource,
    required String surveyorName,
    required String surveyorLicense,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSerifRegular();
    final fontBold = await PdfGoogleFonts.notoSerifBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    if (parcels.isEmpty) return doc.save();

    final subjectParcel = parcels.first;
    final neighborParcels = parcels.sublist(1);
    final participants = gmlService.getSubjectsForParcels(parcels);
    final points = gmlService.getPointsForParcel(subjectParcel);

    doc.addPage(pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            pw.Text(
                'PROTOKÓŁ WZNOWIENIA ZNAKÓW GRANICZNYCH / WYZNACZENIA PUNKTÓW GRANICZNYCH',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 20),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Identyfikator zgłoszenia: $kergId'),
                  pw.Text('Data: ${DateFormat('yyyy-MM-dd').format(date)}'),
                ]),
            pw.SizedBox(height: 20),

            // Section 1
            pw.Text('1. Podstawa czynności',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
                'Czynności wykonano na podstawie art. 39 ustawy Prawo geodezyjne i kartograficzne.'),
            pw.Text(
                'Dokumenty źródłowe stanowiące podstawę wznowienia/wyznaczenia:'),
            pw.Text('- $docSource'),
            pw.SizedBox(height: 20),

            // Section 2
            pw.Text('2. Oznaczenie granic',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
                'Wznowieniu/wyznaczeniu podlegają punkty graniczne pomiędzy działkami:'),
            pw.Row(children: [
              pw.Text('${subjectParcel.numerDzialki} a działkami ${neighborParcels.map((p) => p.numerDzialki).join(', ')}'),
            ]),
            pw.SizedBox(height: 20),

            // Section 3
            pw.Text('3. Wyniki czynności',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Wznowiono/wyznaczono następujące punkty:'),
            pw.Table.fromTextArray(
              headers: [
                'Nr punktu',
                'Rodzaj stabilizacji',
                'Czy znak odnaleziono?',
                'Czy znak wznowiono?'
              ],
              data: List.generate(
                  points.length,
                  (index) => [
                        points[index].displayNumer,
                        points[index].stb ?? '',
                        'TAK / NIE',
                        'TAK / NIE'
                      ]),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
            ),
            pw.SizedBox(height: 20),

            // Section 4
            pw.Text('4. Oświadczenia uczestników',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
                'Uczestnicy zostali poinformowani, że wznowienie/wyznaczenie nastąpiło na podstawie istniejącej dokumentacji geodezyjnej przyjętej do Państwowego Zasobu.'),
            pw.SizedBox(height: 10),
            pw.Text('Czy są spory co do położenia znaków? TAK / NIE'),
            pw.SizedBox(height: 5),
            pw.Text('Jeśli TAK, opis sporu:'),
            pw.Container(
                height: 60,
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all())),
            pw.SizedBox(height: 20),

            // Section 5
            pw.Text('5. Podpisy uczestników',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: ['Imię i Nazwisko', 'Właściciel działki nr', 'Podpis'],
              data: List.generate(
                  participants.length,
                  (index) => [
                        participants[index].value?.name ?? '',
                        gmlService
                            .getParcelsForSubject(participants[index].value!)
                            .map((p) => p.numerDzialki.split('.').last)
                            .join(', '),
                        ''
                      ]),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 40),

            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Column(children: [
                pw.Text('..................................................'),
                pw.Text('(Podpis Geodety Uprawnionego)',
                    style: const pw.TextStyle(fontSize: 10))
              ])
            ])
          ];
        }));
    return doc.save();
  }

  Future<void> generateDemarcationProtocol({
    required List<Parcel> parcels,
    required String caseNumber,
    required DateTime date,
    required String place,
    required String surveyorName,
    required String surveyorLicense,
    required String companyName,
    required String authorityName,
    required String decisionNumber,
    required DateTime decisionDate,
  }) async {
    final pdf = await _buildDemarcationProtocolPdf(
      parcels: parcels,
      caseNumber: caseNumber,
      date: date,
      place: place,
      surveyorName: surveyorName,
      surveyorLicense: surveyorLicense,
      companyName: companyName,
      authorityName: authorityName,
      decisionNumber: decisionNumber,
      decisionDate: decisionDate,
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  Future<Uint8List> _buildDemarcationProtocolPdf({
    required List<Parcel> parcels,
    required String caseNumber,
    required DateTime date,
    required String place,
    required String surveyorName,
    required String surveyorLicense,
    required String companyName,
    required String authorityName,
    required String decisionNumber,
    required DateTime decisionDate,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSerifRegular();
    final fontBold = await PdfGoogleFonts.notoSerifBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    if (parcels.isEmpty) return doc.save();

    final subjectParcel = parcels.first;
    final neighborParcels = parcels.sublist(1);
    final participants = gmlService.getSubjectsForParcels(parcels);

    doc.addPage(pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            pw.Text('PROTOKÓŁ GRANICZNY',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center),
            pw.Text('Sporządzony w toku postępowania rozgraniczeniowego',
                style: const pw.TextStyle(fontSize: 12),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 20),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Miejscowość: $place'),
                  pw.Text('Data: ${DateFormat('yyyy-MM-dd').format(date)}'),
                ]),
            pw.SizedBox(height: 20),

            // Section 1
            pw.Text('1. Podstawa działania',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
                'Czynności wykonano na podstawie postanowienia o wszczęciu postępowania rozgraniczeniowego wydanego przez:'),
            pw.Text('Organ: $authorityName'),
            pw.Text('Znak sprawy: $caseNumber'),
            pw.Text('Data wydania: ${DateFormat('yyyy-MM-dd').format(decisionDate)}'),
            pw.SizedBox(height: 10),
            pw.Text('Wykonawca (Geodeta upoważniony):'),
            pw.Text('$surveyorName, nr uprawnień: $surveyorLicense'),
            pw.Text('Działający z upoważnienia (nazwa firmy): $companyName'),
            pw.SizedBox(height: 20),

            // Section 2
            pw.Text('2. Przedmiot rozgraniczenia',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            // ... more details here based on UI input
            pw.SizedBox(height: 20),

            // Section 3
            pw.Text('3. Uczestnicy czynności',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Lp.', 'Imię i Nazwisko', 'Status', 'Tożsamość (Nr dowodu)', 'Podpis'],
              data: List.generate(
                  participants.length,
                  (index) => [
                        (index + 1).toString(),
                        participants[index].value?.name ?? '',
                        'Właściciel',
                        '',
                        ''
                      ]),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
            ),
            pw.SizedBox(height: 20),
            
            // Section 4
            pw.Text('4. Analiza danych i okazanie granic', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            // ...
            pw.SizedBox(height: 20),

            // Section 5
            pw.Text('5. Oświadczenia stron', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
             pw.SizedBox(height: 5),
            pw.Text('Strona A oświadcza:'),
            pw.Container(height: 40, width: double.infinity, decoration: pw.BoxDecoration(border: pw.Border.all())),
             pw.SizedBox(height: 5),
            pw.Text('Strona B oświadcza:'),
            pw.Container(height: 40, width: double.infinity, decoration: pw.BoxDecoration(border: pw.Border.all())),
            pw.SizedBox(height: 20),

            // Section 6
            pw.Text('6. Wynik rozgraniczenia (WERDYKT)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('[ ] Ustalono przebieg granicy (Zgoda / Dowody)'),
            pw.Text('[ ] Zawarto ugodę'),
            pw.Text('[ ] Brak zgody (Spór)'),
            pw.SizedBox(height: 20),

            // Section 7
            pw.Text('7. Szkic polowy', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Container(
                height: 200,
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Center(child: pw.Text('Miejsce na szkic'))),
            pw.SizedBox(height: 20),

            pw.Text('Podpisy końcowe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
             pw.SizedBox(height: 40),

            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
             children: [
               pw.Column(children: [
                 pw.Text('.........................'),
                 pw.Text('(Podpis Geodety)', style: const pw.TextStyle(fontSize: 10)),
               ]),
                pw.Column(children: [
                 pw.Text('.........................'),
                 pw.Text('(Podpisy stron)', style: const pw.TextStyle(fontSize: 10)),
               ]),
             ]
            )
          ];
        }));
    return doc.save();
  }

  Future<void> generateAgreementAct({
    required DateTime date,
    required String place,
    required String surveyorName,
    required String caseNumber,
    required String parcelANum,
    required String parcelBNum,
    required String points,
  }) async {
    final pdf = await _buildAgreementActPdf(
      date: date,
      place: place,
      surveyorName: surveyorName,
      caseNumber: caseNumber,
      parcelANum: parcelANum,
      parcelBNum: parcelBNum,
      points: points,
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  Future<Uint8List> _buildAgreementActPdf({
    required DateTime date,
    required String place,
    required String surveyorName,
    required String caseNumber,
    required String parcelANum,
    required String parcelBNum,
    required String points,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSerifRegular();
    final fontBold = await PdfGoogleFonts.notoSerifBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    doc.addPage(pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(60),
        build: (context) {
          return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('AKT UGODY',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 10),
                pw.Text('W sprawie ustalenia przebiegu granic nieruchomości',
                    style: const pw.TextStyle(fontSize: 12),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 30),
                pw.Text(
                    'Sporządzony w dniu ${DateFormat('yyyy-MM-dd').format(date)} w miejscowości $place przed geodetą uprawnionym $surveyorName.'),
                pw.SizedBox(height: 20),
                pw.Text(
                    'W toku postępowania rozgraniczeniowego (znak: $caseNumber), Właściciele nieruchomości sąsiednich (wymienieni w Protokole Granicznym), zgodnie oświadczają, że:'),
                pw.SizedBox(height: 20),
                pw.Text(
                    '1. Wszelkie spory graniczne pomiędzy nimi zostały zażegnane.'),
                pw.SizedBox(height: 10),
                pw.Text(
                    '2. Ustalają granicę pomiędzy działką nr $parcelANum a działką nr $parcelBNum wzdłuż linii łączącej punkty: $points.'),
                pw.SizedBox(height: 10),
                pw.Text(
                    '3. Wyrażają zgodę na tak ustalony przebieg granicy i zrzekają się wszelkich roszczeń w tym zakresie w przyszłości.'),
                pw.SizedBox(height: 20),
                pw.Text(
                    'Szkic z ugodzonym przebiegiem granicy stanowi załącznik do Aktu.'),
                pw.SizedBox(height: 60),
                pw.Text('Podpisy stron zawierających ugodę:'),
                pw.SizedBox(height: 40),
                pw.Text('1. ..............................'),
                pw.SizedBox(height: 40),
                pw.Text('2. ..............................'),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(children: [
                    pw.Text('..............................'),
                    pw.Text('(Podpis geodety)',
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
                )
              ]);
        }));

    return doc.save();
  }
}

class _RecipientPage {
  _RecipientPage({
    required this.parcel,
    required this.ownerName,
    this.address,
    this.obreb,
    this.gmina,
    this.powiat,
    this.wojewodztwo,
    this.subjectParcelForText,
  });

  final Parcel parcel;
  final String ownerName;
  final Address? address;
  final String? obreb;
  final String? gmina;
  final String? powiat;
  final String? wojewodztwo;
  final Parcel? subjectParcelForText;
  
  bool get isNeighbor => subjectParcelForText != null;
}
