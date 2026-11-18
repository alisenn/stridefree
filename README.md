# StrideFree

Bluetooth FTMS uyumlu koşu bantları için **ücretsiz ve açık kaynak** kontrol uygulaması.
Abonelik yok, reklam yok, kilitli "premium" özellik yok.

*Free & open-source treadmill controller for Bluetooth FTMS treadmills — no subscriptions, no ads, no paywalls.*

## Özellikler

- **Bluetooth FTMS kontrolü** – hız ve eğimi uygulamadan ayarla, bandın limitlerini otomatik okur
- **Hazır programlar** – HIIT 20, Tepe Tırmanışı, 5K Hazırlık, Piramit, Yağ Yakım, Eğimli 30, Tempolu Yürüyüş
- **Program editörü** – sınırsız özel program, bölüm bazında süre/hız/eğim, tek tıkla interval blokları
- **Hedefli koşu** – süre, mesafe veya kalori hedefi
- **Nabız bandı** – standart BLE Heart Rate; yaşa göre 5 nabız bölgesi
- **Kiloya göre kalori** – ACSM metabolik denklemleri
- **Sınırsız geçmiş & istatistik** – haftalık grafik, seri, rekorlar, hız/nabız grafikleri
- **Güvenlik** – hız sınırı, antrenman sırasında ekran açık kalır
- **Demo modu** – cihaz olmadan dene

## Gizlilik

Tüm veriler (profil, programlar, antrenman geçmişi) **yalnızca cihazınızda** saklanır.
Uygulamada hesap, sunucu, analitik veya internet bağlantısı yoktur.

## Platformlar

Flutter ile yazılmıştır: iOS, Android, macOS, Windows, Linux ve Web (Chrome/Edge – Web Bluetooth).

## Çalıştırma

```bash
flutter pub get
flutter run            # bağlı cihaz / simülatör
flutter run -d chrome  # web
flutter test
```

## Uyumluluk notu

Uygulama standart **Bluetooth FTMS** (Fitness Machine Service, `0x1826`) protokolünü kullanır.
Bazı ucuz bantlardaki FitShow modülleri yalnızca kendi özel protokolünü konuşur; bu bantlar şu an desteklenmiyor.
Bandınız çalışmıyorsa marka/model ile bir issue açın.

## Lisans

MIT – bkz. [LICENSE](LICENSE).

Bluetooth için [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) kullanılır; bu kütüphanenin lisansı kişisel ve
kâr amacı gütmeyen kullanımda ücretsizdir, ticari dağıtım için ayrı lisans gerektirir (`lib/devices.dart` → `kBleLicense`).

*StrideFree, FitShow ile bağlantılı değildir.*
