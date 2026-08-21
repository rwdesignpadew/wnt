# Checklista odbiorowa mobile

## Wymagane przed każdym wydaniem

- [x] `flutter analyze` kończy się bez ostrzeżeń i błędów.
- [x] Wszystkie testy `flutter test` przechodzą (22/22, 19.08.2026).
- [x] Test nie znajduje WebView ani uszkodzonego UTF-8.
- [ ] APK instaluje się na fizycznym telefonie.
- [ ] Aplikacja uruchamia się po czystej instalacji i po aktualizacji.
- [ ] Logo, nazwa „Woda na telefon” i polskie znaki są poprawne.

## Uwierzytelnianie

- [ ] Logowanie administratora otwiera natywny panel administratora.
- [ ] Logowanie kierowcy pokazuje wyłącznie funkcje kierowcy.
- [ ] Logowanie klienta głównego pokazuje wszystkie jego lokalizacje.
- [ ] Logowanie odbiorcy pokazuje wyłącznie przypisaną lokalizację.
- [ ] Rejestracja odrzuca adres poza obsługiwanym regionem.
- [ ] Odzyskiwanie i zmiana hasła działają bez strony webowej.
- [ ] Wylogowanie usuwa token i wraca do logowania.

## Dokumenty

- [ ] WZ ma numer, datę, wartość i typ.
- [ ] Faktura VAT z Fakturowni jest widoczna na liście klienta i administratora.
- [ ] Podgląd WZ otwiera oryginalny PDF wewnątrz aplikacji.
- [ ] Podgląd Faktury VAT otwiera oryginalny PDF wewnątrz aplikacji.
- [ ] Pobieranie zapisuje plik i wyświetla jego lokalizację.
- [ ] Dokument innego klienta lub lokalizacji zwraca 403/404.
- [ ] HTML i nieprawidłowy PDF są odrzucane czytelnym komunikatem.

## Administrator

- [ ] Pulpit, trasy, klienci, dokumenty i produkty ładują się z API.
- [ ] Szczegóły trasy pokazują lokalizację i adres każdego punktu.
- [ ] Nowa trasa i edycja zapisują cykliczność, kolejność, lokalizacje oraz osobne produkty każdego punktu.
- [ ] Optymalizacja Google zmienia kolejność bez utraty produktów punktów.
- [ ] Usunięcie trasy odpina zamówienia i usuwa tylko planowane dokumenty.
- [ ] Przypisanie zamówienia do trasy tworzy punkt, planowaną WZ i jej pozycje.
- [ ] Faktura VAT z pojedynczej WZ powstaje w Fakturowni tylko jeden raz.
- [ ] Usunięcie WZ usuwa dokument w Fakturowni i odwraca magazyn oraz zwroty.
- [ ] Dodawanie i edycja produktu zapisują dane.
- [ ] Produkt użyty historycznie nie może zostać skasowany.
- [ ] Edycja klienta zachowuje lokalizacje, produkty, ceny i dzierżawy.
- [ ] Nowy klient zapisuje pełny formularz i zostaje powiązany z Fakturownią.
- [ ] GUS uzupełnia dane nabywcy oraz odbiorcy wybranej lokalizacji.

## Kierowca

- [ ] Kolejność punktów odpowiada trasie.
- [ ] Obsłużony punkt zmienia stan wizualny na zielony.
- [ ] „Nie zastano” nie ukrywa kolejnych nieobsłużonych punktów.
- [ ] Załadunek wynika z sumy pozycji zaplanowanych dla klientów.
- [ ] Zwrot transportera ustawia 24 butelki 0,3 l i pozwala zmniejszyć liczbę.
- [ ] Zwrot butli 18,9 l jest oddzielony od butelek 0,3 l.
- [ ] Uszkodzona butla i uszkodzony dystrybutor zapisują właściwe informacje.
- [ ] Podpis i WZ używają czasu Europe/Warsaw.

## Klient

- [ ] Produkty i ceny odpowiadają ustawieniom klienta.
- [ ] Zamówienie trafia do wybranej lokalizacji.
- [ ] Śledzenie pokazuje GPS przypisanego auta, nie telefonu.
- [ ] Dane konta i hasło można zmienić natywnie.
- [ ] Konto odbiorcy nie widzi innych lokalizacji.

## Test równoległy Android/iOS

- [ ] Te same role, etykiety i kolejność kart.
- [ ] Te same kontrakty API i walidacje.
- [ ] Różnice dotyczą tylko natywnych uprawnień, map i sposobu zapisu pliku.
