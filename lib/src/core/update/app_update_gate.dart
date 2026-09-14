import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import '../theme/wnt_colors.dart';

typedef AppUpdateLoader = Future<AppUpdateInfo?> Function();
typedef AppStoreLauncher = Future<bool> Function(Uri uri);

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentBuild,
    required this.latestBuild,
    required this.minimumBuild,
    required this.latestVersion,
    required this.storeUrl,
    required this.message,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
    currentBuild: _integer(json['current_build']),
    latestBuild: _integer(json['latest_build']),
    minimumBuild: _integer(json['minimum_build']),
    latestVersion: '${json['latest_version'] ?? ''}'.trim(),
    storeUrl: '${json['store_url'] ?? ''}'.trim(),
    message: '${json['message'] ?? ''}'.trim(),
  );

  final int currentBuild;
  final int latestBuild;
  final int minimumBuild;
  final String latestVersion;
  final String storeUrl;
  final String message;

  bool get isAvailable => latestBuild > 0 && currentBuild < latestBuild;
  bool get isRequired => isAvailable && currentBuild < minimumBuild;
}

class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({
    required this.child,
    this.loader,
    this.storeLauncher,
    super.key,
  });

  final Widget child;
  final AppUpdateLoader? loader;
  final AppStoreLauncher? storeLauncher;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  AppUpdateInfo? _update;
  DateTime? _lastCheckedAt;
  int? _dismissedBuild;
  bool _checking = false;
  bool _openingStore = false;
  String? _storeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final lastCheckedAt = _lastCheckedAt;
    if (lastCheckedAt == null ||
        DateTime.now().difference(lastCheckedAt) >=
            const Duration(minutes: 15)) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final update = await (widget.loader?.call() ?? _loadFromServer());
      if (!mounted) return;
      setState(() {
        _lastCheckedAt = DateTime.now();
        _storeError = null;
        _update = update?.isAvailable == true ? update : null;
        if (_update?.isRequired == true) _dismissedBuild = null;
      });
    } catch (_) {
      if (mounted) setState(() => _lastCheckedAt = DateTime.now());
    } finally {
      _checking = false;
    }
  }

  Future<AppUpdateInfo?> _loadFromServer() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    final package = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(package.buildNumber) ?? 0;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final response = await ref
        .read(apiClientProvider)
        .get(
          '/mobile/app-version',
          query: {'platform': platform, 'current_build': '$currentBuild'},
        );
    final data = response['data'];
    if (data is! Map) return null;
    final json = data.cast<String, dynamic>();
    json['current_build'] = currentBuild;
    return AppUpdateInfo.fromJson(json);
  }

  Future<void> _openStore(AppUpdateInfo update) async {
    final uri = Uri.tryParse(update.storeUrl);
    if (uri == null) {
      setState(
        () => _storeError = 'Nie udało się otworzyć sklepu z aplikacją.',
      );
      return;
    }
    setState(() {
      _openingStore = true;
      _storeError = null;
    });
    var opened = false;
    try {
      opened =
          await (widget.storeLauncher?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _openingStore = false;
      if (!opened) {
        _storeError = 'Nie udało się otworzyć sklepu z aplikacją.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final visible = update != null && _dismissedBuild != update.latestBuild;
    final required = visible && update.isRequired;

    return PopScope(
      canPop: !visible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && visible && !required) {
          setState(() => _dismissedBuild = update.latestBuild);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (visible) ...[
            ModalBarrier(
              dismissible: !required,
              onDismiss: required
                  ? null
                  : () => setState(() => _dismissedBuild = update.latestBuild),
              color: WntColors.ink.withValues(alpha: 0.56),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: WntColors.brandSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.system_update_alt_rounded,
                                color: WntColors.brand,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              required
                                  ? 'Aktualizacja wymagana'
                                  : 'Dostępna jest aktualizacja',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              update.message.isNotEmpty
                                  ? update.message
                                  : 'Zaktualizuj aplikację, aby korzystać z najnowszych poprawek i funkcji.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: WntColors.muted),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: WntColors.canvas,
                                border: Border.all(color: WntColors.line),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _VersionValue(
                                      label: 'Zainstalowana',
                                      value: '${update.currentBuild}',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _VersionValue(
                                      label: 'Najnowsza',
                                      value: update.latestVersion.isEmpty
                                          ? '${update.latestBuild}'
                                          : '${update.latestVersion} (${update.latestBuild})',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_storeError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _storeError!,
                                style: const TextStyle(
                                  color: WntColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!required) ...[
                                  OutlinedButton(
                                    onPressed: () => setState(
                                      () =>
                                          _dismissedBuild = update.latestBuild,
                                    ),
                                    child: const Text('Później'),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                FilledButton.icon(
                                  onPressed: _openingStore
                                      ? null
                                      : () => _openStore(update),
                                  icon: _openingStore
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.open_in_new_rounded),
                                  label: const Text('Aktualizuj'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VersionValue extends StatelessWidget {
  const _VersionValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: WntColors.muted),
      ),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

int _integer(dynamic value) => int.tryParse('$value') ?? 0;
