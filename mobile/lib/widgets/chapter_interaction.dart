import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../pages/login_page.dart';
import '../state/api_client.dart';
import '../state/auth_store.dart';
import '../utils/relative_time.dart' show relativeTime;
import 'reading_theme.dart';

/// 章节末尾互动区：阅读量/点赞数据行 + 评论区（分页）+ 底部输入卡片。
///
/// - 配色全部取 [ReadingTheme]（阅读主题体系），卡片为分隔色浅描边圆角容器；
/// - 挂在正文 sliver 之后随内容滚动（不悬浮），父级按 chapterSlug 挂 key，
///   切章即重挂载、状态重置；
/// - 未登录：点赞/输入引导去 [LoginPage]；点赞乐观更新 + 失败回滚；
/// - 429（COMMENT_TOO_FAST）提示「评论太快啦，休息一下」；
/// - 自基类自管理状态（stats/评论分页），失败静默不影响阅读。
class ChapterInteraction extends StatefulWidget {
  const ChapterInteraction({
    super.key,
    required this.courseSlug,
    required this.chapterSlug,
    required this.theme,
  });

  final String courseSlug;
  final String chapterSlug;

  /// 阅读主题（父级 build 时传入，主题切换即刷新；key 不变则状态保留）。
  final ReadingTheme theme;

  @override
  State<ChapterInteraction> createState() => _ChapterInteractionState();
}

class _ChapterInteractionState extends State<ChapterInteraction>
    with SingleTickerProviderStateMixin {
  ChapterStats _stats = const ChapterStats(
    viewCount: 0,
    likeCount: 0,
    commentCount: 0,
    liked: false,
  );

  List<ChapterComment> _comments = const [];
  int _commentTotal = 0;

  /// 已加载到第几页（0 = 首次加载中/未加载）。
  int _commentLoadedPages = 0;

  /// 服务端返回的总页数。
  int _commentPageCount = 0;

  bool _commentsLoading = false;
  bool _likeBusy = false;
  bool _sending = false;

  final TextEditingController _input = TextEditingController();

  /// 点赞按钮缩放动画（点一下 1 → 1.22 → 回弹到 1）；控制器 0..1 对应
  /// 缩放 1..1.22，静止在 0（即原尺寸）。
  late final AnimationController _likeScale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    // 播完自动回弹，动画结束后停在原尺寸。
    _likeScale.addStatusListener(_onLikeScaleStatus);
    // 输入内容变化时刷新发送按钮的点亮态。
    _input.addListener(_onInputChanged);
    _loadInitial();
  }

  void _onLikeScaleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _likeScale.reverse();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _likeScale.removeStatusListener(_onLikeScaleStatus);
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _likeScale.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    // stats 与评论首页各自失败互不影响。
    final api = context.read<ApiClient>();
    try {
      final stats = await api.fetchChapterStats(
        widget.courseSlug,
        widget.chapterSlug,
      );
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (_) {
      // 离线/失败：保持默认值，互动区仍可用（操作失败各自兜底）。
    }
    await _loadComments();
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    final nextPage = _commentLoadedPages + 1;
    setState(() => _commentsLoading = true);
    try {
      final page = await context.read<ApiClient>().fetchComments(
        widget.courseSlug,
        widget.chapterSlug,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        // 首页覆盖（重试场景），追加页拼接；最新在前由服务端保证。
        _comments = nextPage == 1
            ? page.comments
            : [..._comments, ...page.comments];
        _commentTotal = page.total;
        _commentLoadedPages = page.page;
        _commentPageCount = page.pageCount;
      });
    } catch (_) {
      // 静默：评论加载失败保持现状，用户可下拉重进重试。
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  // —— 点赞：乐观更新 + 失败回滚 ——

  Future<void> _toggleLike() async {
    final auth = context.read<AuthStore>();
    if (!auth.isLoggedIn) {
      _goLogin();
      return;
    }
    if (_likeBusy) return;
    final before = _stats;
    final target = !before.liked;
    _likeScale.forward(from: 0);
    setState(() {
      _stats = before.copyWith(
        liked: target,
        likeCount: before.likeCount + (target ? 1 : -1),
      );
    });
    _likeBusy = true;
    try {
      final result = await context.read<ApiClient>().setLike(
        widget.courseSlug,
        widget.chapterSlug,
        target,
      );
      if (!mounted) return;
      setState(() {
        _stats = _stats.copyWith(liked: result.liked, likeCount: result.likeCount);
      });
    } catch (_) {
      // 失败回滚到点击前的服务端真值。
      if (!mounted) return;
      setState(() => _stats = before);
      _snack('操作失败，请稍后重试');
    } finally {
      _likeBusy = false;
    }
  }

  // —— 评论：发送 / 删除 ——

  Future<void> _sendComment() async {
    final auth = context.read<AuthStore>();
    if (!auth.isLoggedIn) {
      _goLogin();
      return;
    }
    final content = _input.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await context.read<ApiClient>().addComment(
        widget.courseSlug,
        widget.chapterSlug,
        content,
      );
      if (!mounted) return;
      setState(() {
        _comments = [comment, ..._comments];
        _commentTotal += 1;
        _stats = _stats.copyWith(
          commentCount: _stats.commentCount + 1,
        );
      });
      _input.clear();
    } on ApiException catch (error) {
      if (!mounted) return;
      _snack(
        error.code == 'COMMENT_TOO_FAST'
            ? '评论太快啦，休息一下'
            : (error.code == 'COMMENT_INVALID_INPUT'
                  ? '评论内容需 1-1000 字'
                  : (error.message.isEmpty ? '评论失败，请稍后重试' : error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      _snack('网络不可用，请稍后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(ChapterComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.theme.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: widget.theme.divider),
        ),
        title: Text(
          '删除评论',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: widget.theme.text,
          ),
        ),
        content: Text(
          '删除后不可恢复，确定删除这条评论吗？',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: widget.theme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: widget.theme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: widget.theme.accent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != comment.id).toList();
        if (_commentTotal > 0) _commentTotal -= 1;
        if (_stats.commentCount > 0) {
          _stats = _stats.copyWith(commentCount: _stats.commentCount - 1);
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _snack(
        error.code == 'COMMENT_FORBIDDEN'
            ? '只能删除自己的评论'
            : (error.message.isEmpty ? '删除失败，请稍后重试' : error.message),
      );
    } catch (_) {
      if (!mounted) return;
      _snack('网络不可用，请稍后重试');
    }
  }

  void _goLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // —— 构建 ——

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final auth = context.watch<AuthStore>();
    final myUserId = auth.isLoggedIn ? auth.user?.id : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsRow(theme),
        const SizedBox(height: 14),
        _buildCommentsCard(theme, myUserId),
        const SizedBox(height: 14),
        _buildInputCard(theme, auth.isLoggedIn),
      ],
    );
  }

  /// 卡片容器：分隔色浅描边圆角容器（阅读主题体系内配色）。
  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: widget.theme.bg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: widget.theme.divider),
    ),
    child: child,
  );

  /// 数据行：阅读 N 次 · N 人觉得有用 · N 条评论 + 右侧点赞按钮。
  Widget _buildStatsRow(ReadingTheme theme) {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '阅读 ${_stats.viewCount} 次 · ${_stats.likeCount} 人觉得有用 · '
              '${_stats.commentCount} 条评论',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: theme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _LikeButton(
            liked: _stats.liked,
            likeCount: _stats.likeCount,
            scale: _likeScale,
            theme: theme,
            onTap: _toggleLike,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCard(ReadingTheme theme, int? myUserId) {
    final hasMore = _commentLoadedPages > 0 && _commentLoadedPages < _commentPageCount;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _commentLoadedPages > 0 ? '评论 ($_commentTotal)' : '评论',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 6),
          if (_comments.isEmpty && !_commentsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  '还没有评论，点击下方输入框抢沙发',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.textSecondary,
                  ),
                ),
              ),
            ),
          for (final comment in _comments)
            _CommentTile(
              comment: comment,
              isMine: comment.userId == myUserId,
              theme: theme,
              avatarUrl: comment.avatar.isEmpty
                  ? null
                  : context.read<ApiClient>().resolve(comment.avatar),
              onDelete: () => _deleteComment(comment),
            ),
          if (_commentsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: theme.accent,
                  ),
                ),
              ),
            ),
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: _commentsLoading ? null : _loadComments,
                style: TextButton.styleFrom(
                  foregroundColor: theme.accent,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('加载更多'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputCard(ReadingTheme theme, bool loggedIn) {
    if (!loggedIn) {
      // 未登录：整卡可点，引导去登录页（与历史页云端引导同模式）。
      return _card(
        padding: const EdgeInsets.all(0),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _goLogin,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: theme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '登录后参与评论',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return _card(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_sending,
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
              cursorColor: theme.accent,
              style: TextStyle(fontSize: 14, color: theme.text),
              decoration: InputDecoration(
                counterText: '',
                hintText: '写下你的想法…',
                hintStyle: TextStyle(fontSize: 14, color: theme.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          _SendButton(
            theme: theme,
            busy: _sending,
            enabled: _input.text.trim().isNotEmpty,
            onTap: _sendComment,
          ),
        ],
      ),
    );
  }
}

/// 点赞按钮：点赞态实心 + 主题强调色；未赞描边；点击缩放动画。
class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.likeCount,
    required this.scale,
    required this.theme,
    required this.onTap,
  });

  final bool liked;
  final int likeCount;
  final Animation<double> scale;
  final ReadingTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = theme.accentTint(0.14);
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.22).animate(
        CurvedAnimation(parent: scale, curve: Curves.easeOutBack),
      ),
      child: Material(
        color: liked ? fill : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: liked ? theme.accent : theme.divider,
                width: liked ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  size: 18,
                  color: liked ? theme.accent : theme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: liked ? theme.accent : theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 发送按钮：发送中转圈，否则纸飞机图标；空文案置灰。
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.theme,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final ReadingTheme theme;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled || busy;
    return IconButton(
      onPressed: busy ? null : onTap,
      icon: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: theme.accent,
              ),
            )
          : Icon(
              Icons.send_rounded,
              size: 20,
              color: active ? theme.accent : theme.textSecondary.withValues(alpha: 0.5),
            ),
    );
  }
}

/// 评论条目：头像(30px 圆形) + 用户名 + 时间 + 内容；自己的评论带删除入口。
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.theme,
    required this.avatarUrl,
    required this.onDelete,
  });

  final ChapterComment comment;
  final bool isMine;
  final ReadingTheme theme;
  final String? avatarUrl;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentAvatar(
            username: comment.username,
            url: avatarUrl,
            theme: theme,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondary,
                      ),
                    ),
                    if (isMine) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: theme.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: theme.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 评论头像：30px 圆形；网络图加载失败/无头像回退首字母占位。
class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.username,
    required this.url,
    required this.theme,
  });

  final String username;
  final String? url;
  final ReadingTheme theme;

  @override
  Widget build(BuildContext context) {
    final letter = username.isEmpty
        ? '?'
        : username.characters.first.toUpperCase();
    final fallback = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.accentTint(0.14),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: theme.accent,
        ),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
