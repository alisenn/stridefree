# Accessibility

StrideFree should be usable by everyone who uses a treadmill — including people with low vision, people who use a screen reader, and people who need large text. This page describes where the app stands today and how to tell us about barriers.

## What we do today

- **Large, high-contrast numbers.** Speed, time, distance and heart rate are shown in large bold digits on a dark background, readable at arm's length while walking or running.
- **System text size.** The app follows your phone's font size; metric tiles shrink their contents instead of cutting text off.
- **Big touch targets.** Speed and incline controls use large +/– buttons and one-tap presets, so you don't need precise taps while moving.
- **Not color-only.** Heart-rate zones are shown with a colour *and* the zone name (e.g. "HR · Warm-up").
- **Two languages.** English and Turkish, following the phone's language.
- **Platform widgets.** The app uses standard Material components, which come with basic screen-reader labels on Android (TalkBack), iOS (VoiceOver) and the web.

## Known limitations

- **Charts** (speed / heart-rate graphs, weekly bars) are not described to screen readers yet; the totals next to them are.
- **Dark theme only.** There's no light or high-contrast theme yet.
- **No audio or haptic cues for segment changes** beyond a short vibration — spoken cues ("next: 8 km/h in 10 seconds") are on the wishlist.
- Some icon-only buttons may be missing descriptive labels.

## Supported environments

Android 7.0+, iOS (current App Store build), and current Chrome / Edge / Firefox / Safari for the web demo (Bluetooth treadmills require Chrome or Edge).

## Report a barrier

If something in StrideFree is hard or impossible for you to use, please [open an issue](https://github.com/alisenn/stridefree/issues/new?labels=accessibility&title=Accessibility%3A%20) — describe what you tried, your device, and any assistive technology you use. Accessibility issues are treated as bugs, not feature requests. You can also email **canykimy@gmail.com**.

---

**Türkçe:** StrideFree'yi kullanmanızı zorlaştıran bir durum varsa (ekran okuyucu, büyük yazı, renk ayrımı vb.) lütfen [issue açın](https://github.com/alisenn/stridefree/issues/new?labels=accessibility&title=Accessibility%3A%20) ya da **canykimy@gmail.com** adresine yazın. Erişilebilirlik sorunları hata olarak ele alınır.
