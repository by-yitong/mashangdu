import 'dart:convert';

import 'package:code_tutorials/models/models.dart';
import 'package:code_tutorials/state/resume_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // getInstance() 有进程级缓存，setMockInitialValues 对已建实例无效；
  // 每个用例拿同一实例后 clear() 做隔离（同 reader_prefs_test 模式）。
  late SharedPreferences prefs;
  late ResumeStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    store = ResumeStore(prefs);
  });

  const course = CourseSummary(
    slug: 'go-basics',
    title: 'Go 入门',
    summary: '一门入门课',
    language: 'Go',
    color: '#14B8A6',
    chapterCount: 12,
    updatedAt: null,
  );

  test('enter 后 pendingResume 返回课程与章节', () async {
    await store.enterReading(course, 'ch-2');
    final pending = store.pendingResume();
    expect(pending, isNotNull);
    expect(pending!.course.slug, 'go-basics');
    expect(pending.course.title, 'Go 入门');
    expect(pending.course.chapterCount, 12);
    expect(pending.chapterSlug, 'ch-2');
  });

  test('切章再 enter：章节记录更新', () async {
    await store.enterReading(course, 'ch-2');
    await store.enterReading(course, 'ch-3');
    expect(store.pendingResume()!.chapterSlug, 'ch-3');
  });

  test('exit 后 pendingResume 返回 null，两个 key 均被删除', () async {
    await store.enterReading(course, 'ch-2');
    await store.exitReading();
    expect(store.pendingResume(), isNull);
    expect(prefs.getString('resume.course_json'), isNull);
    expect(prefs.getString('resume.chapter_slug'), isNull);
  });

  test('记录不存在：pendingResume 返回 null', () {
    expect(store.pendingResume(), isNull);
  });

  test('course_json 坏 JSON：pendingResume 返回 null', () async {
    await prefs.setString('resume.course_json', '{not-valid-json');
    await prefs.setString('resume.chapter_slug', 'ch-2');
    expect(store.pendingResume(), isNull);
  });

  test('course_json 非 JSON 对象（数组）：pendingResume 返回 null', () async {
    await prefs.setString('resume.course_json', jsonEncode([1, 2, 3]));
    await prefs.setString('resume.chapter_slug', 'ch-2');
    expect(store.pendingResume(), isNull);
  });

  test('章节 slug 缺失：pendingResume 返回 null', () async {
    await prefs.setString('resume.course_json', jsonEncode(course.toJson()));
    expect(store.pendingResume(), isNull);
  });
}
