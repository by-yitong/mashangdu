import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/api_client.dart';
import '../state/auth_store.dart';
import '../widgets/design.dart';

/// 登录/注册页：顶部模式切换 + 单卡片表单。
///
/// 输入风格沿用课程页搜索框（card 底圆角容器 + 无边框输入），
/// 行内校验错误 + 服务端错误 SnackBar；成功后回退上一页。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _AuthMode { login, register }

class _LoginPageState extends State<LoginPage> {
  _AuthMode _mode = _AuthMode.login;

  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3 || text.length > 32) return '用户名需 3-32 个字符';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.length < 6 || text.length > 64) return '密码需 6-64 位';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthStore>();
    final username = _username.text.trim();
    final password = _password.text;
    try {
      if (_mode == _AuthMode.login) {
        await auth.login(username, password);
      } else {
        await auth.register(username, password);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_serverErrorMessage(error))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络不可用，请稍后重试')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _serverErrorMessage(ApiException error) {
    switch (error.code) {
      case 'AUTH_USERNAME_TAKEN':
        return '用户名已存在';
      case 'AUTH_INVALID_CREDENTIALS':
        return '用户名或密码错误';
      default:
        return error.message.isEmpty ? '请求失败，请稍后重试' : error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLogin = _mode == _AuthMode.login;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(title: Text(isLogin ? '登录' : '注册')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SegmentedButton<_AuthMode>(
              segments: const [
                ButtonSegment(value: _AuthMode.login, label: Text('登录')),
                ButtonSegment(value: _AuthMode.register, label: Text('注册')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
              style: SegmentedButton.styleFrom(
                foregroundColor: colors.inkMuted,
                selectedForegroundColor: colors.onAccent,
                selectedBackgroundColor: colors.accent,
                side: BorderSide(color: colors.track),
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: DesignCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? '欢迎回来' : '创建账号',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLogin ? '登录后可云同步观看历史' : '用户名 3-32 字符，密码 6-64 位',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _username,
                      label: '用户名',
                      hint: '3-32 个字符',
                      validator: _validateUsername,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _password,
                      label: '密码',
                      hint: '6-64 位',
                      validator: _validatePassword,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _submitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: colors.onAccent,
                                ),
                              )
                            : Text(
                                isLogin ? '登录' : '注册并登录',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 表单字段：card 底圆角容器 + 无边框输入，行内错误提示在字段下方。
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
    this.obscure = false,
    this.onToggleObscure,
    this.prefixIcon,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FormFieldValidator<String> validator;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final Widget? prefixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.track),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            obscureText: obscure,
            cursorColor: colors.accent,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            style: TextStyle(fontSize: 15, color: colors.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 15, color: colors.inkMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              prefixIcon: prefixIcon,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 20,
              ),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: colors.inkMuted,
                      ),
                      onPressed: onToggleObscure,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
