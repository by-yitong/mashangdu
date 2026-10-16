# 本地分叉补丁说明（liquid_glass_widgets）

上游版本：**1.13.0**（pub.dev，MIT 许可，来自本机 Pub Cache 的原样拷贝）。
分叉来源：学习 [timer0173/timerq](https://github.com/timer0173/timerq) 对上游
1.6.0 的同类补丁，在其 LOCAL_PATCH.md 配方上按 1.13.0 结构重放。

分叉原因：上游 `GlassTabBar` 的底部指示器胶囊只接受整数 `selectedIndex`，
没有对外 API 让宿主注入**连续**的滑动位置——主壳内容区（PageView）跟手
分页时，指示器无法像素级跟随手指。

## 补丁内容（搜 `LOCAL PATCH` 定位全部改动）

新增公开参数 `GlassTabBar.bottom(swipePosition: ValueListenable<double>?)`，
值为宿主内容分页器的页面位置（0..tabs.length-1，允许橡皮筋越界小量）：

1. `lib/widgets/surfaces/glass_tab_bar.dart` — `.bottom` 构造器新增
   `swipePosition` 参数，经私有构造器存为字段，`_buildBottom` 透传给
   `TabBarBottomLayout`。
2. `lib/src/widgets/surfaces/tab_bar_bottom_layout.dart` — 同名参数透传给
   `TabIndicator`。
3. `lib/src/widgets/surfaces/tab_bar_bottom_internal.dart` — 核心：
   - `TabIndicator` 新增 `swipePosition` 字段；
   - `TabIndicatorState` 订阅该 listenable，回调里把页面位置映射为
     指示器对齐值（`align = -1 + 2·p/(n-1)`，与
     `TabDragGestureMixin.computeTabAlignment` 互逆），直接写
     `tabXAlign`，复用既有的 `VelocitySpringBuilder`（拖拽中紧贴、
     松手弹簧）实现连续跟手；
   - 栏自身胶囊拖拽（`tabIsDragging`）优先，注入被忽略，互不打架；
   - `_externalDrivenThisFrame` 帧标志：本帧有外部注入时，
     `didUpdateWidget` 跳过 `updateTabAlignIfNeeded` 的整位吸附，
     避免 `selectedIndex` 跨中点四舍五入时指示器抢跳整位；
   - 与 1.6.0 的差异：1.13.0 的 `initState/dispose` 在
     `TabDragGestureMixin` 里，本补丁在 `TabIndicatorState` 重写并链回
     super 后挂/摘监听。

宿主接线示例见 `mobile/lib/app.dart` 的 `_HomeShellState`：
`PageController` 监听器把 `controller.page` 写进 `ValueNotifier<double>`，
传给 `swipePosition`；`onPageChanged` 更新整数 `selectedIndex`。

## 升级上游时

1. 重新复制新版本源码到本目录（保留本文件）；
2. 按上面 3 处重放补丁（上游若重构，定位 `TabIndicatorState.tabXAlign`
   与 `updateTabAlignIfNeeded` 即可找到等价位置）；
3. 跑 `mobile/test/swipe_tab_test.dart` 验证滑动跟随不回归。
