# Woda na telefon - aplikacja mobilna

## Założenia

- Jeden projekt Flutter dla Androida i iOS.
- Trzy role: administrator, kierowca i klient.
- Cały interfejs jest natywny. WebView jest zabroniony testem architektury.
- Backend Laravel udostępnia wyłącznie JSON i pliki binarne przez `/api/mobile/*`.
- Sesja mobilna używa tokenu Bearer przechowywanego w bezpiecznym magazynie systemowym.
- Teksty źródłowe są UTF-8, a typowe ślady uszkodzonego kodowania blokują testy.

## Warstwy

- `lib/src/core`: konfiguracja, klient HTTP, sesja, routing i motyw zgodny z panelem webowym.
- `lib/src/features/auth`: logowanie, rejestracja, odzyskiwanie i zmiana hasła.
- `lib/src/features/admin`: pulpit, trasy, klienci, dokumenty i produkty.
- `lib/src/features/driver`: trasa, obsługa punktu, załadunek i dokumenty WZ.
- `lib/src/features/client`: zamawianie, śledzenie, dokumenty i konto.
- `lib/src/features/documents`: wspólny natywny podgląd PDF.

## Dokumenty

1. Aplikacja pobiera dokument przez autoryzowany endpoint API.
2. Backend sprawdza rolę oraz powiązanie dokumentu z klientem lub lokalizacją.
3. Backend pobiera oryginał z Fakturowni i zwraca go jako PDF.
4. Klient mobilny weryfikuje status, `Content-Type` i sygnaturę `%PDF`.
5. Podgląd działa w `flutter_pdfview`, bez przeglądarki i bez WebView.
6. Plik podglądu jest usuwany po zamknięciu. Ikona pobierania otwiera natywny arkusz Androida/iOS, z którego użytkownik zapisuje kopię lub wysyła dokument.

Obsługiwane źródła:

- lokalne WZ powiązane z rekordem `DeliveryDocument`,
- WZ i Faktury VAT zsynchronizowane jako `FakturowniaExternalDocument`.

## Role i nawigacja

### Administrator

- Pulpit i dane operacyjne.
- Trasy: tworzenie, edycja, cykliczność, lokalizacje punktów, osobne produkty, zmiana kolejności, optymalizacja Google i bezpieczne usuwanie.
- Klienci: pełna lista bez limitu, wyszukiwanie oraz transakcyjna edycja danych, lokalizacji, produktów, cen i dzierżaw.
- Klienci: tworzenie i edycja korzystają z jednego formularza; GUS obsługuje nabywcę i odbiorcę lokalizacji.
- Zamówienia: szczegóły, status i transakcyjne przypisanie do trasy wraz z punktem, planowaną WZ i pozycjami.
- Dokumenty: WZ oraz Faktury VAT z natywnym PDF, Faktura VAT z pojedynczej WZ i synchronizowane usuwanie WZ.
- Produkty: lista, dodawanie, edycja i bezpieczne usuwanie.

### Kierowca

- Bieżąca trasa i wyraźne stany punktów.
- Obsługa klienta, zwroty, podpis i generowanie WZ.
- Oznaczenie „Nie zastano” i widoczność pominiętych punktów.
- Załadunek wynikający z produktów zaplanowanych na trasie.
- Natywny podgląd oryginalnego WZ.

### Klient

- Zamawianie tylko dla aktywnej, obsługiwanej lokalizacji.
- Śledzenie pojazdu przypisanego do trasy.
- WZ i Faktury VAT z podglądem oraz pobieraniem PDF.
- Edycja danych konta i zmiana hasła.

## Zasady rozwoju

- Nie dodawać `webview_flutter`, `InAppWebView` ani ekranów URL.
- Nie zwracać przekierowań HTML z endpointów mobilnych.
- Każda operacja zapisu musi zwracać JSON z `message` i aktualnym zasobem.
- Operacje usuwania wymagają potwierdzenia i nie mogą niszczyć historii dokumentów.
- Wspólna logika biznesowa pozostaje po stronie Laravel; Flutter odpowiada za natywny interfejs.
- Przed wdrożeniem backendu wykonywana jest kopia plików na serwerze.

## Budowanie

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Android używa pakietu `pl.wnt.wodanatelefon`. Ten sam kod Dart jest bazą wydania iOS; różnice platformowe ograniczają się do uprawnień, podpisu i konfiguracji map.
