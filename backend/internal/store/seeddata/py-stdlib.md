## 第9章 · 标准库常用模块

Python 的口号是"自带电池"（batteries included）：安装好 Python，就同时获得了几百个现成的模块，管这叫标准库。生成随机数、处理日期、读写 JSON、操作文件路径，这些常见需求都不用自己造轮子，import 一下就有。本章挑四个最常用的模块入门。

先看 random 和 datetime。random 负责随机性——掷骰子、抽奖、洗牌都靠它；datetime 负责日期时间——取当前时间、格式化输出、做时间计算：

```python
import random
from datetime import date, datetime

# random：随机数
print(random.randint(1, 6))                   # 掷骰子：1 到 6 的随机整数
print(random.choice(["石头", "剪刀", "布"]))   # 随机选一个
nums = [1, 2, 3, 4, 5]
random.shuffle(nums)                          # 原地打乱顺序
print(nums)

# datetime：日期与时间
today = date.today()
print(today.year, today.month, today.day)     # 2026 10 15

now = datetime.now()
print(now.strftime("%Y-%m-%d %H:%M"))         # 按格式输出，如 2026-10-15 09:30
```

再看 json 和 pathlib。json 负责在 Python 对象和 JSON 文本之间转换，JSON 是配置文件和网络接口最常用的数据格式，学它等于拿到了和外部世界交换数据的通用语言；pathlib 用面向对象的方式处理文件路径，比拼接字符串可靠得多：

```python
import json
from pathlib import Path

# json：对象与 JSON 字符串互相转换
data = {"name": "小明", "scores": [90, 85]}
text = json.dumps(data, ensure_ascii=False)   # 转 JSON 字符串
print(text)                                   # {"name": "小明", "scores": [90, 85]}
same = json.loads(text)                       # 解析回 Python 对象
print(same["scores"][0])                      # 90

# pathlib：路径操作
p = Path("docs")
p.mkdir(exist_ok=True)        # 创建文件夹，已存在也不报错
print(p.exists())             # 是否存在
print(list(p.glob("*.txt")))  # 列出其中的 txt 文件
```

标准库里值得继续了解的模块还有很多，这里给个地图，用到时再查文档：

- `os`：老牌的系统和路径模块，很多功能正被 pathlib 取代，但仍然常见；
- `math`：平方根、向上向下取整、圆周率等数学工具；
- `re`：正则表达式，复杂文本匹配的利器；
- `time`：时间戳和 sleep 暂停；
- `collections`：Counter 统计次数、defaultdict 带默认值的字典，非常好用；
- `csv`：读写 CSV 表格文件；
- `itertools`：各种迭代器工具，处理组合、排列很省事。

一个高效的学习策略：不必背 API，记住"标准库里有 XXX 这样的东西"即可，写代码时先想"官方会不会已经有现成的"，再查官方文档（docs.python.org 的标准库章节，有中文版）。绝大多数你准备手写的工具函数，标准库里早就有久经考验的实现。

探索模块还有两个自带工具：dir(random) 列出模块里的所有名字，help(random.choice) 直接查看某个函数的用法说明，不用离开解释器就能边写边查，标准库文档配合这两个函数，基本不需要额外搜索。还有一个原则：同一个需求先怀疑标准库已经有实现，比如统计次数用 collections.Counter，一行就能数出最高频的元素，自己手写循环反而容易出错。把 Counter 的用法查一查，写个小例子试试。标准库不用背用法，记住"有什么"比记住"怎么写"更重要。别贪多，本章四个模块各写十行小例子就够入门，剩下的一切都可以在用到时再查，用得越多记得越牢。

小结：random 管随机，datetime 管时间，json 管数据交换，pathlib 管路径——四个模块覆盖了脚本编程的大半日常。练习建议：用 random 写一个"猜数字"游戏，用 randint 生成 1 到 100 的答案，循环让用户猜，大了小了都给提示。

下一步：第 10 章进入实战，综合运用 pathlib、字符串处理和 f-string，写一个批量重命名文件的工具。
