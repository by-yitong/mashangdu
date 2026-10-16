import 'package:code_tutorials/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MetaInfo 解析信封 data', () {
    final meta = MetaInfo.fromJson(<String, dynamic>{
      'content_version': '2026-10-15T08:30:00Z',
      'course_count': 2,
    });
    expect(meta.courseCount, 2);
    expect(meta.versionDate, '2026-10-15');
  });

  test('CourseSummary 列表解析', () {
    final courses = CourseSummary.listFromJson(<Object?>[
      <String, dynamic>{
        'slug': 'go-basics',
        'title': 'Go 语言入门',
        'summary': '从零开始学 Go',
        'language': 'Go',
        'color': '#14B8A6',
        'chapter_count': 3,
        'updated_at': '2026-10-14T12:00:00Z',
      },
      '非对象元素应被跳过',
    ]);
    expect(courses.length, 1);
    expect(courses.first.slug, 'go-basics');
    expect(courses.first.chapterCount, 3);
  });

  test('CourseDetail 章节解析', () {
    final detail = CourseDetail.fromJson(<String, dynamic>{
      'slug': 'go-basics',
      'title': 'Go 语言入门',
      'summary': '',
      'language': 'Go',
      'color': '#14B8A6',
      'updated_at': '2026-10-14T12:00:00Z',
      'chapters': [
        {'slug': 'hello-world', 'title': 'Hello World', 'order': 1},
        {'slug': 'variables', 'title': '变量与类型', 'order': 2},
      ],
    });
    expect(detail.chapters.length, 2);
    expect(detail.chapters[1].title, '变量与类型');
  });

  test('ChapterContent 解析', () {
    final chapter = ChapterContent.fromJson(<String, dynamic>{
      'slug': 'hello-world',
      'course_slug': 'go-basics',
      'title': 'Hello World',
      'content_md': '# Hello\n```go\nfmt.Println("hi")\n```',
      'updated_at': '2026-10-14T12:00:00Z',
    });
    expect(chapter.courseSlug, 'go-basics');
    expect(chapter.contentMd, contains('fmt.Println'));
  });

  test('ReadRecord 列表解析（跳过非对象元素）', () {
    final records = ReadRecord.listFromJson(<Object?>[
      <String, dynamic>{
        'courseSlug': 'go-basics',
        'courseTitle': 'Go 语言入门',
        'chapterSlug': 'hello-world',
        'chapterTitle': 'Hello World',
        'readAt': '2026-10-16T04:00:00Z',
      },
      '非对象元素应被跳过',
    ]);
    expect(records.length, 1);
    expect(records.first.courseSlug, 'go-basics');
    expect(records.first.courseTitle, 'Go 语言入门');
    expect(records.first.chapterSlug, 'hello-world');
    expect(records.first.readAt, isNotNull);
  });

  test('ReadRecord 缺字段兜底', () {
    final record = ReadRecord.fromJson(<String, dynamic>{});
    expect(record.courseSlug, '');
    expect(record.readAt, isNull);
  });

  test('AppRelease 解析（force 缺省 false）', () {
    final release = AppRelease.fromJson(<String, dynamic>{
      'version': '1.1.0',
      'versionCode': 2,
      'notes': '新增登录与云同步',
      'apkUrl': 'http://192.168.31.169:8090/apk/app-1.1.0.apk',
      'force': true,
      'releasedAt': '2026-10-15T10:00:00Z',
    });
    expect(release.version, '1.1.0');
    expect(release.versionCode, 2);
    expect(release.force, isTrue);

    final minimal = AppRelease.fromJson(<String, dynamic>{
      'version': '1.0.1',
      'versionCode': 2,
      'notes': '',
      'apkUrl': '',
    });
    expect(minimal.force, isFalse);
    expect(minimal.releasedAt, isNull);
  });

  test('AuthUser 解析', () {
    final user = AuthUser.fromJson(<String, dynamic>{
      'id': 7,
      'username': 'alice',
      'createdAt': '2026-10-01T08:00:00Z',
    });
    expect(user.id, 7);
    expect(user.username, 'alice');
    expect(user.createdAt, isNotNull);
  });
}
