import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/api_client.dart';
import '../state/settings_store.dart';
import '../widgets/design.dart';

/// 设置页：服务器地址（http/https 校验）+ 保存 + 测试连接。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _inputError;

  /// 测试连接结果：null=未测试；success=false 时 message 为错误。
  bool? _testSuccess;
  String _testMessage = '';

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: context.read<SettingsStore>().serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsStore>();
    final ok = await settings.setServerUrl(_urlController.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _inputError = '地址必须以 http:// 或 https:// 开头';
        _testSuccess = null;
        _testMessage = '';
      });
      return;
    }
    setState(() {
      _inputError = null;
      _testSuccess = true;
      _testMessage = '已保存服务器地址：${settings.serverUrl}';
    });
  }

  Future<void> _testConnection() async {
    final settings = context.read<SettingsStore>();
    final api = context.read<ApiClient>();

    // 先保存当前输入框的合法地址，再对它做连接测试。
    final saved = await settings.setServerUrl(_urlController.text);
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _inputError = '地址必须以 http:// 或 https:// 开头';
        _testSuccess = false;
        _testMessage = '请输入以 http:// 或 https:// 开头的地址';
      });
      return;
    }

    setState(() {
      _inputError = null;
      _testing = true;
    });
    String message;
    bool success;
    try {
      final meta = await api.fetchMeta();
      success = true;
      message = '连接成功 · 内容版本 ${meta.versionDate} · ${meta.courseCount} 门课程';
    } catch (error) {
      success = false;
      message = '连接失败：$error';
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSuccess = success;
      _testMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = context.watch<SettingsStore>();
    final topPadding = MediaQuery.paddingOf(context).top + 12;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 120),
      children: [
        Text(
          '设置',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '当前服务器：${settings.serverUrl}',
            style: TextStyle(fontSize: 13, height: 1.3, color: colors.inkMuted),
          ),
        ),
        const SizedBox(height: 16),
        DesignCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '服务器地址',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Golang 后端 API 地址，默认 ${SettingsStore.defaultServerUrl}',
                style:
                    TextStyle(fontSize: 12, height: 1.4, color: colors.inkMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                style: MonoText.monoBase.copyWith(
                  fontSize: 14,
                  color: colors.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'http://10.0.2.2:8080',
                  hintStyle: MonoText.monoBase
                      .copyWith(fontSize: 14, color: colors.inkMuted),
                  errorText: _inputError,
                  filled: true,
                  fillColor: colors.paper,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.track),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.track),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accent,
                        side: BorderSide(color: colors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_rounded, size: 18),
                      label: const Text('测试连接'),
                    ),
                  ),
                ],
              ),
              if (_testMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color:
                          _testSuccess == true ? colors.accent : colors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _testMessage,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _testSuccess == true
                              ? colors.accent
                              : colors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
