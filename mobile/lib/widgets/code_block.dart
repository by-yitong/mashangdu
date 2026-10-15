import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// markdown 是 flutter_markdown 的传递依赖；白名单限制下不直接加入 pubspec。
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;

import 'design.dart';

/// 代码块：深色圆角容器 + 等宽字体 + 右上角复制按钮（设计固定深底，不随主题）。
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  static const Color _blockBg = Color(0xFF0C0F0E);
  static const Color _blockText = Color(0xFFE6EDEA);

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('代码已复制'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = code.endsWith('\n') ? code.substring(0, code.length - 1) : code;
    final langLabel = (language ?? '').replaceFirst('language-', '');
    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.fromLTRB(14, 34, 14, 14),
          decoration: BoxDecoration(
            color: _blockBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFeatures: [FontFeature.tabularFigures()],
                fontSize: 13,
                height: 1.55,
                color: _blockText,
              ),
            ),
          ),
        ),
        if (langLabel.isNotEmpty)
          Positioned(
            top: 18,
            left: 14,
            child: Text(
              langLabel,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.2,
                color: Color(0xFF8A938E),
              ),
            ),
          ),
        Positioned(
          top: 12,
          right: 8,
          child: IconButton(
            tooltip: '复制代码',
            icon: Icon(Icons.copy_rounded, size: 16, color: colors.inkMuted),
            onPressed: () => _copy(context),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

/// flutter_markdown 自定义 `pre` 元素构建器：把围栏代码块渲染为 [CodeBlock]。
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final codeChild = element.children;
    final language = codeChild != null && codeChild.isNotEmpty
        ? (codeChild.first as md.Element?)?.attributes['class']
        : null;
    return CodeBlock(
      code: element.textContent,
      language: language,
    );
  }
}
