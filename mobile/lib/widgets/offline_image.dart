import 'dart:io';

import 'package:flutter/material.dart';

import '../state/image_cache_store.dart';
import 'design.dart';

/// Markdown 图片：本地已有直接显示，缺失则尝试下载后显示；
/// 下载中/失败/不可下载一律显示同款占位（card 底 + alt 文本 + 图片图标）。
/// [url] 是 markdown 里的原文（相对路径或绝对 URL），落盘与去重都按原文；
/// [resolver] 由调用方注入（一般传 `(raw) => context.read<ApiClient>().resolve(raw)`），
/// 负责把原文拼成可下载地址。落盘路径规则与 DownloadStore 共用 ImageCacheStore。
class OfflineImage extends StatefulWidget {
  const OfflineImage({
    super.key,
    required this.url,
    required this.alt,
    required this.resolver,
  });

  final String url;
  final String alt;
  final String Function(String raw) resolver;

  @override
  State<OfflineImage> createState() => _OfflineImageState();
}

class _OfflineImageState extends State<OfflineImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant OfflineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  Future<void> _resolve() async {
    if (!ImageCacheStore.isDownloadable(widget.url)) return;
    try {
      final file = await ImageCacheStore.fileFor(widget.url);
      if (await file.exists()) {
        if (mounted) setState(() => _file = file);
        return;
      }
      await ImageCacheStore.ensureDownloaded(
        widget.url,
        widget.resolver(widget.url),
      );
      if (mounted) setState(() => _file = file);
    } catch (_) {
      // 下载失败保持占位，下次进入正文或重连后会再尝试。
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final file = _file;
    if (file == null) return _placeholder(colors);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.file(
        file,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(colors),
      ),
    );
  }

  Widget _placeholder(AppColors colors) => Container(
    height: 180,
    width: double.infinity,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 28, color: colors.inkMuted),
        const SizedBox(height: 8),
        Text(
          widget.alt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, color: colors.inkMuted),
        ),
      ],
    ),
  );
}
