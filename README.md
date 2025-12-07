# OperatFlow GML Viewer

Desktop/mobile Flutter app for inspecting EGIB GML files with full parcel detail coverage (działki, kontury, punkty, podmioty, budynki, lokale, adresy, podstawy prawne) plus PDF/notification utilities.

## Co robi

- Wczytuje pliki EGIB GML (drag & drop lub wybór pliku) i parsuje **wszystkie** obiekty: działki, kontury użytków/klasoużytków, punkty graniczne, podmioty i udziały (JRG), adresy nieruchomości/podmiotów, budynki, lokale, podstawy prawne. Nieznane pola lądują w `extraAttributes`, żeby nie gubić danych.
- Widok szczegółów działki z zakładkami: Działka, Podmioty/adresy/udziały, Punkty graniczne, Budynki (i lokale), z podglądem geometrii.
- Eksport PDF: tryb pełny (dane parceli + kontury + podmioty + budynki/lokale + podstawy prawne + punkty) lub wypis graficzny (geometria + punkty).
- Generowanie zawiadomień (formularz z danymi nadawcy/odbiorcy) zgodnych z art. 39 Pgik.
- Logowanie przez Supabase, możliwość „zapamiętaj dane logowania”, automatyczne wylogowanie po 8h od logowania; sesja przywracana po restarcie jeśli nie wygasła. Konta pro/lifetime/tester → tylko jedna aktywna sesja (blokada na urządzenie), konta enterprise → wiele urządzeń równocześnie.

## Wymagania

- Flutter SDK 3.9.x+
- Dart 3.9.x+
- Visual Studio z CMake/ninja (dla Windows build) lub odpowiednie toolchainy dla macOS/Linux/Mobile.
- Dostęp do Supabase

## Szybki start

```bash
flutter pub get
# desktop/web/mobile – wybierz device:
flutter run -d windows   # lub macos / linux / chrome / emulator
```

Plik GML możesz wczytać przez przycisk folderu lub przeciągając do okna.

## Testy

```bash
flutter test
```

## Architektura (skrót)

- `lib/repositories/gml_repository.dart` – parser EGIB GML (działki, punkty, kontury, podmioty, adresy, budynki, lokale, podstawy prawne, extraAttributes) podzielony na dedykowane parsery.
- Modele w `lib/data/models/*` odzwierciedlają obiekty EGIB; większość ma `extraAttributes` na nieznane pola.
- UI: `lib/presentation/pages/home_page.dart` (główny ekran), komponenty w `lib/presentation/theme/widgets/*` (podgląd geometrii, panel szczegółów).
- PDF: `lib/services/parcel_report_service.dart` (tryb full/graphic) + `assets/templates/*`.
- Auth: `lib/services/auth_service.dart`, `lib/services/secure_storage_service.dart` (bezpieczne klucze, timestamp logowania, deviceId do blokady wielosesyjnej).

## Jak to działa (w skrócie)

1. Logowanie do Supabase (persistSession + autoRefresh). Po zalogowaniu zapisujemy timestamp; auto logout po 8h.
2. Wczytanie GML -> `GmlRepository.parseGml` -> mapy obiektów + listy działek.
3. UI renderuje listę działek, szczegóły z zakładkami i podglądem geometrii; dane są zaznaczalne (SelectionArea).
4. PDF export/druk korzysta z `ParcelReportService` (dwa tryby).

## Przydatne informacje

- Geometria jest skalowana responsywnie w komponentach podglądu.
- Obręb w UI: nazwa + 4 cyfry po prefiksie identyfikatora działki (bez „221208_2.”).
- ExtraAttributes mogą być ukryte, jeśli wyglądają na śmieci (nadmiar danych).
- „Zapamiętaj dane” zapisuje email/hasło lokalnie (prosta obfuscacja, nie traktować jako silne szyfrowanie).
