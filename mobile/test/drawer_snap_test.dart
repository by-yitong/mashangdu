import 'package:code_tutorials/utils/drawer_snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('速度优先：向右甩动 ≥ 阈值 → 开（哪怕位置很小）', () {
    expect(drawerSnapOpen(0.1, 600), isTrue);
    expect(drawerSnapOpen(0.05, 1200), isTrue);
  });

  test('速度优先：向左甩动 ≤ -阈值 → 关（哪怕位置很大）', () {
    expect(drawerSnapOpen(0.9, -600), isFalse);
    expect(drawerSnapOpen(0.95, -1500), isFalse);
  });

  test('速度不足按位置：拖过半（≥0.5）→ 开，否则关', () {
    expect(drawerSnapOpen(0.5, 0), isTrue);
    expect(drawerSnapOpen(0.7, 100), isTrue);
    expect(drawerSnapOpen(0.49, -100), isFalse);
    expect(drawerSnapOpen(0.3, 0), isFalse);
  });

  test('低于阈值的小速度不参与判定，位置说了算', () {
    // 599 px/s 向右但不足阈值 → 看位置。
    expect(drawerSnapOpen(0.2, 599), isFalse);
    expect(drawerSnapOpen(0.6, 599), isTrue);
    // -599 px/s 向左不足阈值 → 看位置。
    expect(drawerSnapOpen(0.8, -599), isTrue);
  });

  test('自定义阈值参数生效', () {
    expect(drawerSnapOpen(0.4, 0, positionThreshold: 0.3), isTrue);
    expect(drawerSnapOpen(0.4, 0, positionThreshold: 0.6), isFalse);
    expect(drawerSnapOpen(0, 300, flingVelocity: 200), isTrue);
  });
}
