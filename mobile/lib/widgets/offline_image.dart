import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../state/image_cache_store.dart';
import 'design.dart';

/// Markdown 图片：本地已有直接显示，缺失则尝试下载后显示；
/// 下载中/失败/不可下载一律显示同款占位（card 底 + alt 文本 + 图片图标）。
/// 已加载的图片可点击进入全屏查看器（双指缩放 / 双击放大 / 点按关闭）。
/// SVG 走 flutter_svg 分支渲染，且一律垫白底（课程图解按白底设计、
/// 深色线条 + 透明背景，直接铺深色卡片上会看不清）。
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

  /// 是否按 SVG 渲染：以 markdown 原文 url 的后缀为准
  /// （落盘文件名保留原文后缀，两者一致）。
  bool get _isSvg => widget.url.toLowerCase().endsWith('.svg');

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

  void _openViewer() {
    final file = _file;
    if (file == null) return;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: _ImageViewerPage(file: file, alt: widget.alt, isSvg: _isSvg),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final file = _file;
    if (file == null) return _placeholder(colors);
    return GestureDetector(
      onTap: _openViewer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: _isSvg
            ? Container(
                // 白底容器把宽度收紧成满宽，SvgPicture 内部的 FittedBox
                // 在「宽受限、高不受限」下按 viewBox 等比给高，
                // 与位图 Image(width: infinity, fit: fitWidth) 观感一致。
                width: double.infinity,
                color: Colors.white,
                child: SvgPicture.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _placeholder(colors),
                ),
              )
            : Image.file(
                file,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _placeholder(colors),
              ),
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

/// 全屏图片查看器：黑底、双指缩放（0.6~5x）、双击在 1x/2.5x 间切换、
/// 单击关闭、右上角关闭按钮。基于官方 InteractiveViewer，无额外依赖。
/// SVG 单独分支：深色线条在纯黑背景上不可见，改用白底圆角容器承载。
class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({
    required this.file,
    required this.alt,
    required this.isSvg,
  });

  final File file;
  final String alt;
  final bool isSvg;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage>
    with TickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 双击缩放：以点击点为中心，在 1x 与 2.5x 之间切换。
  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final current = _controller.value.getMaxScaleOnAxis();
    final target = current > 1.05 ? 1.0 : 2.5;
    final Matrix4 end;
    if (target == 1.0) {
      end = Matrix4.identity();
    } else {
      end = Matrix4.identity()
        ..translateByDouble(-position.dx * (target - 1), -position.dy * (target - 1), 0.0, 1.0)
        ..scaleByDouble(target, target, 1.0, 1.0);
    }
    _animateMatrix(_controller.value.clone(), end);
  }

  void _animateMatrix(Matrix4 start, Matrix4 end) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    final tween = Matrix4Tween(begin: start, end: end);
    late final Animation<double> curve;
    curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    void listener() {
      _controller.value = tween.transform(curve.value);
    }

    curve.addListener(listener);
    controller.forward().whenComplete(() {
      curve.removeListener(listener);
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              // 双击与单击共存：arena 自动让双击优先，单击延迟约 300ms。
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 0.6,
                maxScale: 5.0,
                panEnabled: true,
                constrained: true,
                child: Center(
                  // SVG：白底圆角容器随内容等比收缩（Center 放宽约束后
                  // FittedBox 按 viewBox 尺寸夹紧到屏幕内），黑底只露边框。
                  child: widget.isSvg
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            color: Colors.white,
                            child: SvgPicture.file(
                              widget.file,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Image.file(
                          widget.file,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: IconButton(
                    tooltip: '关闭',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: IgnorePointer(
                    child: Text(
                      '双指缩放 · 双击放大 · 点击关闭',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
