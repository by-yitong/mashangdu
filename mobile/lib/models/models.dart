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

/// POST /api/v1/auth/register|login 返回 data 里的 user。
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.avatar = '',
    this.createdAt,
  });

  final int id;
  final String username;

  /// 头像相对路径（如 /avatars/xx.jpg），空串 = 无头像；展示时经
  /// ApiClient.resolve 拼成绝对 URL。
  final String avatar;
  final DateTime? createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: json['username'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    createdAt: _parseDate(json['createdAt']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'username': username,
    'avatar': avatar,
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// 登录/注册成功后的会话（token + 用户）。
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// GET /api/v1/records 返回 data.records 的元素（云端观看历史）。
class ReadRecord {
  const ReadRecord({
    required this.courseSlug,
    required this.courseTitle,
    required this.chapterSlug,
    required this.chapterTitle,
    required this.readAt,
  });

  final String courseSlug;
  final String courseTitle;
  final String chapterSlug;
  final String chapterTitle;
  final DateTime? readAt;

  factory ReadRecord.fromJson(Map<String, dynamic> json) => ReadRecord(
    courseSlug: json['courseSlug'] as String? ?? '',
    courseTitle: json['courseTitle'] as String? ?? '',
    chapterSlug: json['chapterSlug'] as String? ?? '',
    chapterTitle: json['chapterTitle'] as String? ?? '',
    readAt: _parseDate(json['readAt']),
  );

  static List<ReadRecord> listFromJson(Object? data) =>
      (data as List<Object?>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReadRecord.fromJson)
          .toList();
}

/// GET /api/v1/app/latest 的 data（新版 APK 信息）。
class AppRelease {
  const AppRelease({
    required this.version,
    required this.versionCode,
    required this.notes,
    required this.apkUrl,
    required this.force,
    this.releasedAt,
  });

  final String version;

  /// 与 Android versionCode（buildNumber）比较判断是否更新。
  final int versionCode;
  final String notes;
  final String apkUrl;
  final bool force;
  final DateTime? releasedAt;

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    version: json['version'] as String? ?? '',
    versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String? ?? '',
    apkUrl: json['apkUrl'] as String? ?? '',
    force: json['force'] as bool? ?? false,
    releasedAt: _parseDate(json['releasedAt']),
  );
}

/// GET /api/v1/courses/{c}/chapters/{ch}/stats 的 data。
class ChapterStats {
  const ChapterStats({
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
  });

  final int viewCount;
  final int likeCount;
  final int commentCount;

  /// 当前登录用户是否已点赞（未登录恒为 false）。
  final bool liked;

  factory ChapterStats.fromJson(Map<String, dynamic> json) => ChapterStats(
    viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    liked: json['liked'] as bool? ?? false,
  );

  ChapterStats copyWith({
    int? viewCount,
    int? likeCount,
    int? commentCount,
    bool? liked,
  }) => ChapterStats(
    viewCount: viewCount ?? this.viewCount,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    liked: liked ?? this.liked,
  );
}

/// 章节 / 评论相关字段（camelCase，对应冻结契约）。
class ChapterComment {
  const ChapterComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String username;

  /// 头像相对路径，空串 = 无头像。
  final String avatar;
  final String content;
  final DateTime? createdAt;

  factory ChapterComment.fromJson(Map<String, dynamic> json) => ChapterComment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    username: json['username'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt: _parseDate(json['createdAt']),
  );

  /// 防御式列表解析（同 ReadRecord.listFromJson：跳过非 Map 元素）。
  static List<ChapterComment> listFromJson(Object? data) =>
      (data as List<Object?>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChapterComment.fromJson)
          .toList();
}

/// GET /api/v1/courses/{c}/chapters/{ch}/comments 的 data（分页信封）。
class CommentPage {
  const CommentPage({
    required this.comments,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pageCount,
  });

  /// 最新在前。
  final List<ChapterComment> comments;
  final int total;
  final int page;
  final int pageSize;
  final int pageCount;

  factory CommentPage.fromJson(Map<String, dynamic> json) => CommentPage(
    comments: ChapterComment.listFromJson(json['comments']),
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
  );
}
