import 'dart:async';

import 'package:stride_free/l10n.dart';

/// Testler varsayılan olarak Türkçe çalışır (test makinesinin diline bakılmaz).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  langOverride = AppLang.tr;
  await testMain();
}
