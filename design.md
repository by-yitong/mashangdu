# 码上读 — 冻结设计系统 v1

> 本文件是 App 端唯一设计依据（已获用户确认）。UI 代码不得偏离此处 token；确需变更先回主 agent 更新本文件。

## 设计基调
- 深色大圆角卡片风格（参考:深色任务管理类 App），浅色版同构
- 气质:technical 技术感（等宽字体呈现数字/代码元素，信息密度适中）
- 深浅色:跟随系统，两套同构配色

## 颜色 token

| token | 深色值 | 浅色值 | 用途 |
|---|---|---|---|
| paper | #101312 | #F4F6F5 | 页面背景 |
| card | #1D211F | #FFFFFF | 卡片背景 |
| ink | #F2F5F3 | #1A1F1D | 主文字 |
| inkMuted | #8A938E | #6D7773 | 次要文字 |
| accent | #14B8A6 | #0D9488 | 主题色(青蓝 teal，禁止紫/琥珀) |
| accentDim | accent 14% 混入 card | accent 12% 混入 card | 选中胶囊/状态底色 |
| track | #313734 | #E3E8E6 | 进度条轨道 |

语言标签块底色（固定，不随主题反色）:
- Go: 底 #1D2B2E / 字 #7DD3C8（浅色版 底 #E6F5F3 / 字 #0F766E）
- Python: 底 #232936 / 字 #9DB4E8（浅色版 底 #EDF1FA / 字 #4C6BB0）
- 新语言按同思路:语言主色低饱和深底 + 亮字（深色）/ 低饱和浅底 + 深字（浅色）

## 字体与字号（系统默认无衬线；数字/进度用等宽 tabular）
- 页面大标题 32 / w700
- 卡片标题 20 / w700
- 状态行、胶囊 14（选中 w600）
- 次要说明 12-13
- 等宽数字（进度、百分比）13 mono

## 形状与间距
- 卡片圆角 22，内边距 18（底部 16）；卡片间距 14；页面左右边距 16
- 筛选胶囊、底部导航胶囊:全圆角 999
- 进度条高 4、圆角 2
- 底部浮动胶囊导航:宽 min(330, 100%-48)，左右 10、上下 8 内边距，图标 20，下边距 18（v1.1 起:不再放同步按钮，首页改为下拉刷新）

## 组件规范
- 课程卡:状态行（8px 色点 + 状态词，右侧 13px 次要文字）→ 20/w700 标题 → 底部行（语言标签块 12px + 右侧 mono 进度）→ 4px 进度条
- 继续阅读卡（hero 卡，与普通课程卡明确区分）:accentDim 底 + accent 28% 描边，圆角 22、内边距同课程卡；横向布局——左列「继续阅读」标签（accent 12/w600）+ 课程名（12 inkMuted，省略号）→ 章节标题 20/w700 ink（最多 2 行）→ 底部行 Expanded 4px 进度条 + mono accent 百分比；右列 52px accent 圆形播放钮（onAccent 播放图标）
- 筛选胶囊组:选中 = accentDim 底 + accent 字 w600；未选 = card 底 + inkMuted
- 列表末尾居中 13px "没有更多了"
- 设置开关行:DesignCard 内卡片标题 15/w700 + 每行左侧条目（14 ink，说明 12-13 inkMuted）+ 右侧 Switch（选中 accent）
- 底部导航:选中项 accentDim 胶囊底 + accent 字；未选 inkMuted；主按钮 accent 底圆形（深色字 #062925 / 浅色白字）

## Flutter 实现（liquid_glass_widgets 规则摘要，全文见 C:\Users\admin\.agents\skills\liquid-glass-widgets\SKILL.md）
- main(): `await LiquidGlassWidgets.initialize()` 后 `LiquidGlassWidgets.wrap()`（brightnessResolver: Theme.maybeBrightnessOf）
- 底部导航用 `GlassTabBar.bottom(...)`（GlassBottomBar 已删除，禁用）；玻璃层仅用于导航/控制层
- 禁止玻璃套玻璃；内容卡片用普通容器实现本文件 token，不用 GlassCard 包按钮
- GlassScaffold 下滚动体底部预留 ≥104，顶部预留 safeArea+12+bar 高
- GlassButton 用 onTap；GlassIconButton 用 onPressed
- 内容主题色随本文件 token；玻璃导航层保持库默认毛玻璃即可

## 页面清单
1. 首页:大标题"码上读"+ 同步行 → 筛选胶囊（全部/学习中/未开始）→ 卡片列表（继续阅读卡置顶）→ 没有更多了；底部胶囊导航 + 同步主按钮
2. 课程页:章节列表卡，已读打勾，顶部整体进度
3. 阅读页:Markdown 正文 + 代码块（深底圆角、等宽、一键复制）+ 底部上一章/下一章，打开即记已读
4. 设置页:阅读卡（「打开时继续上次阅读」开关，默认开——上次退出时停留在阅读页则启动直达该章）+ 外观卡 + 关于卡
