## 第5章 · 函数与模块

代码越写越多，全堆在一个文件里从上到下执行，很快就会乱掉。两样工具能解决这个问题：函数把一段逻辑打包成可以反复调用的单元，模块把多个函数和常量整理成一个文件，供别的程序导入使用。

Python 用 def 定义函数，参数可以带默认值，调用时可以按位置传也可以按名字传（关键字参数）：

```python
# def 定义函数，缩进的部分是函数体
def greet(name, greeting="你好"):
    return f"{greeting}，{name}！"

print(greet("小明"))                # 你好，小明！（用默认值）
print(greet("Tom", greeting="Hi")) # Hi，Tom！（关键字参数）

# 函数可以一次返回多个值（其实是打包成元组，自动拆开接收）
def min_max(nums):
    return min(nums), max(nums)

low, high = min_max([3, 1, 4, 1, 5])
print(low, high)   # 1 5
```

函数名取得好，代码自己会说话：动作加对象，比如 save_config、load_scores。一个函数只做一件事，超过二三十行就该考虑拆分。

再说模块。把常用的函数写进一个 .py 文件，它就是一个模块；其他文件用 import 导入后，通过"模块名.函数名"的方式调用。Python 之所以好用，一大原因是标准库提供了几百个现成模块：

```python
# ---- 文件 mymath.py ----
def square(x):
    return x * x

PI = 3.14

# ---- 文件 main.py ----
import mymath

print(mymath.square(5))   # 25
print(mymath.PI)          # 3.14

# 只想导入部分内容时用 from ... import
from mymath import square
print(square(5))
```

注意上面那两个"文件"要放在同一个目录下再运行 main.py。还有个广为流传的惯用写法，能让一个文件既能当模块被导入、又能自己直接运行：

```python
# 在 mymath.py 末尾加上：
if __name__ == "__main__":
    # 只有直接运行 python mymath.py 时才执行这里
    # 被别人 import 时这一段不执行，用来放测试代码正合适
    print(square(10))  # 100
```

原理很简单：直接运行文件时 Python 把它的 `__name__` 设成 `"__main__"`，被导入时设成模块名，所以这个 if 就成了"是否被直接运行"的开关。你以后读任何 Python 项目，几乎都会见到它。

关于函数，还有几条实用规则：

- 没有 return 语句的函数返回 None；
- 参数默认值只计算一次，不要用列表等可变对象当默认值；
- `*args` 接收任意多个位置参数，`**kwargs` 接收任意多个关键字参数，标准库函数大量使用；
- 变量作用域：函数内赋值的变量是局部的，函数外的是全局的，函数内想改全局变量需要 global 声明——更好的做法是通过参数传进去、用返回值拿出来。

顺便认识文档字符串：在函数体的第一行写一段三引号文字，说明这个函数做什么、参数是什么，这就是 docstring。调用 help(greet) 时 Python 会把它打印出来，很多编辑器的悬浮提示读的也是它。团队协作时，docstring 加上清晰的参数名，常常就是最好的接口文档，养成"先写一句话说明"的习惯，半年后回看自己的代码会感谢现在的自己。把通讯录的几个函数都补上 docstring，再用 help 查一次试试。函数是 Python 功底的分水岭，值得多写多改。

小结：函数复用逻辑，模块复用文件，`if __name__ == "__main__"` 区分直接运行与被导入。把之前写的"通讯录"练习改造成函数版本：add_contact、find_contact、remove_contact，再存进 addressbook.py 试试导入。

下一步：第 6 章学习面向对象编程，用类把数据和相关函数绑定在一起。
