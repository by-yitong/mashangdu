## 第7章 · 文件读写

到目前为止，我们的数据都活在内存里：程序一退出就全部消失。要让数据"留下来"——保存配置、记录日志、处理文档——就要学会文件读写。Python 内置的 open 函数配合 with 语句，几行代码就能搞定。

读文件最常用的姿势是 for 循环逐行读，内存占用小，多大的文件都不怕：

```python
# with 语句会在代码块结束时自动关闭文件，推荐始终使用它
# "r" 是读模式，encoding 指定编码，Windows 下处理中文务必写上 utf-8
with open("diary.txt", "r", encoding="utf-8") as f:
    for line in f:
        print(line.strip())  # strip 去掉行尾的换行符

# 也可以一次性读出全部内容，适合小文件
with open("diary.txt", "r", encoding="utf-8") as f:
    content = f.read()
    print(len(content), "个字符")
```

写文件用 "w" 或 "a" 模式。特别注意 "w" 是覆盖写入：文件里原有内容会被清空重来；想保留旧内容在后面追加，必须用 "a"：

```python
# "w" 模式覆盖写入，文件不存在会自动创建
with open("output.txt", "w", encoding="utf-8") as f:
    f.write("第一行\n")          # write 不会自动换行，要自己加 \n
    f.write("第二行\n")

# "a" 模式追加，不覆盖原有内容
with open("output.txt", "a", encoding="utf-8") as f:
    f.write("第三行（追加进来的）\n")

# writelines 接收字符串列表，一次写多行
lines = ["苹果\n", "香蕉\n", "橘子\n"]
with open("fruits.txt", "w", encoding="utf-8") as f:
    f.writelines(lines)
```

文件路径方面，新手最常遇到三类问题，提前知道能省很多调试时间：

- 编码错误：Windows 上不写 encoding 参数时默认编码可能不是 UTF-8，读中文文件出现乱码或 UnicodeDecodeError，加上 `encoding="utf-8"` 基本都能解决；
- 文件不存在：读一个不存在的文件会抛出 FileNotFoundError，稳妥的写法是先用第 9 章的 try/except 捕获，或者用 pathlib 先判断 `Path("diary.txt").exists()`；
- 相对路径的基准是"运行命令时所在的目录"，不是脚本文件所在目录，找不到文件时先检查这一点。

模式参数的完整含义集中列一下：

- `"r"`：只读，文件必须已存在（默认值）；
- `"w"`：只写，清空原内容，不存在则创建；
- `"a"`：只写，在末尾追加，不存在则创建；
- `"r+"`：读和写，文件必须已存在；
- 加一个 `"b"` 如 `"rb"`、`"wb"`：按二进制处理，用于图片、音频等非文本文件。

如果只是简单地读或写整个文件，pathlib 还提供了更短的快捷方式：Path("diary.txt").read_text(encoding="utf-8") 一行读完全部内容，write_text 一行写完，连 with 都省了。临时读个小配置文件用它最省事；需要逐行处理大文件或边读边写时，还是回到本节的 open 写法。注意 write_text 每次都是覆盖写入，追加内容仍然要用 "a" 模式，规则和本节完全一致。另外建议专门建一个练习文件夹存放脚本产生的文件，文件操作的破坏性比内存里的变量大得多，养成隔离的习惯能少闯不少祸。写完先在小文件上试验，确认读写模式用对了再碰真实数据。还有，把路径集中写在脚本开头的变量里，改目录时只动一处，出错概率立刻下降一半。

小结：open 加 with 是文件操作的标准姿势，"r" 读、"w" 覆盖写、"a" 追加写，处理中文记得 encoding="utf-8"。练习建议：把第 6 章 BankAccount 的余额保存到 account.txt，程序启动时读出来继续用——这样它就有了"记忆"。

下一步：第 8 章学习异常处理，让程序在出错时优雅应对而不是直接崩溃。
