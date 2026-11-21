# Contributing to StrideFree

Thanks for helping! StrideFree is a free, open-source treadmill app with no ads, no accounts and no server. Every contribution — a device report, a bug, a translation or code — makes it better for everyone.

*Türkçe özet en altta.*

## Ways to help

| What | How |
| --- | --- |
| 🏃 **Device report** — the most valuable one | [Open a device report](https://github.com/alisenn/stridefree/issues/new?template=device_report.yml): brand/model, protocol shown in the app, what works and what doesn't |
| 🐞 **Bug report** | [Open a bug report](https://github.com/alisenn/stridefree/issues/new?template=bug_report.yml) with steps to reproduce |
| 💡 **Feature idea** | [Open a feature request](https://github.com/alisenn/stridefree/issues/new?template=feature_request.yml) |
| 🌍 **Translation** | See [Adding a language](#adding-a-language) |
| 🛠 **Code** | Fork → branch → pull request (see below) |

## Development setup

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.x.

```bash
git clone https://github.com/alisenn/stridefree.git
cd stridefree
flutter pub get
flutter run -d chrome     # quickest: web build, tap "Demo" for a simulated treadmill
flutter run               # phone / simulator (real Bluetooth)
```

No treadmill? **Demo mode** simulates one, so you can work on almost everything without hardware.

## Before you open a pull request

```bash
dart format lib test
flutter analyze           # must say "No issues found!"
flutter test              # must pass
```

- Keep pull requests focused — one fix or feature per PR.
- Add or update a test when you change logic (parsers, stats, calories, steps…).
- **User-visible text must be in both languages** with the `tx()` helper:
  ```dart
  Text(tx('Başla', 'Start'))
  ```
  Don't worry if your Turkish isn't perfect — write the English and leave a note in the PR; the maintainer will fix the Turkish.
- Don't add analytics, ads, trackers, accounts or network calls. Workout data stays on the device — that's a core promise of the app.
- Bluetooth changes: please say which treadmill you tested on.

## Project layout

| Path | What's inside |
| --- | --- |
| `lib/devices.dart` | FTMS parser & driver, heart-rate strap, demo treadmill |
| `lib/fitshow.dart` | FitShow protocol driver |
| `lib/state.dart` | Settings, programs, history, workout engine |
| `lib/l10n.dart` | `tx()` language helper |
| `lib/screens/` | UI |
| `test/` | Unit tests |
| `store/` | Store listings, screenshots, release tooling |

## Adding a language

Today the app uses `tx('Türkçe', 'English')` pairs. To add a third language, open an issue first so we can agree on the approach (the helper would grow into a small lookup) — then translations can be split across contributors.

## Releases (maintainers)

1. Bump `version:` in `pubspec.yaml` (both the name and the build number).
2. Write release notes in `store/release-notes/<version>/tr-TR.txt` and `en-US.txt` (max 500 chars).
3. `python store/tools/play_upload.py --build` to validate, then `--commit` to send for review.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).

---

## Türkçe özet

En değerli katkı **cihaz raporu**: bandınızın marka/modelini ve neyin çalışıp neyin çalışmadığını [bu formla](https://github.com/alisenn/stridefree/issues/new?template=device_report.yml) bildirin. Kod katkısı için: fork → dal → PR; göndermeden önce `dart format lib test`, `flutter analyze` ve `flutter test` geçmeli. Ekranda görünen her metin `tx('Türkçe', 'English')` ile iki dilde yazılmalı. Uygulamaya analitik, reklam, hesap ya da sunucu bağlantısı eklenmez — veriler telefonda kalır.
