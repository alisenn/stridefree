// Basit iki dilli (Türkçe / İngilizce) metin altyapısı.
//
// Her metin kullanıldığı yerde iki diliyle yan yana yazılır:
//   Text(tx('Başla', 'Start'))
// BuildContext gerektirmez; model, istatistik ve bildirim kodunda da çalışır.
// Dil değişince uygulama ağacı yeniden kurulur (bkz. main.dart).
import 'dart:ui' show PlatformDispatcher;

enum AppLang { tr, en }

/// Kullanıcının seçimi: null = telefonun diline göre.
AppLang? langOverride;

/// Şu an geçerli dil.
AppLang get appLang {
  if (langOverride != null) return langOverride!;
  final code = PlatformDispatcher.instance.locale.languageCode;
  return code == 'tr' ? AppLang.tr : AppLang.en;
}

bool get isEn => appLang == AppLang.en;

/// Türkçe / İngilizce metinden geçerli dildekini döndürür.
String tx(String tr, String en) => isEn ? en : tr;
