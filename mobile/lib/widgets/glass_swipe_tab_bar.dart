import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// [GlassSwipeTabBar] 的单个导航项。
class GlassSwipeTab {
  const GlassSwipeTab({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final Widget icon;
  final Widget? activeIcon;
  final String label;
}

/// 联动 [PageView] 的底部导航条。
///
/// `GlassTabBar.bottom` 的选中位置只收 int（1.13.0 无小数/控制器 API），
/// 无法跟随页面的小数偏移；本组件用 `AdaptiveGlass` 重建同款胶囊外观，
/// 药丸指示器与图标/文字颜色逐像素跟随 [PageController] 的 page 值——
/// 页面滑多少、Tab 跟多少，松手后随页面一起停靠。
///
/// 外观参数对齐原 GlassTabBar.bottom 用法：horizontalPadding 24、
/// verticalPadding 18、barHeight 56、iconSize 20。玻璃层走
/// `AdaptiveGlass.grouped`，由 GlassScaffold 的隔离作用域自动升 premium。
class GlassSwipeTabBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassSwipeTabBar({
    required this.controller,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
    required this.indicatorColor,
    required this.selectedIconColor,
    required this.selectedLabelColor,
    required this.unselectedIconColor,
    required this.unselectedLabelColor,
    this.horizontalPadding = 24,
    this.verticalPadding = 18,
    this.barHeight = 56,
    this.iconSize = 20,
    this.labelFontSize = 11,
    this.pillInset = 6,
    super.key,
  });

  final PageController controller;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<GlassSwipeTab> tabs;

  // 配色（沿用 AppColors token）。
  final Color indicatorColor;
  final Color selectedIconColor;
  final Color selectedLabelColor;
  final Color unselectedIconColor;
  final Color unselectedLabelColor;

  // 几何：与 GlassScaffold 的 bottomBar 槽位约定一致（见 preferredSize）。
  final double horizontalPadding;
  final double verticalPadding;
  final double barHeight;
  final double iconSize;
  final double labelFontSize;

  /// 药丸距 tab 槽位边缘的内缩。
  final double pillInset;

  /// GlassScaffold 用它给 body 让位；与 GlassTabBar.bottom 同口径：
  /// barHeight + 上下 verticalPadding（安全区由 Scaffold 自己处理）。
  @override
  Size get preferredSize => Size.fromHeight(barHeight + verticalPadding * 2);

  @override
  State<GlassSwipeTabBar> createState() => _GlassSwipeTabBarState();
}

class _GlassSwipeTabBarState extends State<GlassSwipeTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handlePageChanged);
  }

  @override
  void didUpdateWidget(GlassSwipeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePageChanged);
      widget.controller.addListener(_handlePageChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePageChanged);
    super.dispose();
  }

  void _handlePageChanged() {
    // PageController 每帧汇报像素位置，这里只需触发重建。
    if (mounted) setState(() {});
  }

  /// 当前小数页码：拖动/动画中为连续值，停靠后恰为整数。
  double get _page {
    final controller = widget.controller;
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.page!.clamp(0, widget.tabs.length - 1);
    }
    return widget.selectedIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final tabCount = widget.tabs.length;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
        vertical: widget.verticalPadding,
      ),
      child: SizedBox(
        height: widget.barHeight,
        width: double.infinity,
        child: AdaptiveGlass.grouped(
          shape: LiquidRoundedRectangle(
            borderRadius: GlassDefaults.capsuleRadius,
          ),
          child: Stack(
            children: [
              // 药丸指示器：FractionallySizedBox 占一个槽位宽，
              // Alignment 随 page 在 [-1, +1] 间连续滑动（暂只支持 LTR）。
              Align(
                key: const ValueKey('swipe_tab_pill'),
                alignment: Alignment(
                  tabCount < 2 ? 0 : -1 + 2 * page / (tabCount - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / tabCount,
                  heightFactor: 1,
                  child: Padding(
                    padding: EdgeInsets.all(widget.pillInset),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: widget.indicatorColor,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ),
              // 图标 + 文字层：颜色随与当前 page 的距离连续过渡。
              Row(
                children: [
                  for (var i = 0; i < tabCount; i++)
                    Expanded(child: _buildTabItem(i, page)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, double page) {
    final tab = widget.tabs[index];
    // 距离 0 = 完全选中，1 = 完全未选中，中间随滑动渐变。
    final distance = (page - index).abs().clamp(0.0, 1.0);
    final iconColor = Color.lerp(
      widget.selectedIconColor,
      widget.unselectedIconColor,
      distance,
    )!;
    final labelColor = Color.lerp(
      widget.selectedLabelColor,
      widget.unselectedLabelColor,
      distance,
    )!;
    final icon = distance < 0.5 ? (tab.activeIcon ?? tab.icon) : tab.icon;

    return Semantics(
      button: true,
      selected: index == widget.selectedIndex,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            IconTheme(data: IconThemeData(color: iconColor, size: widget.iconSize), child: icon),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: widget.labelFontSize,
                fontWeight: distance < 0.5 ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
