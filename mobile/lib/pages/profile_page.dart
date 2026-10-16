import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/api_client.dart';
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

/// 头部：头像（网络头像 / 用户名首字 / 未登录人形图标）+ 名称 + 状态行。
/// 未登录整卡可点进登录页；已登录头像可点换头像（拍照 / 相册 → 裁切 →
/// 上传），头像右侧放退出（低频，收在头部角落）。
class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader();

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  /// 头像上传中：头像上盖转圈，避免重复点击。
  bool _uploading = false;

  /// 裁切页 toolbar 用 App 主题青色系（design token：深色档 accent）。
  static const Color _cropToolbarColor = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = context.watch<AuthStore>();
    final user = auth.user;
    final loggedIn = auth.isLoggedIn && user != null;

    Widget placeholder = Container(
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

    // 有头像：网络图（相对路径经 resolve 拼绝对），加载失败回退占位。
    Widget avatar = placeholder;
    if (loggedIn && user.avatar.isNotEmpty) {
      final url = context.read<ApiClient>().resolve(user.avatar);
      avatar = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.track),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Image.network(
            url,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          ),
        ),
      );
    }

    if (_uploading) {
      avatar = Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.paper.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
            ),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: colors.accent,
              ),
            ),
          ),
        ],
      );
    }

    return DesignCard(
      onTap: loggedIn ? null : () => _openLogin(context),
      child: Row(
        children: [
          // 已登录：头像外圈可点换头像；未登录整卡可点，头像不单独响应。
          GestureDetector(
            onTap: (loggedIn && !_uploading)
                ? () => _showAvatarSourceSheet(context)
                : null,
            child: avatar,
          ),
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

  // —— 换头像：选图面板 → 裁切 → 上传 ——

  /// 换头像来源面板（仪表盘卡片风格：圆角 + 细描边选项行）。
  void _showAvatarSourceSheet(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget option(IconData icon, String label, VoidCallback onTap) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: colors.paper,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.track),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 22, color: colors.accent),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.track,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  option(
                    Icons.photo_camera_outlined,
                    '拍照',
                    () {
                      Navigator.of(sheetContext).pop();
                      _pickAndUpload(ImageSource.camera);
                    },
                  ),
                  option(
                    Icons.photo_library_outlined,
                    '从相册选择',
                    () {
                      Navigator.of(sheetContext).pop();
                      _pickAndUpload(ImageSource.gallery);
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.inkMuted,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 选图 → 1:1 裁切（JPEG 85 / 512px 压缩）→ 上传 → 刷新 user。
  /// 任一步被用户取消则静默结束；上传失败 Snackbar 提示。
  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁切头像',
          toolbarColor: _cropToolbarColor,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _cropToolbarColor,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.6),
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          statusBarLight: false,
          navBarLight: false,
        ),
        IOSUiSettings(title: '裁切头像', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;

    // 依赖先取引用再 await（BuildContext 不跨异步间隙使用）。
    final api = context.read<ApiClient>();
    final auth = context.read<AuthStore>();
    setState(() => _uploading = true);
    try {
      final bytes = await cropped.readAsBytes();
      final user = await api.uploadAvatar(bytes, 'avatar.jpg');
      await auth.applyUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'AVATAR_INVALID'
                ? '图片格式或大小不符合要求（≤5MB，jpeg/png/webp）'
                : (error.message.isEmpty ? '头像上传失败，请稍后重试' : error.message),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络不可用，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
