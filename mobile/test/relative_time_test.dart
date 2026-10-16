import 'package:code_tutorials/utils/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 固定“当前时间”，避免测试随真实时钟漂移。
  final now = DateTime(2026, 10, 16, 12, 0, 0);
  test('null / 解析失败给占位符', () {
    expect(relativeTime(null, now: now), '—');
  });

  test('不到 1 分钟 = 刚刚（含轻微未来偏差）', () {
    expect(relativeTime(now.subtract(30.seconds), now: now), '刚刚');
    expect(relativeTime(now.add(20.seconds), now: now), '刚刚');
  });

  test('分钟 / 小时 / 天', () {
    expect(relativeTime(now.subtract(5.minutes), now: now), '5分钟前');
    expect(relativeTime(now.subtract(59.minutes), now: now), '59分钟前');
    expect(relativeTime(now.subtract(3.hours), now: now), '3小时前');
    expect(relativeTime(now.subtract(23.hours), now: now), '23小时前');
    expect(relativeTime(now.subtract(2.days), now: now), '2天前');
    expect(relativeTime(now.subtract(29.days), now: now), '29天前');
  });

  test('超过 30 天回退日期格式', () {
    expect(relativeTime(now.subtract(45.days), now: now), '2026-09-01');
  });

  test('较大未来时间给占位符', () {
    expect(relativeTime(now.add(5.minutes), now: now), '—');
  });

  group('formatHm 状态条时间', () {
    test('两位补零（24 小时制）', () {
      expect(formatHm(DateTime(2026, 10, 16, 20, 5)), '20:05');
      expect(formatHm(DateTime(2026, 10, 16, 9, 7)), '09:07');
      expect(formatHm(DateTime(2026, 10, 16, 23, 59)), '23:59');
    });

    test('午夜与正午', () {
      expect(formatHm(DateTime(2026, 10, 16, 0, 0)), '00:00');
      expect(formatHm(DateTime(2026, 10, 16, 12, 0)), '12:00');
    });
  });
}

extension _NumDuration on num {
  Duration get seconds => Duration(seconds: toInt());
  Duration get minutes => Duration(minutes: toInt());
  Duration get hours => Duration(hours: toInt());
  Duration get days => Duration(days: toInt());
}
