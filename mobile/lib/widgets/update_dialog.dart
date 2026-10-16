import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'design.dart';

/// 更新弹窗：版本号 + 更新日志 + 「浏览器下载」。
///
/// force 更新：标题/文案加强，且不允许关闭（PopScope 拦截返回、
/// 无「稍后再说」按钮）；普通更新可关闭。
Future<void> showUpdateDialog(BuildContext context, AppRelease release) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !release.force,
    builder: (dialogContext) {
      final colors = AppColors.of(dialogContext);
      return PopScope(
        canPop: !release.force,
        child: AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: colors.track),
          ),
          title: Text(
            release.force ? '重要更新：v${release.version}' : '发现新版本 v${release.version}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (release.force) ...[
                Text(
                  '此版本为必装更新，请尽快下载安装。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                release.notes.isEmpty ? '优化体验，修复已知问题。' : release.notes,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
          actions: [
            if (!release.force)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(foregroundColor: colors.inkMuted),
                child: const Text('稍后再说'),
              ),
            FilledButton.icon(
              onPressed: () => _openDownload(dialogContext, release.apkUrl),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('浏览器下载'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openDownload(BuildContext context, String apkUrl) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(apkUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('打开下载链接失败，请稍后重试')),
    );
  }
}
