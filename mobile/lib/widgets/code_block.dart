import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as hl;
// markdown 是 flutter_markdown 的传递依赖；白名单限制下不直接加入 pubspec。
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;

import 'design.dart';

/// 代码块：深色圆角容器 + 语法高亮 + 右上角复制按钮（设计固定深底，不随主题）。
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.fontSize = 13,
  });

  final String code;
  final String? language;

  /// 代码字号（阅读字号档位：13 / 14 / 15）。
  final double fontSize;

  static const Color _blockBg = Color(0xFF0C0F0E);
  static const Color _plainText = Color(0xFFE6EDEA);

  /// One Dark 风格高亮配色（编辑器惯例配色，与主题色无关）。
  static const Map<String, Color> _palette = {
    'root': _plainText,
    'comment': Color(0xFF7F848E),
    'quote': Color(0xFF7F848E),
    'keyword': Color(0xFFC678DD),
    'selector-tag': Color(0xFFC678DD),
    'literal': Color(0xFFC678DD),
    'section': Color(0xFFC678DD),
    'doctag': Color(0xFFC678DD),
    'name': Color(0xFFE06C75),
    'tag': Color(0xFFE06C75),
    'deletion': Color(0xFFE06C75),
    'symbol': Color(0xFF56B6C2),
    'bullet': Color(0xFF56B6C2),
    'meta': Color(0xFF56B6C2),
    'link': Color(0xFF56B6C2),
    'string': Color(0xFF98C379),
    'addition': Color(0xFF98C379),
    'regexp': Color(0xFF98C379),
    'attribute': Color(0xFFD19A66),
    'number': Color(0xFFD19A66),
    'variable': Color(0xFFD19A66),
    'template-variable': Color(0xFFD19A66),
    'type': Color(0xFFD19A66),
    'class': Color(0xFFD19A66),
    'built_in': Color(0xFFE5C07B),
    'builtin-name': Color(0xFFE5C07B),
    'params': Color(0xFFE6EDEA),
    'title': Color(0xFF61AFEF),
    'title.class': Color(0xFFE5C07B),
    'title.function': Color(0xFF61AFEF),
    'attr': Color(0xFFD19A66),
    'selector-attr': Color(0xFFC678DD),
    'selector-class': Color(0xFFD19A66),
    'selector-id': Color(0xFF61AFEF),
  };

  static const TextStyle _mono = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 13,
    height: 1.55,
  );

  /// 把 highlight 的节点树转成 TextSpan。
  /// highlight 包把颜色标在有 className 的父节点上，文字在 className=null
  /// 的子节点——无 className 时不能填默认色，否则会覆盖继承的颜色。
  static TextSpan _buildSpan(hl.Node node) {
    TextStyle? style;
    if (node.className != null) {
      style = TextStyle(color: _palette[node.className] ?? _plainText);
    }
    if (node.value != null) {
      return TextSpan(text: node.value, style: style);
    }
    return TextSpan(
      style: style,
      children: node.children?.map(_buildSpan).toList(),
    );
  }

  /// 支持高亮的语言及围栏标记别名映射。
  static const Map<String, String> _languageAliases = {
    'go': 'go',
    'golang': 'go',
    'python': 'python',
    'py': 'python',
    'javascript': 'javascript',
    'js': 'javascript',
    'typescript': 'typescript',
    'ts': 'typescript',
    'sql': 'sql',
    'rust': 'rust',
    'rs': 'rust',
    'java': 'java',
    'dart': 'dart',
    'bash': 'bash',
    'sh': 'bash',
    'shell': 'bash',
    'json': 'json',
    'yaml': 'yaml',
    'yml': 'yaml',
    'xml': 'xml',
    'html': 'xml',
    'css': 'css',
    'c': 'c',
    'cpp': 'cpp',
  };

  TextSpan _highlight(String text, String? language) {
    final raw = (language ?? '').replaceFirst('language-', '').trim();
    final lang = _languageAliases[raw];
    if (lang != null) {
      try {
        final result = hl.highlight.parse(text, language: lang);
        return TextSpan(children: result.nodes?.map(_buildSpan).toList());
      } catch (_) {
        // 高亮失败时退回纯文本。
      }
    }
    return TextSpan(
      text: text,
      style: const TextStyle(color: _plainText),
    );
  }

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
    final text = code.endsWith('\n')
        ? code.substring(0, code.length - 1)
        : code;
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
            child: Text.rich(
              _highlight(text, language),
              style: _mono.copyWith(fontSize: fontSize),
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
  CodeBlockBuilder({this.fontSize = 13});

  /// 代码字号（阅读字号档位：13 / 14 / 15）。
  final double fontSize;

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
      fontSize: fontSize,
    );
  }
}
