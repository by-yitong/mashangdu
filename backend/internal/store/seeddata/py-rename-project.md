## 第10章 · 实战：批量重命名文件

课程最后做一个立刻能用得上的工具：把一个文件夹里的照片从"IMG_2024.jpg"这样的相机命名，批量改成"旅行照片_001.jpg"式的有序命名。相机一次拍几百张，手工重命名不现实，这正是编程的用武之地。这个项目会综合用到 pathlib、glob 匹配、f-string 和循环。

思路分三步：找到目标文件夹里所有 jpg 文件；按文件名排序保证顺序稳定；循环逐个生成新名字并调用 rename。第一版先求能跑：

```python
from pathlib import Path

folder = Path("photos")   # 要处理的文件夹，按需修改路径

# glob("*.jpg") 匹配文件夹下所有 jpg 文件；sorted 保证顺序稳定
# enumerate 从 1 开始编号
for i, old in enumerate(sorted(folder.glob("*.jpg")), start=1):
    new = folder / f"旅行照片_{i:03d}.jpg"   # i:03d 表示补零到 3 位：001、002……
    old.rename(new)                          # 执行重命名
    print(f"{old.name} -> {new.name}")
```

注意 `i:03d` 这个格式说明：03d 表示按十进制整数输出、不足三位在左边补零。没有补零的话，"旅行照片_10.jpg"会排在"旅行照片_2.jpg"前面，文件管理器里的顺序就乱了——细节决定工具好不好用。

第一版有个隐患：rename 一执行就覆水难收，万一新名字规则写错了，几百个文件就乱了。工程上的解法是"预演"（dry run）：先把要做的改动打印出来，人工确认无误后再真正执行。我们加上这个安全机制，顺便处理"目标文件已存在"的情况：

```python
from pathlib import Path

folder = Path("photos")
prefix = "旅行照片"
dry_run = True   # 先预演，检查输出无误后改成 False 正式执行

for i, old in enumerate(sorted(folder.glob("*.jpg")), start=1):
    new = folder / f"{prefix}_{i:03d}.jpg"

    if new.exists():                     # 目标已存在就跳过，避免覆盖
        print(f"跳过，目标已存在：{new.name}")
        continue

    if dry_run:
        print(f"[预演] {old.name} -> {new.name}")
    else:
        old.rename(new)
        print(f"已重命名 {old.name} -> {new.name}")
```

使用流程和几个可扩展方向：

- 第一步：把 folder 改成你自己的文件夹路径，保持 dry_run = True 运行一遍，检查每行"[预演]"输出是否符合预期；
- 第二步：确认无误后把 dry_run 改成 False，再运行一次完成改名；
- 想处理 png 图片，把 glob 里的 `*.jpg` 换成 `*.png`；想匹配多种格式，可以用两次循环或 `folder.iterdir()`；
- 想给文件名统一加前缀而不是编号，把 new 的生成规则改成 `f"{prefix}_{old.name}"` 即可；
- 再进一步，可以把规则参数化并配合第 5 章的函数、第 8 章的异常处理，做成一个通用的小命令行工具。

回顾整个课程：变量、控制流、容器、函数、类、文件、异常、标准库，在这 30 行代码里全部登场了。学编程的下一步不是再找一门新课，而是带着这门语言去解决你自己的真实问题——文件整理、数据处理、自动化办公都是好起点。

sorted 在这里不是可选项：glob 返回的文件顺序在不同操作系统上不一定一致，不排序的话编号就是随机的，重命名结果每次都可能不同，这是批量操作的大忌。想换一种排序依据，可以利用 key 参数，比如按文件修改时间排：sorted(folder.glob("*.jpg"), key=lambda p: p.stat().st_mtime)，照片就能按拍摄先后编号，这在整理照片时往往比按文件名排更符合直觉。

小结：批量重命名 = glob 找文件 + sorted 定顺序 + 循环 rename，dry run 让危险操作先预演。运行它，改 10 个文件试试。

下一步：打开 docs.python.org 标准库文档，挑一个感兴趣的模块（推荐 collections）读读入门章节，保持手感。
