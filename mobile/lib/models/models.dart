/// 数据实体与 JSON 解析（对应冻结 API 契约）。
library;

/// GET /api/v1/meta 的 data。
class MetaInfo {
  const MetaInfo({required this.contentVersion, required this.courseCount});

  final String contentVersion;
  final int courseCount;

  factory MetaInfo.fromJson(Map<String, dynamic> json) => MetaInfo(
    contentVersion: json['content_version'] as String? ?? '',
    courseCount: (json['course_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'content_version': contentVersion,
    'course_count': courseCount,
  };

  /// content_version(RFC3339) 的日期部分，如 2026-10-15。
  String get versionDate {
    final parsed = DateTime.tryParse(contentVersion);
    if (parsed == null) return contentVersion;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }
}

/// 课程列表项（GET /api/v1/courses 的元素）。
class CourseSummary {
  const CourseSummary({
    required this.slug,
    required this.title,
    required this.summary,
    required this.language,
    required this.color,
    required this.chapterCount,
    required this.updatedAt,
  });

  final String slug;
  final String title;
  final String summary;
  final String language;

  /// 形如 #14B8A6 的十六进制颜色。
  final String color;
  final int chapterCount;
  final DateTime? updatedAt;

  factory CourseSummary.fromJson(Map<String, dynamic> json) => CourseSummary(
    slug: json['slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    language: json['language'] as String? ?? '',
    color: json['color'] as String? ?? '',
    chapterCount: (json['chapter_count'] as num?)?.toInt() ?? 0,
    updatedAt: _parseDate(json['updated_at']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'slug': slug,
    'title': title,
    'summary': summary,
    'language': language,
    'color': color,
    'chapter_count': chapterCount,
    'updated_at': updatedAt?.toIso8601String(),
  };

  static List<CourseSummary> listFromJson(Object? data) =>
      (data as List<Object?>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseSummary.fromJson)
          .toList();
}

/// 课程详情内嵌的章节引用。
class ChapterRef {
  const ChapterRef({
    required this.slug,
    required this.title,
    required this.order,
  });

  final String slug;
  final String title;
  final int order;

  factory ChapterRef.fromJson(Map<String, dynamic> json) => ChapterRef(
    slug: json['slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    order: (json['order'] as num?)?.toInt() ?? 0,
  );
}

/// GET /api/v1/courses/{slug} 的 data。
class CourseDetail {
  const CourseDetail({
    required this.slug,
    required this.title,
    required this.summary,
    required this.language,
    required this.color,
    required this.updatedAt,
    required this.chapters,
  });

  final String slug;
  final String title;
  final String summary;
  final String language;
  final String color;
  final DateTime? updatedAt;
  final List<ChapterRef> chapters;

  factory CourseDetail.fromJson(Map<String, dynamic> json) => CourseDetail(
    slug: json['slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    language: json['language'] as String? ?? '',
    color: json['color'] as String? ?? '',
    updatedAt: _parseDate(json['updated_at']),
    chapters: (json['chapters'] as List<Object?>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChapterRef.fromJson)
        .toList(),
  );
}

/// GET /api/v1/courses/{slug}/chapters/{chapterSlug} 的 data。
class ChapterContent {
  const ChapterContent({
    required this.slug,
    required this.courseSlug,
    required this.title,
    required this.contentMd,
    required this.updatedAt,
  });

  final String slug;
  final String courseSlug;
  final String title;
  final String contentMd;
  final DateTime? updatedAt;

  factory ChapterContent.fromJson(Map<String, dynamic> json) => ChapterContent(
    slug: json['slug'] as String? ?? '',
    courseSlug: json['course_slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    contentMd: json['content_md'] as String? ?? '',
    updatedAt: _parseDate(json['updated_at']),
  );
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
