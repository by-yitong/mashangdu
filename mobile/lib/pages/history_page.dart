import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/api_client.dart';
import '../state/auth_store.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../utils/relative_time.dart';
import '../widgets/design.dart';
import 'course_page.dart';
import 'login_page.dart';

/// 观看历史页。
///
/// - 未登录：顶部「登录后云同步」引导卡 + 本地最近阅读
///   （ProgressStore 每门课的最后阅读章节，时间列显示 '—'）；
/// - 已登录：GET /api/v1/records 的云端记录（下拉刷新），
///   条目 = 课程名 / 章节名 / 相对时间，点击进入对应章节；
///   AppBar 右上「清空」→ 确认对话框 → DELETE /api/v1/records。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ReadRecord>? _records;

  /// 仅在请求真正在途时为 true。初始必须为 false——首次加载由
  /// initState 的首帧回调触发；初始为 true 时 build 里的 `!_loading`
  /// 条件永远不满足，请求发不出去、转圈死锁（已踩过）。
  bool _loading = false;
  Object? _error;

  /// 本次登录会话是否已自动加载过。防止错误态下每次重建都重新调度
  /// _load（无限重试风暴）；出错后由用户下拉重试。
  bool _autoLoaded = false;

  @override
  void initState() {
    super.initState();
    // 首帧后发起首次加载（initState 里不能读 inherited，走 post-frame）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.read<AuthStore>().isLoggedIn) return;
      _autoLoaded = true;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = _records == null;
      _error = null;
    });
    try {
      final records = await context.read<ApiClient>().fetchRecords();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '网络不可用';
        _loading = false;
      });
    }
  }

  /// 登录态从无到有时（如从引导卡去登录后返回）自动拉取云端记录。
  void _scheduleLoadIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoLoaded || _loading || _records != null) return;
      if (!context.read<AuthStore>().isLoggedIn) return;
      _autoLoaded = true;
      _load();
    });
  }

  Future<void> _confirmClear() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: const Text('清空观看历史'),
        content: const Text('将删除服务器上的全部观看记录，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '清空',
              style: TextStyle(color: colors.accent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<ApiClient>().clearRecords();
      if (!mounted) return;
      setState(() => _records = const []);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.isEmpty ? '清空失败' : error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络不可用，清空失败')));
    }
  }

  /// 跳转对应章节：照首页「继续阅读」卡的跳法（CoursePage + openChapterSlug），
  /// 课程信息优先取 LibraryStore 已同步列表，缺失时用记录里的 slug/标题兜底。
  void _openRecord(String courseSlug, String courseTitle, String chapterSlug) {
    CourseSummary? course;
    for (final cached in context.read<LibraryStore>().courses) {
      if (cached.slug == courseSlug) {
        course = cached;
        break;
      }
    }
    course ??= CourseSummary(
      slug: courseSlug,
      title: courseTitle,
      summary: '',
      language: '',
      color: '',
      chapterCount: 0,
      updatedAt: null,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePage(course: course!, openChapterSlug: chapterSlug),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = context.watch<AuthStore>();
    final loggedIn = auth.isLoggedIn;
    if (loggedIn && _records == null && !_loading && !_autoLoaded) {
      _scheduleLoadIfNeeded();
    }
    if (!loggedIn && _records != null) {
      // 注销/登录失效后丢弃上一账号的云端记录，回到本地视图；
      // 重新登录后允许再次自动加载。
      _records = null;
      _loading = false;
      _error = null;
      _autoLoaded = false;
    }

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          if (loggedIn)
            IconButton(
              tooltip: '清空历史',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: loggedIn
          ? _buildCloudList(colors)
          : RefreshIndicator(
              color: colors.accent,
              backgroundColor: colors.card,
              onRefresh: () async {},
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _SyncGuideCard(onGoLogin: _openLogin),
                  const SizedBox(height: 14),
                  ..._buildLocalList(colors),
                ],
              ),
            ),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  // —— 未登录：本地最近阅读 ——

  List<Widget> _buildLocalList(AppColors colors) {
    final progress = context.watch<ProgressStore>();
    final library = context.watch<LibraryStore>();
    final courses = library.courses
        .where((course) => progress.lastChapter(course.slug) != null)
        .toList();
    if (courses.isEmpty) {
      return [_EmptyCard(text: '还没有本地阅读记录\n打开一门课程开始阅读吧')];
    }
    return [
      for (final course in courses)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RecordCard(
            courseTitle: course.title,
            chapterTitle: progress.lastChapterTitle(course.slug) ?? '',
            time: '—',
            onTap: () => _openRecord(
              course.slug,
              course.title,
              progress.lastChapter(course.slug) ?? '',
            ),
          ),
        ),
    ];
  }

  // —— 已登录：云端记录 ——

  Widget _buildCloudList(AppColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (_error != null)
            _ErrorCard(message: '$_error，下拉重试')
          else if (_records?.isEmpty ?? true)
            const _EmptyCard(text: '暂无云端观看记录\n打开一章即自动同步到这里')
          else
            for (final record in _records!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecordCard(
                  courseTitle: record.courseTitle,
                  chapterTitle: record.chapterTitle,
                  time: relativeTime(record.readAt),
                  onTap: () => _openRecord(
                    record.courseSlug,
                    record.courseTitle,
                    record.chapterSlug,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 未登录时的「登录后云同步」引导卡。
class _SyncGuideCard extends StatelessWidget {
  const _SyncGuideCard({required this.onGoLogin});

  final VoidCallback onGoLogin;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DesignCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.cloud_sync_outlined, size: 22, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '登录后云同步',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '多设备同步观看历史，换机不丢失',
                  style: TextStyle(fontSize: 12, height: 1.4, color: colors.inkMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onGoLogin,
            style: TextButton.styleFrom(foregroundColor: colors.accent),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}

/// 单条历史记录卡：课程名 / 章节名 / 相对时间。
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.courseTitle,
    required this.chapterTitle,
    required this.time,
    required this.onTap,
  });

  final String courseTitle;
  final String chapterTitle;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DesignCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapterTitle.isEmpty ? '未命名章节' : chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  courseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.3, color: colors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 18, color: colors.inkMuted),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DesignCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DesignCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 32, color: colors.inkMuted),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
