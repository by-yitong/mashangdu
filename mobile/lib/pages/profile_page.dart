import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_store.dart';
import '../state/library_store.dart';
import '../state/progress_store.dart';
import '../widgets/design.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'settings_page.dart';

/// 个人页：开放式头部（头像 + 登录态）→ 三格阅读数据 → 功能入口组 →
/// 设置入口。设置本体在外观/关于等低频项，收进 [SettingsPage] 子页。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topPadding = MediaQuery.paddingOf(context).top + 12;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 120),
      children: [
        Text(
          '我的',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 16),
        const _ProfileHeader(),
        const SizedBox(height: 14),
        const _StatsCard(),
        const SizedBox(height: 14),
        const _EntriesCard(),
        const SizedBox(height: 14),
        const _SettingsEntryCard(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Center(
            child: Text(
              '码上读 · 内容在线更新，支持离线阅读',
              style: TextStyle(fontSize: 13, color: colors.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// 头部：头像（用户名首字 / 未登录人形图标）+ 名称 + 状态行。
/// 未登录整卡可点进登录页；已登录头像右侧放退出（低频，收在头部角落）。
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = context.watch<AuthStore>();
    final user = auth.user;
    final loggedIn = auth.isLoggedIn && user != null;

    Widget avatar = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.accentDim,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: loggedIn
          ? Text(
              user.username.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            )
          : Icon(Icons.person_rounded, size: 28, color: colors.accent),
    );

    return DesignCard(
      onTap: loggedIn ? null : () => _openLogin(context),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loggedIn ? user.username : '未登录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  loggedIn ? '观看历史已云同步' : '点击登录，多设备同步观看记录',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!loggedIn) ...[
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.inkMuted),
          ] else ...[
            TextButton(
              onPressed: () => context.read<AuthStore>().logout(),
              style: TextButton.styleFrom(
                foregroundColor: colors.inkMuted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
              ),
              child: const Text('退出', style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }
}

/// 三格阅读数据：已读章节 / 在学课程 / 课程总数（真实数据，无编造指标）。
class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final progress = context.watch<ProgressStore>();

    var readChapters = 0;
    var learningCourses = 0;
    for (final course in library.courses) {
      final read = progress.readCount(course.slug);
      readChapters += read;
      if (courseStatusFor(read, course.chapterCount) ==
          CourseStatus.learning) {
        learningCourses++;
      }
    }
    final total = library.courses.length;

    return DesignCard(
      child: Row(
        children: [
          _StatValue(value: readChapters, label: '已读章节'),
          _StatDivider(),
          _StatValue(value: learningCourses, label: '在学课程'),
          _StatDivider(),
          _StatValue(value: total, label: '课程总数'),
        ],
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          MonoText('$value', color: colors.accent, fontSize: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.of(context).track,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// 功能入口组：观看历史（登录与否都可用，页内分本地/云端）。
class _EntriesCard extends StatelessWidget {
  const _EntriesCard();

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: _EntryRow(
        icon: Icons.history_rounded,
        label: '观看历史',
        hint: '本地 / 云端',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const HistoryPage())),
      ),
    );
  }
}

/// 设置入口：外观、关于与更新都在设置子页。
class _SettingsEntryCard extends StatelessWidget {
  const _SettingsEntryCard();

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: _EntryRow(
        icon: Icons.tune_rounded,
        label: '设置',
        hint: '外观 · 关于 · 更新',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ),
            Text(
              hint,
              style: TextStyle(fontSize: 12, color: colors.inkMuted),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18, color: colors.inkMuted),
          ],
        ),
      ),
    );
  }
}
