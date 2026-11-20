// Profil ve ayarlar.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state.dart';
import '../widgets.dart';
import 'import.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tx('Profil & Ayarlar', 'Profile & Settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Section(tx('Dil', 'Language'), [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'system',
                  label: Text(tx('Sistem', 'System')),
                ),
                const ButtonSegment(value: 'tr', label: Text('Türkçe')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {s.language},
              onSelectionChanged: (v) => s.setLanguage(v.first),
            ),
          ]),
          _Section(tx('Profil', 'Profile'), [
            _Row(
              tx('Kilo', 'Weight'),
              AdjustControl(
                compact: true,
                label: 'kg',
                value: s.weightKg.toStringAsFixed(0),
                onMinus: () =>
                    s.update(weight: (s.weightKg - 1).clamp(30, 250)),
                onPlus: () => s.update(weight: (s.weightKg + 1).clamp(30, 250)),
              ),
            ),
            _Row(
              tx('Boy', 'Height'),
              AdjustControl(
                compact: true,
                label: 'cm',
                value: s.heightCm.toStringAsFixed(0),
                onMinus: () =>
                    s.update(height: (s.heightCm - 1).clamp(100, 230)),
                onPlus: () =>
                    s.update(height: (s.heightCm + 1).clamp(100, 230)),
              ),
            ),
            _Row(
              tx('Yaş', 'Age'),
              AdjustControl(
                compact: true,
                label: tx('yıl', 'yrs'),
                value: '${s.age}',
                onMinus: () => s.update(age: (s.age - 1).clamp(10, 100)),
                onPlus: () => s.update(age: (s.age + 1).clamp(10, 100)),
              ),
            ),
            Text(
              tx(
                'Kalori kilonuza göre (ACSM formülü), nabız bölgeleri yaşınıza göre (maks ${s.maxHr} bpm) hesaplanır. '
                    'Bant adım saymıyorsa adım sayısı boyunuz ve hızınızdan tahmin edilir (≈).',
                'Calories are based on your weight (ACSM formula), heart-rate zones on your age (max ${s.maxHr} bpm). '
                    "If the treadmill doesn't count steps, they're estimated from your height and speed (≈).",
              ),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
          _Section(tx('Hedefler', 'Goals'), [
            _Row(
              tx('Haftalık hedef', 'Weekly goal'),
              AdjustControl(
                compact: true,
                label: 'km',
                value: s.weeklyGoalKm.toStringAsFixed(0),
                onMinus: () =>
                    s.update(weekly: (s.weeklyGoalKm - 1).clamp(1, 300)),
                onPlus: () =>
                    s.update(weekly: (s.weeklyGoalKm + 1).clamp(1, 300)),
              ),
            ),
          ]),
          _Section(tx('Güvenlik & kontrol', 'Safety & control'), [
            _Row(
              tx('Hız sınırı', 'Speed limit'),
              AdjustControl(
                compact: true,
                label: tx('km/s', 'km/h'),
                value: s.speedLimit.toStringAsFixed(0),
                onMinus: () => s.update(limit: (s.speedLimit - 1).clamp(3, 25)),
                onPlus: () => s.update(limit: (s.speedLimit + 1).clamp(3, 25)),
              ),
            ),
            _Row(
              tx('Hız adımı (+/-)', 'Speed step (+/-)'),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.1, label: Text('0.1')),
                  ButtonSegment(value: 0.5, label: Text('0.5')),
                  ButtonSegment(value: 1.0, label: Text('1.0')),
                ],
                selected: {s.speedStep},
                onSelectionChanged: (v) => s.update(step: v.first),
              ),
            ),
          ]),
          _Section(tx('Nabız bölgeleri', 'Heart-rate zones'), [
            for (var z = 1; z <= 5; z++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: zoneColors[z],
                ),
                title: Text(
                  tx('Bölge $z · ${zoneNames[z]}', 'Zone $z · ${zoneNames[z]}'),
                ),
                trailing: Text(
                  '${(s.maxHr * (0.4 + z * 0.1)).round()}–${(s.maxHr * (0.5 + z * 0.1)).round()} bpm',
                ),
              ),
          ]),
          _Section(tx('Manuel eğim', 'Manual incline'), [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tx(
                  'Bandımda manuel eğim var',
                  'My treadmill has manual incline',
                ),
              ),
              subtitle: Text(
                tx(
                  'Eğim, öndeki ayaklar kaldırılarak veriliyorsa açın (motorlu eğimi olmayan bantlar)',
                  'Turn on if incline is set by raising the front feet (treadmills without motorized incline)',
                ),
              ),
              value: s.manualInclineEnabled,
              onChanged: (v) => s.setManualIncline(enabled: v),
            ),
            if (s.manualInclineEnabled) ...[
              _Row(
                tx('Eğim', 'Incline'),
                AdjustControl(
                  compact: true,
                  label: '%',
                  value: s.manualInclinePct.toStringAsFixed(1),
                  onMinus: () => s.setManualIncline(
                    pct: (s.manualInclinePct - 0.5).clamp(0.5, 15),
                  ),
                  onPlus: () => s.setManualIncline(
                    pct: (s.manualInclinePct + 0.5).clamp(0.5, 15),
                  ),
                ),
              ),
              Text(
                tx(
                  'Ölçmek için: ayaklar takılıyken bandın ön ucunun yerden yüksekliğinden '
                      'arka ucunun yüksekliğini çıkarın, bandın boyuna bölüp 100 ile çarpın. '
                      'Örnek: 5 cm fark, 100 cm boy → 5 / 100 × 100 = %5 '
                      '(ör. Relax RL-890: üretici 5 cm manuel eğim belirtiyor).',
                  'To measure: with the feet attached, subtract the rear end height from the '
                      'front end height, divide by the treadmill length and multiply by 100. '
                      'Example: 5 cm difference, 100 cm length → 5 / 100 × 100 = 5% '
                      '(e.g. Relax RL-890: the maker specifies 5 cm manual incline).',
                ),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ]),
          _Section(tx('Verilerim', 'My data'), [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz),
              title: Text(
                tx('Verileri içe aktar / yedekle', 'Import / back up data'),
              ),
              subtitle: Text(
                tx(
                  'Strava, Apple Sağlık, TCX, GPX, CSV · yedek al / geri yükle',
                  'Strava, Apple Health, TCX, GPX, CSV · back up / restore',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
            ),
          ]),
          _Section(tx('FitShow modüllü bantlar', 'FitShow treadmills'), [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tx('Bant hızı mil cinsinden', 'Treadmill speed in miles'),
              ),
              subtitle: Text(
                tx(
                  'Ekrandaki hız bandın göstergesinden 1.6 kat farklıysa açın',
                  'Turn on if the app speed differs from the treadmill display by 1.6x',
                ),
              ),
              value: s.fitshowMiles,
              onChanged: (v) => s.setFitShow(miles: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tx('FitShow protokolünü tercih et', 'Prefer FitShow protocol'),
              ),
              subtitle: Text(
                tx(
                  'Bant hem FTMS hem FitShow destekliyorsa FitShow kullan',
                  'Use FitShow if the treadmill supports both FTMS and FitShow',
                ),
              ),
              value: s.preferFitShow,
              onChanged: (v) => s.setFitShow(prefer: v),
            ),
          ]),
          _Section(tx('Hakkında', 'About'), [
            Text(
              tx(
                'StrideFree – Bluetooth FTMS ve FitShow modüllü koşu bantları için açık ve ücretsiz kontrol uygulaması. '
                    'Abonelik yok, reklam yok, kilitli özellik yok. Verileriniz yalnızca bu cihazda saklanır.',
                'StrideFree – an open, free controller app for Bluetooth FTMS and FitShow treadmills. '
                    'No subscription, no ads, no locked features. Your data is stored only on this device.',
              ),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row(this.label, this.child);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        child,
      ],
    ),
  );
}
