// Antrenman sırasında uygulamanın arka planda öldürülmemesi için.
//
// Android: bildirim çubuğunda görünen bir "ön plan servisi" başlatılır; sistem,
//          bu servis çalışırken uygulamayı (YouTube vb. açıkken bile) kapatmaz.
// iOS:     arka plan modu kullanılmıyor (App Review 2.5.4); uygulama askıya alınır.
//          Geri dönüldüğünde WorkoutController aradaki süreyi bandın sayaçlarından
//          telafi eder; antrenman her 5 sn ve arka plana geçerken kaydedilir.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'l10n.dart';

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

class WorkoutBackground {
  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout',
        channelName: tx('Aktif antrenman', 'Active workout'),
        channelDescription: tx(
          'Antrenman sürerken gösterilir; uygulamanın kapanmasını önler.',
          'Shown during a workout; keeps the app from being closed.',
        ),
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  static Future<void> start(String title, String text) async {
    if (!_isAndroid) return;
    try {
      _init();
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 1001,
          serviceTypes: [ForegroundServiceTypes.connectedDevice],
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (e) {
      debugPrint('Ön plan servisi başlatılamadı: $e');
    }
  }

  static Future<void> update(String title, String text) async {
    if (!_isAndroid || !_initialized) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!_isAndroid || !_initialized) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
