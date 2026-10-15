import 'package:code_tutorials/state/reader_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // getInstance() 有进程级缓存，setMockInitialValues 对已建实例无效；
  // 每个用例拿同一实例后 clear() 做隔离。
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test('默认标准档：正文 16 / h1 24 / h2 20.8 / h3 18.4 / 代码 13', () {
    final store = ReaderPrefs(prefs)..load();
    expect(store.scale, 1.0);
    expect(store.bodyFontSize, 16);
    expect(store.h1FontSize, 24);
    expect(store.h2FontSize, closeTo(20.8, 0.001));
    expect(store.h3FontSize, closeTo(18.4, 0.001));
    expect(store.codeFontSize, 13);
    expect(store.label, '标准');
  });

  test('切特大档：正文 20 / h1 30 / 代码 15，并持久化倍率 1.25', () async {
    final store = ReaderPrefs(prefs);
    await store.setScale(1.25);
    expect(store.bodyFontSize, 20);
    expect(store.h1FontSize, 30);
    expect(store.h2FontSize, closeTo(26.0, 0.001));
    expect(store.h3FontSize, 23);
    expect(store.codeFontSize, 15);
    expect(store.label, '特大');
    expect(prefs.getDouble('reader.font_scale'), 1.25);
  });

  test('load 读回已保存倍率：大档正文 18 / 代码 14', () async {
    await prefs.setDouble('reader.font_scale', 1.125);
    final store = ReaderPrefs(prefs)..load();
    expect(store.scale, 1.125);
    expect(store.bodyFontSize, 18);
    expect(store.codeFontSize, 14);
  });

  test('非法倍率 load 回退标准档；未定义倍率的 setScale 被忽略', () async {
    await prefs.setDouble('reader.font_scale', 9.9);
    final store = ReaderPrefs(prefs)..load();
    expect(store.scale, 1.0);

    await store.setScale(2.0);
    expect(store.scale, 1.0);
    expect(prefs.getDouble('reader.font_scale'), 9.9);
  });
}
