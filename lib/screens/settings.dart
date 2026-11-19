// Profil ve ayarlar.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      appBar: AppBar(title: const Text('Profil & Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Section('Profil', [
            _Row(
              'Kilo',
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
              'Yaş',
              AdjustControl(
                compact: true,
                label: 'yıl',
                value: '${s.age}',
                onMinus: () => s.update(age: (s.age - 1).clamp(10, 100)),
                onPlus: () => s.update(age: (s.age + 1).clamp(10, 100)),
              ),
            ),
            Text(
              'Kalori kilonuza göre (ACSM formülü), nabız bölgeleri yaşınıza göre (maks ${s.maxHr} bpm) hesaplanır.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
          _Section('Hedefler', [
            _Row(
              'Haftalık hedef',
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
          _Section('Güvenlik & kontrol', [
            _Row(
              'Hız sınırı',
              AdjustControl(
                compact: true,
                label: 'km/s',
                value: s.speedLimit.toStringAsFixed(0),
                onMinus: () => s.update(limit: (s.speedLimit - 1).clamp(3, 25)),
                onPlus: () => s.update(limit: (s.speedLimit + 1).clamp(3, 25)),
              ),
            ),
            _Row(
              'Hız adımı (+/-)',
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
          _Section('Nabız bölgeleri', [
            for (var z = 1; z <= 5; z++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: zoneColors[z],
                ),
                title: Text('Bölge $z · ${zoneNames[z]}'),
                trailing: Text(
                  '${(s.maxHr * (0.4 + z * 0.1)).round()}–${(s.maxHr * (0.5 + z * 0.1)).round()} bpm',
                ),
              ),
          ]),
          _Section('Manuel eğim', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bandımda manuel eğim var'),
              subtitle: const Text(
                'Eğim, öndeki ayaklar kaldırılarak veriliyorsa açın (motorlu eğimi olmayan bantlar)',
              ),
              value: s.manualInclineEnabled,
              onChanged: (v) => s.setManualIncline(enabled: v),
            ),
            if (s.manualInclineEnabled) ...[
              _Row(
                'Eğim',
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
                'Ölçmek için: ayaklar takılıyken bandın ön ucunun yerden yüksekliğinden '
                'arka ucunun yüksekliğini çıkarın, bandın boyuna bölüp 100 ile çarpın. '
                'Örnek: 5 cm fark, 120 cm boy → 5 / 120 × 100 ≈ %4.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ]),
          _Section('Verilerim', [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Verileri içe aktar / yedekle'),
              subtitle: const Text(
                'Strava, Apple Sağlık, TCX, GPX, CSV · yedek al / geri yükle',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
            ),
          ]),
          _Section('FitShow modüllü bantlar', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bant hızı mil cinsinden'),
              subtitle: const Text(
                'Ekrandaki hız bandın göstergesinden 1.6 kat farklıysa açın',
              ),
              value: s.fitshowMiles,
              onChanged: (v) => s.setFitShow(miles: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('FitShow protokolünü tercih et'),
              subtitle: const Text(
                'Bant hem FTMS hem FitShow destekliyorsa FitShow kullan',
              ),
              value: s.preferFitShow,
              onChanged: (v) => s.setFitShow(prefer: v),
            ),
          ]),
          _Section('Hakkında', [
            Text(
              'StrideFree – Bluetooth FTMS ve FitShow modüllü koşu bantları için açık ve ücretsiz kontrol uygulaması. '
              'Abonelik yok, reklam yok, kilitli özellik yok. Verileriniz yalnızca bu cihazda saklanır.',
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
