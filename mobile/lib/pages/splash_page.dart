import 'package:flutter/material.dart';

import '../widgets/design.dart';

/// 启动页：居中图标（圆角卡片容器）+ 应用名 + 底部小号加载指示。
///
/// 由 main 的 _SplashGate 展示 ≥600ms，随后切换到正式根。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: colors.track),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '码上读',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '碎片时间，读懂编程',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colors.accent,
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
