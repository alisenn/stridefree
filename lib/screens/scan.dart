// Bluetooth cihaz tarama ekranı (koşu bandı veya nabız bandı).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../devices.dart';
import '../fitshow.dart';

enum ScanKind { treadmill, heartRate }

/// Seçilen cihazı döndürür.
Future<BluetoothDevice?> showScanSheet(BuildContext context, ScanKind kind) {
  return showModalBottomSheet<BluetoothDevice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ScanSheet(kind: kind),
  );
}

class _ScanSheet extends StatefulWidget {
  final ScanKind kind;
  const _ScanSheet({required this.kind});

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  List<ScanResult> results = [];
  bool scanning = false;
  bool showAll = false;
  String? error;
  StreamSubscription? _sub, _scanSub;

  List<Guid> get services => widget.kind == ScanKind.treadmill
      ? [ftmsService, ...fitshowServices]
      : [hrService];

  /// 'FTMS', 'FitShow', 'Nabız' veya null
  String? matchLabel(ScanResult r) {
    final uu = r.advertisementData.serviceUuids;
    if (widget.kind == ScanKind.heartRate) {
      return uu.contains(hrService) ? 'Nabız sensörü' : null;
    }
    if (uu.contains(ftmsService)) return 'FTMS uyumlu';
    final n =
        (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.advName)
            .toUpperCase();
    if (fitshowServices.any(uu.contains) || n.startsWith('FS-')) {
      return 'FitShow protokolü';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _sub = FlutterBluePlus.scanResults.listen((r) {
      if (mounted) setState(() => results = r);
    });
    _scanSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => scanning = s);
    });
    _start();
  }

  Future<void> _start() async {
    setState(() => error = null);
    try {
      if (!await FlutterBluePlus.isSupported) {
        setState(
          () => error =
              'Bu cihaz/tarayıcı Bluetooth LE desteklemiyor. '
              'Web için Chrome veya Edge kullanın.',
        );
        return;
      }
      if (!kIsWeb) {
        final st = await FlutterBluePlus.adapterState
            .where((s) => s != BluetoothAdapterState.unknown)
            .first
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => BluetoothAdapterState.unknown,
            );
        if (st != BluetoothAdapterState.on) {
          setState(
            () => error = 'Bluetooth kapalı veya izin verilmedi. Lütfen açın.',
          );
          return;
        }
      }
      await FlutterBluePlus.startScan(
        withServices: showAll ? [] : services,
        webOptionalServices: [ftmsService, ...fitshowServices, hrService],
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      setState(() => error = 'Tarama başlatılamadı: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list =
        results
            .where((r) => showAll || matchLabel(r) != null || kIsWeb)
            .where(
              (r) =>
                  !showAll ||
                  r.device.platformName.isNotEmpty ||
                  r.advertisementData.advName.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final title = widget.kind == ScanKind.treadmill
        ? 'Koşu bandı ara'
        : 'Nabız bandı ara';

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            ListTile(
              title: Text(title, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                widget.kind == ScanKind.treadmill
                    ? 'Bandı açın. FTMS ve FitShow modüllü bantlar desteklenir.'
                    : 'Göğüs bandını takın ya da saatinizde nabız yayınını açın.',
              ),
              trailing: scanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _start,
                    ),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Tüm Bluetooth cihazlarını göster'),
              subtitle: const Text('Bandınız listede yoksa açın'),
              value: showAll,
              onChanged: (v) async {
                setState(() => showAll = v);
                await FlutterBluePlus.stopScan();
                _start();
              },
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!, style: TextStyle(color: cs.error)),
              ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        scanning ? 'Aranıyor…' : 'Cihaz bulunamadı',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final r = list[i];
                        final name = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : (r.advertisementData.advName.isNotEmpty
                                  ? r.advertisementData.advName
                                  : r.device.remoteId.str);
                        final label = matchLabel(r);
                        final isMatch = label != null;
                        return ListTile(
                          leading: Icon(
                            widget.kind == ScanKind.treadmill
                                ? Icons.directions_run
                                : Icons.favorite,
                            color: isMatch ? cs.primary : cs.onSurfaceVariant,
                          ),
                          title: Text(name),
                          subtitle: Text(label ?? r.device.remoteId.str),
                          trailing: Text('${r.rssi} dBm'),
                          onTap: () {
                            FlutterBluePlus.stopScan();
                            Navigator.pop(context, r.device);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
