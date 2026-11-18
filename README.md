# StrideFree

Bluetooth **FTMS** ve **FitShow modüllü** koşu bantları için **ücretsiz ve açık kaynak** kontrol uygulaması.
Abonelik yok, reklam yok, kilitli "premium" özellik yok.

*Free & open-source treadmill controller for Bluetooth FTMS and FitShow-module treadmills — no subscriptions, no ads, no paywalls.*

## Özellikler

- **Bluetooth kontrol** – standart FTMS ve FitShow'un özel protokolü; hız/eğim kontrolü, bandın limitlerini otomatik okur
- **Hazır programlar** – HIIT 20, Tepe Tırmanışı, 5K Hazırlık, Piramit, Yağ Yakım, Eğimli 30, Tempolu Yürüyüş
- **Program editörü** – sınırsız özel program, bölüm bazında süre/hız/eğim, tek tıkla interval blokları
- **Hedefli koşu** – süre, mesafe veya kalori hedefi
- **Nabız bandı** – standart BLE Heart Rate; yaşa göre 5 nabız bölgesi
- **Kiloya göre kalori** – ACSM metabolik denklemleri
- **Sınırsız geçmiş & istatistik** – haftalık grafik, seri, rekorlar, hız/nabız grafikleri
- **Güvenlik** – hız sınırı, antrenman sırasında ekran açık kalır
- **FitShow'dan geçiş** – Strava (`activities.csv`), Apple Sağlık (`export.xml`), TCX, GPX ve CSV içe aktarma
- **Dışa aktarma** – her antrenmanı TCX olarak kaydet (Strava / Garmin'e yükle), tüm verileri JSON yedeğe al
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

## Desteklenen bantlar

| Protokol | Nasıl tanınır | Not |
|---|---|---|
| Bluetooth FTMS (`0x1826`) | Servis UUID'si | Standart; çoğu yeni bant |
| FitShow özel protokolü (`0xFFF0` / `0xFFE0`) | Servis UUID'si veya `FS-` ile başlayan ad | FTMS olmayan FitShow modüllü bantlar |

Bağlanırken uygulama önce FTMS'i, yoksa FitShow protokolünü dener (Profil → "FitShow protokolünü tercih et" ile tersine çevrilebilir).
Bazı FitShow bantları hızı mil cinsinden bildirir; hız 1,6 kat farklı görünüyorsa Profil → "Bant hızı mil cinsinden" seçeneğini açın.

FitShow protokol desteği gerçek cihazlarda henüz sınırlı test edildi — bandınızda sorun olursa marka/model ile bir issue açın.

## FitShow'dan veri taşıma

Profil → **Verilerim → FitShow'dan / başka uygulamadan aktar**:

- **Strava:** strava.com → Ayarlar → Hesabım → "Hesabınızı indirin" → zip içindeki `activities.csv`
- **Apple Sağlık:** Sağlık → profil → "Tüm sağlık verilerini dışa aktar" → `export.zip` içindeki `export.xml` (kaynak uygulamaya göre filtrelenebilir)
- **TCX / GPX** dosyaları
- **CSV:** `tarih, süre, mesafe, kalori` sütunları (`,` veya `;` ayırıcı)

Aynı antrenman iki kez eklenmez.

## Lisans

MIT – bkz. [LICENSE](LICENSE).

Bluetooth için [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) kullanılır; bu kütüphanenin lisansı kişisel ve
kâr amacı gütmeyen kullanımda ücretsizdir, ticari dağıtım için ayrı lisans gerektirir (`lib/devices.dart` → `kBleLicense`).

*StrideFree, FitShow ile bağlantılı değildir.*
