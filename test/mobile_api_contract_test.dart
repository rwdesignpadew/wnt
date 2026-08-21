import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend udostępnia oryginalny PDF dla każdej roli', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    for (final role in ['admin', 'driver', 'client']) {
      expect(
        routes,
        contains("/$role/documents/{document}/fakturownia"),
        reason: 'Brak trasy PDF dla roli $role',
      );
    }
  });

  test('metody PDF autoryzują dokument przed pobraniem', () {
    final controllers = {
      'admin':
          '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
      'driver':
          '../../remote_live/app/Http/Controllers/Api/Mobile/MobileDriverController.php',
      'client':
          '../../remote_live/app/Http/Controllers/Api/Mobile/MobileClientController.php',
    };
    for (final entry in controllers.entries) {
      final source = File(entry.value).readAsStringSync();
      expect(source, contains('function fakturowniaDocument'));
      expect(source, contains('fetchWarehouseDocumentPdf'));
      expect(source, contains("'Content-Type'"));
    }
  });

  test('administrator i klient pobierają faktury z Fakturowni natywnie', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    final client = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileClientController.php',
    ).readAsStringSync();
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(
      routes,
      contains('/client/external-documents/{externalDocument}/fakturownia'),
    );
    expect(
      routes,
      contains('/admin/external-documents/{externalDocument}/fakturownia'),
    );
    for (final source in [client, admin]) {
      expect(source, contains('function externalFakturowniaDocument'));
      expect(source, contains('fetchOriginalDocument'));
    }
    expect(client, contains('abort_unless'));
  });

  test('administrator wystawia Fakturę VAT bezpośrednio z pojedynczej WZ', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(routes, contains('/admin/documents/{document}/final-invoice'));
    expect(admin, contains('function createFinalInvoice'));
    expect(admin, contains('createFinalInvoiceForDocuments'));
    expect(admin, contains("\$document->status === 'completed'"));
    expect(admin, contains(r'$document->final_invoice_fakturownia_id'));
    expect(admin, contains(r'$document->final_invoiced_at'));
  });

  test('usunięcie WZ synchronizuje Fakturownię i odwraca magazyn', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(routes, contains("Route::delete('/admin/documents/{document}'"));
    expect(admin, contains('function destroyDocument'));
    expect(admin, contains('deleteWarehouseDocument'));
    expect(admin, contains('reverseInventoryAndRentalReturns'));
    expect(admin, contains(r'$document->final_invoice_fakturownia_id'));
  });

  test('natywny edytor tras zapisuje punkty i osobne produkty atomowo', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(routes, contains("Route::post('/admin/routes'"));
    expect(routes, contains('/admin/routes/optimize'));
    expect(admin, contains('function storeRoute'));
    expect(admin, contains('function updateRoute'));
    expect(admin, contains('function syncMobileRoute'));
    expect(admin, contains("'stops.*.products.*'"));
    expect(admin, contains("\$document->status !== 'planned'"));
    expect(admin, contains(r'DB::transaction'));
  });

  test('przypisanie zamówienia tworzy punkt, WZ i pozycje w transakcji', () {
    final routes = File('../../remote_live/routes/api.php').readAsStringSync();
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(routes, contains('/admin/orders/{order}/route'));
    expect(routes, contains('/admin/orders/{order}/status'));
    expect(admin, contains('function assignOrderRoute'));
    expect(admin, contains("'delivery_document_id' => \$document->id"));
    expect(admin, contains('DeliveryItem::updateOrCreate'));
    expect(admin, contains("'status' => 'planned'"));
  });

  test(
    'edycja klienta zapisuje lokalizacje, produkty, ceny i dzierżawy atomowo',
    () {
      final source = File(
        '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
      ).readAsStringSync();

      expect(source, contains(r'DB::transaction(function () use ($client'));
      expect(
        source,
        contains("'visible_product_ids' => ['nullable', 'array']"),
      );
      expect(source, contains("'rental_items' => ['nullable', 'array']"));
      expect(source, contains(r'$client->visibleProducts()->sync'));
      expect(source, contains(r'$client->rentalItems()->delete'));
      expect(source, isNot(contains('take(80)')));
    },
  );

  test(
    'administrator tworzy klienta i pobiera dane nabywcy lub odbiorcy z GUS',
    () {
      final routes = File(
        '../../remote_live/routes/api.php',
      ).readAsStringSync();
      final admin = File(
        '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
      ).readAsStringSync();

      expect(routes, contains("Route::post('/admin/clients'"));
      expect(routes, contains('/admin/clients/gus'));
      expect(admin, contains('function storeClient'));
      expect(admin, contains('function gusClientData'));
      expect(admin, contains(r'$fakturownia->ensureClient'));
    },
  );

  test('mobilne API zwraca kluczowe komunikaty z polskimi znakami', () {
    final client = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileClientController.php',
    ).readAsStringSync();
    final driver = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileDriverController.php',
    ).readAsStringSync();
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();

    expect(client, contains('Zamówienie zostało wysłane.'));
    expect(driver, contains('WZ nie został wysłany'));
    expect(admin, contains('Nowe zamówienia'));
  });

  test('nie zastano nie zmienia kolejności trasy', () {
    final driver = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileDriverController.php',
    ).readAsStringSync();
    final missed = driver.substring(
      driver.indexOf('public function missed'),
      driver.indexOf('public function emailDocument'),
    );
    expect(missed, contains("'status' => 'missed_closed'"));
    expect(missed, isNot(contains("'sequence' =>")));
  });

  test('lista dokumentów administratora nie zawiera planowanych WZ', () {
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();
    final documents = admin.substring(
      admin.indexOf('public function documents'),
      admin.indexOf('public function createFinalInvoice'),
    );
    expect(documents, contains("whereNotNull('number')"));
    expect(documents, contains("where('number', '!=', '')"));
  });

  test('trasy cykliczne są generowane tylko 14 dni naprzód', () {
    final admin = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileAdminController.php',
    ).readAsStringSync();
    expect(admin, contains('function ensureRecurringRoutes'));
    expect(admin, contains('today()->addDays(14)'));
    expect(admin, contains("\$copy->is_recurring = false"));
  });

  test('reczne WZ nie sa punktami trasy kierowcy', () {
    final driver = File(
      '../../remote_live/app/Http/Controllers/Api/Mobile/MobileDriverController.php',
    ).readAsStringSync();
    final route = driver.substring(
      driver.indexOf('public function route'),
      driver.indexOf('public function complete'),
    );
    expect(route, isNot(contains(r'$documents->concat($manualDocuments)')));
    expect(route, contains("->whereNull('delivery_route_id')"));
    expect(route, contains("->where('status', 'completed')"));
    expect(route, contains("'manual_served_clients'"));
    expect(driver, contains(r'$stopKeys'));
  });
}
