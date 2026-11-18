import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_free/fitshow.dart';
import 'package:stride_free/importer.dart';
import 'package:stride_free/models.dart';

void main() {
  group('FitShow protokolü', () {
    test('çerçeve + XOR sağlaması', () {
      final f = fsFrame([0x53, 0x02, 80, 3]);
      expect(f.first, 0x02);
      expect(f.last, 0x03);
      expect(f[f.length - 2], 0x53 ^ 0x02 ^ 80 ^ 3);
      expect(fsUnframe(f), [0x53, 0x02, 80, 3]);
      final bad = List.of(f)..[2] = 81;
      expect(fsUnframe(bad), isNull);
    });

    test('koşarken durum paketi', () {
      // 0x51, RUNNING, hız 85 (8.5), eğim 2, süre 600 sn, mesafe, kcal 120, adım 900, nabız 140, ?
      final p = [0x51, 3, 85, 2, 0x58, 0x02, 0, 0, 120, 0, 0x84, 0x03, 140, 0];
      final st = parseFitShowStatus(p)!;
      expect(st.state, fsStateRunning);
      expect(st.speedKmh, 8.5);
      expect(st.incline, 2);
      expect(st.elapsedS, 600);
      expect(st.kcal, 120);
      expect(st.steps, 900);
      expect(st.heartRate, 140);
    });

    test('geri sayım ve mil dönüşümü', () {
      expect(parseFitShowStatus([0x51, 2, 3])!.countdown, 3);
      final st = parseFitShowStatus([
        0x51,
        3,
        50,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ], speedFactor: 1.60934)!;
      expect(st.speedKmh, closeTo(8.05, 0.01));
    });
  });

  group('İçe aktarma', () {
    test('Strava activities.csv', () {
      const csv =
          'Activity ID,Activity Date,Activity Name,Activity Type,Elapsed Time,Distance,Max Heart Rate,Elapsed Time,Distance,Calories\n'
          '1,"Nov 5, 2023, 7:45:12 AM",Sabah koşusu,Run,1800,5.01,170,1800,5010.5,320\n'
          '2,"Nov 6, 2023, 6:00:00 PM",Bisiklet,Ride,3600,20,150,3600,20000,500\n';
      final r = parseImportFile('activities.csv', utf8.encode(csv));
      expect(r.format, 'Strava');
      expect(r.sessions.length, 1);
      final s = r.sessions.first;
      expect(s.distanceKm, closeTo(5.0105, 0.0001));
      expect(s.durationSec, 1800);
      expect(s.kcal, 320);
      expect(s.start.toUtc(), DateTime.utc(2023, 11, 5, 7, 45, 12));
    });

    test('Türkçe basit CSV', () {
      const csv = 'tarih;süre;mesafe;kalori\n05.11.2025 07:30;32:10;5,2;310\n';
      final r = parseImportFile('kosular.csv', utf8.encode(csv));
      expect(r.sessions.single.durationSec, 32 * 60 + 10);
      expect(r.sessions.single.distanceKm, 5.2);
      expect(r.sessions.single.start, DateTime(2025, 11, 5, 7, 30));
    });

    test('Apple Sağlık export.xml (yeni ve eski biçim)', () {
      const xml = '''<?xml version="1.0"?>
<HealthData locale="tr_TR">
 <Workout workoutActivityType="HKWorkoutActivityTypeRunning" duration="30" durationUnit="min" sourceName="FitShow" startDate="2024-01-02 07:00:00 +0300" endDate="2024-01-02 07:30:00 +0300">
  <WorkoutStatistics type="HKQuantityTypeIdentifierDistanceWalkingRunning" sum="4.5" unit="km"/>
  <WorkoutStatistics type="HKQuantityTypeIdentifierActiveEnergyBurned" sum="300" unit="kcal"/>
  <WorkoutStatistics type="HKQuantityTypeIdentifierHeartRate" average="141" maximum="165" unit="count/min"/>
 </Workout>
 <Workout workoutActivityType="HKWorkoutActivityTypeWalking" duration="20" durationUnit="min" totalDistance="1" totalDistanceUnit="mi" totalEnergyBurned="90" totalEnergyBurnedUnit="kcal" sourceName="Apple Watch" startDate="2024-01-03 08:00:00 +0300" endDate="2024-01-03 08:20:00 +0300"/>
 <Workout workoutActivityType="HKWorkoutActivityTypeCycling" duration="60" durationUnit="min" sourceName="X" startDate="2024-01-04 08:00:00 +0300" endDate="2024-01-04 09:00:00 +0300"/>
</HealthData>''';
      final r = parseImportFile('export.xml', utf8.encode(xml));
      expect(r.sessions.length, 2);
      expect(r.sources, {'FitShow': 1, 'Apple Watch': 1});
      final fs = r.sessions.firstWhere((s) => s.source == 'FitShow');
      expect(fs.distanceKm, 4.5);
      expect(fs.durationSec, 1800);
      expect(fs.avgHr, 141);
      expect(
        r.sessions.firstWhere((s) => s.source == 'Apple Watch').distanceKm,
        closeTo(1.609, 0.001),
      );
    });

    test('TCX dışa aktar → içe aktar gidiş-dönüş', () {
      final s = WorkoutSession(
        id: 'x',
        start: DateTime.utc(2025, 3, 1, 6, 0),
        title: 'Test',
        durationSec: 60,
        distanceKm: 0.15,
        kcal: 12,
        maxSpeed: 10,
        avgHr: 130,
        speedSamples: List.filled(12, 9.0),
        hrSamples: List.filled(12, 130),
      );
      final back = parseTcx(buildTcx(s)).single;
      expect(back.durationSec, 60);
      expect(back.distanceKm, closeTo(0.15, 0.001));
      expect(back.kcal, 12);
      expect(back.avgHr, 130);
      expect(back.start.toUtc(), s.start);
      expect(back.speedSamples, isNotEmpty);
    });

    test('Yedek gidiş-dönüş', () {
      final s = WorkoutSession(
        id: 'a',
        start: DateTime(2025),
        title: 't',
        durationSec: 10,
        distanceKm: 1,
        kcal: 1,
        maxSpeed: 1,
        source: 'Strava',
      );
      final json = buildBackup(
        sessions: [s],
        programs: builtInPrograms.take(1).toList(),
        settings: {'age': 40},
      );
      final r = parseImportFile('yedek.json', utf8.encode(json));
      expect(r.sessions.single.source, 'Strava');
      expect(r.programs.single.name, builtInPrograms.first.name);
      expect(r.settings!['age'], 40);
    });
  });
}
