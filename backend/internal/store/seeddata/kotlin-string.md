字符串是编程中最常用的数据类型，用来表示文本。

Kotlin 的 String 类提供了丰富的查找、截取、替换方法，还支持原始字符串和字符串模板，写起来比 Java 简洁很多。

本篇先介绍字符串本身，再介绍正则表达式 Regex 的完整用法。

---

## 字符串基础与不可变性

字符串用双引号包裹，类型是 String。

String 是不可变的（immutable）：一旦创建，内容就不能再改变。

所有看起来像"修改"的方法，例如 uppercase()、replace()，实际上都返回一个新的字符串，原字符串保持不变。

**实例**

```kotlin
fun main() {
    val site = "Runoob"

    // 调用 uppercase 得到新字符串，原字符串不受影响
    val upper = site.uppercase()
    println(site)         // Runoob
    println(upper)        // RUNOOB

    // 用方括号按下标取字符，下标从 0 开始
    println(site[0])      // R
    println(site.length)  // 6

    // 用 for 遍历每一个字符
    for (c in site) {
        print(c)
    }
    println()             // 输出换行
}
```

```text
Runoob
RUNOOB
R
6
Runoob
```

比较字符串内容要用 `==`，它比较的是值；`===` 比较的是引用，不要用来判断字符串是否相等。

**实例**

```kotlin
fun main() {
    val a = "runoob"
    val b = "runoob"
    val c = String(charArrayOf('r', 'u', 'n', 'o', 'o', 'b'))

    println(a == b)    // true，内容相同
    println(a == c)    // true，内容相同
    println(a === c)   // false，c 是运行时新建的对象
}
```

```text
true
true
false
```

> **注意：**字符串不可变意味着拼接、替换都会产生新对象。在循环里反复拼接字符串时，应改用 StringBuilder，否则会产生大量临时对象。

---

## 转义字符串与原始字符串

Kotlin 有两种字符串字面量：转义字符串和原始字符串。

转义字符串用一对双引号包裹，支持 \n、\t 等转义序列。

原始字符串用三个双引号包裹，内容原样保留，反斜杠和引号都不需要转义，适合写路径、JSON 和正则。

**实例**

```kotlin
fun main() {
    // 转义字符串：\n 会被解释为换行
    val escaped = "第一行\n第二行"
    println(escaped)

    // 原始字符串：内容原样保留，包括换行
    val raw = """第一行
第二行"""
    println(raw)

    // 原始字符串里可以直接写反斜杠，不需要转义
    val path = """C:\Users\runoob\kotlin"""
    println(path)

    // 写 JSON 时特别方便
    val json = """{"site": "www.runoob.com"}"""
    println(json)

    // 原始字符串中 $ 仍然是模板起始符，输出字面量 $ 要写成 ${'$'}
    val price = """${'$'}9.99"""
    println(price)
}
```

```text
第一行
第二行
第一行
第二行
C:\Users\runoob\kotlin
{"site": "www.runoob.com"}
$9.99
```

> **提示：**原始字符串中唯一需要注意的字符是 `$`，它仍会触发字符串模板。需要输出字面量美元符号时，写成 `${'$'}`。

---

## trimIndent 与 trimMargin

用原始字符串写多行文本时，代码缩进会被一起保留，看起来会有多余的空格。

trimIndent() 会删除所有行共同的缩进，以及首尾的空行。

trimMargin() 则按边界前缀（默认是竖线）裁剪每一行，适合需要保留部分缩进的场景。

**实例**

```kotlin
fun main() {
    // trimIndent：去掉公共缩进
    val text = """
        Runoob
        www.runoob.com
        RUNOOB
    """.trimIndent()
    println(text)

    // trimMargin：默认以 | 作为边界前缀
    val margin = """
        |Runoob
        |www.runoob.com
        |RUNOOB
    """.trimMargin()
    println(margin)

    // 也可以自定义边界前缀
    val custom = """
        >Runoob
        >RUNOOB
    """.trimMargin(">")
    println(custom)
}
```

```text
Runoob
www.runoob.com
RUNOOB
Runoob
www.runoob.com
RUNOOB
Runoob
RUNOOB
```

trimIndent() 计算公共缩进时会忽略空行，所以中间插入空行不影响结果。

trimMargin() 只删除边界前缀之前的内容，前缀之后的部分保持原样，因此可以灵活控制每行的起始位置。

---

## 字符串模板

字符串模板允许把变量或表达式直接嵌入字符串，用 `$` 开头。

简单的变量名用 `$name`，表达式或带点的调用用 `${...}`。

**实例**

```kotlin
fun main() {
    val siteName = "Runoob"
    val age = 10

    println("站点：$siteName")                    // 站点：Runoob
    println("$siteName 已上线 $age 年")           // Runoob 已上线 10 年

    // 复杂表达式用花括号包起来
    println("$siteName 长度是 ${siteName.length}")  // Runoob 长度是 6
    println("明年是第 ${age + 1} 年")               // 明年是第 11 年

    // 模板里也可以调用函数
    println("大写：${siteName.uppercase()}")        // 大写：RUNOOB

    // 输出字面量 $ 需要转义
    println("价格：\$9.99")                        // 价格：$9.99
}
```

```text
站点：Runoob
Runoob 已上线 10 年
Runoob 长度是 6
明年是第 11 年
大写：RUNOOB
价格：$9.99
```

> **注意：**当变量名后面紧跟其他字母时，必须用 `${name}` 形式，否则编译器会把后续字符当作变量名的一部分。例如 `"$siteNameSuffix"` 会去找名为 siteNameSuffix 的变量。

---

## 常用方法

下表列出了日常开发中最常用的字符串方法。

| 方法 | 说明 | 示例 |
| --- | --- | --- |
| length | 字符个数，属性不是方法 | "runoob".length 得到 6 |
| isEmpty() | 是否为空字符串 | "".isEmpty() 得到 true |
| isBlank() | 是否为空白（只有空格也算） | " ".isBlank() 得到 true |
| lowercase() | 转小写，返回新字符串 | "RUNOOB".lowercase() 得到 runoob |
| uppercase() | 转大写，返回新字符串 | "runoob".uppercase() 得到 RUNOOB |
| trim() | 去掉首尾空白 | " Runoob ".trim() 得到 Runoob |
| split() | 按分隔符切分成 List | "a,b".split(",") 得到 [a, b] |
| replace() | 替换所有匹配内容 | "a-b".replace("-", "+") 得到 a+b |
| substring() | 截取子串，区间左闭右开 | "runoob".substring(0, 3) 得到 run |
| padStart() | 在左侧补字符到指定长度 | "7".padStart(3, '0') 得到 007 |
| repeat() | 重复指定次数 | "ab".repeat(2) 得到 abab |
| startsWith() | 是否以某内容开头 | "runoob".startsWith("run") 得到 true |
| contains() | 是否包含某内容，区分大小写 | "runoob".contains("NO") 得到 false |
| indexOf() | 返回首次出现的下标，找不到返回 -1 | "runoob".indexOf("o") 得到 2 |
| toInt() | 解析成整数，失败抛异常 | "42".toInt() 得到 42 |

下面的例子演示了这些方法的具体结果。

**实例**

```kotlin
fun main() {
    val s = "  Runoob Kotlin  "

    println(s.length)                       // 17
    println(s.trim())                       // Runoob Kotlin
    println(s.trim().lowercase())           // runoob kotlin
    println(s.trim().uppercase())           // RUNOOB KOTLIN
    println(s.contains("runoob"))           // false，区分大小写
    println(s.trim().startsWith("Run"))     // true
    println(s.trim().endsWith("lin"))       // true
    println(s.trim().substring(0, 6))       // Runoob
    println(s.trim().replace("Kotlin", "RUNOOB"))  // Runoob RUNOOB
    println(s.trim().indexOf("Kotlin"))     // 7
    println("7".padStart(3, '0'))           // 007
    println("ab".repeat(3))                 // ababab
    println("a,b,c".split(","))             // [a, b, c]
    println("".isEmpty())                   // true
    println("   ".isBlank())                // true
}
```

```text
17
Runoob Kotlin
runoob kotlin
RUNOOB KOTLIN
false
true
true
Runoob
Runoob RUNOOB
7
007
ababab
[a, b, c]
true
true
```

split() 还可以同时指定多个分隔符，或者直接传入一个正则表达式。

**实例**

```kotlin
fun main() {
    // 多个分隔符
    println("a,b;c".split(",", ";"))          // [a, b, c]

    // 用正则作为分隔符
    println("a1b2c3".split(Regex("""\d""")))  // [a, b, c]

    // 限制返回元素个数，最后一个元素保留剩余内容
    println("a,b,c,d".split(",", limit = 3))  // [a, b, c,d]
}
```

```text
[a, b, c]
[a, b, c]
[a, b, c,d]
```

---

## 字符串格式化

需要对齐、补零或控制小数位数时，可以使用格式化函数。

在 JVM 平台上，Kotlin 提供了 `String.format()` 静态方法和字符串的 `format()` 扩展函数，语法与 Java 的格式化字符串一致。

**实例**

```kotlin
fun main() {
    val name = "Runoob"
    val score = 95.5

    // String.format：占位符依次对应后面的参数
    val s1 = String.format("%s 的得分是 %.2f", name, score)
    println(s1)

    // 字符串的 format 扩展函数，写法更紧凑
    val s2 = "站点：%s，得分：%d".format(name, 96)
    println(s2)

    // %-10s 表示左对齐、宽度 10；%05d 表示不足 5 位左侧补 0
    println("%-10s|".format("runoob"))
    println("%05d".format(42))

    // %x 输出十六进制
    println("%x".format(255))
}
```

```text
Runoob 的得分是 95.50
站点：Runoob，得分：96
runoob    |
00042
ff
```

下表列出了最常用的占位符。

| 占位符 | 含义 | 示例结果 |
| --- | --- | --- |
| %s | 字符串 | "%s".format("runoob") 得到 runoob |
| %d | 十进制整数 | "%d".format(42) 得到 42 |
| %f | 浮点数，默认 6 位小数 | "%f".format(3.14) 得到 3.140000 |
| %.2f | 保留两位小数 | "%.2f".format(3.14159) 得到 3.14 |
| %05d | 宽度 5，不足补 0 | "%05d".format(42) 得到 00042 |
| %-10s | 宽度 10，左对齐 | "%-10s\|".format("runoob") 得到 runoob 加 4 个空格 |
| %x | 十六进制小写 | "%x".format(255) 得到 ff |

> **注意：**`String.format` 依赖 JVM，在 Kotlin/JS 和 Kotlin/Native 上不可用。跨平台代码请改用字符串模板或自己实现补位逻辑。

---

## 正则表达式 Regex

正则表达式用来描述一类文本的模式，常用于校验、提取和替换。

Kotlin 用 Regex 类封装正则功能，创建方式是调用 Regex 构造函数或字符串的 toRegex() 扩展函数。

推荐用原始字符串写正则，这样反斜杠只需要写一次。

**实例**

```kotlin
fun main() {
    // 原始字符串中的 \d 就是正则的数字，不需要写 \\d
    val regex = Regex("""\d+""")

    // matches：整个字符串是否匹配
    println(regex.matches("12345"))             // true
    println(regex.matches("abc123"))            // false

    // containsMatchIn：是否包含任意一处匹配
    println(regex.containsMatchIn("订单号 abc123"))  // true

    // 等价写法：用 toRegex() 把字符串转成正则
    val same = """\d+""".toRegex()
    println(same.matches("2026"))               // true
}
```

```text
true
false
true
true
```

### find 与 findAll

find() 返回第一个匹配结果，findAll() 返回所有匹配结果的序列。

**实例**

```kotlin
fun main() {
    val regex = Regex("""\d+""")
    val text = "Runoob 2026 年 9 月 8 日"

    // find 返回 MatchResult?，可能为 null
    val first = regex.find(text)
    println(first?.value)                              // 2026
    println(first?.range)                              // 7..10

    // findAll 返回 Sequence<MatchResult>，用 map 取出内容
    val all = regex.findAll(text).map { it.value }.toList()
    println(all)                                       // [2026, 9, 8]

    // 也可以只取前两个
    val firstTwo = regex.findAll(text).take(2).map { it.value }.toList()
    println(firstTwo)                                  // [2026, 9]
}
```

```text
2026
7..10
[2026, 9, 8]
[2026, 9]
```

MatchResult 的 value 是匹配到的文本，range 是它在原字符串中的下标区间。

### replace 与 split

replace() 可以把所有匹配替换成指定内容，split() 可以按匹配切分字符串。

**实例**

```kotlin
fun main() {
    val regex = Regex("""\d+""")

    // 替换所有匹配
    println(regex.replace("a1b2c3", "#"))          // a#b#c#

    // 用 lambda 自定义替换内容，it 是匹配结果
    println(regex.replace("a1b2c3") { "<${it.value}>" })  // a<1>b<2>c<3>

    // 按匹配切分
    println("a1b2c3".split(regex))                 // [a, b, c]

    // 只替换第一个匹配
    println(regex.replaceFirst("a1b2", "#"))       // a#b2
}
```

```text
a#b#c#
a<1>b<2>c<3>
[a, b, c]
a#b2
```

### 捕获组

用圆括号可以把正则的一部分括成捕获组，匹配后可以单独取出每一组的内容。

groupValues[0] 是整体匹配，之后依次是第 1、2、3 个捕获组。

**实例**

```kotlin
fun main() {
    // 三个捕获组：年、月、日
    val regex = Regex("""(\d{4})-(\d{2})-(\d{2})""")

    // matchEntire 要求整个字符串完全匹配
    val match = regex.matchEntire("2026-09-08")
    if (match != null) {
        println(match.groupValues)        // [2026-09-08, 2026, 09, 08]
        println(match.groupValues[1])     // 2026
        println(match.groupValues[2])     // 09
        println(match.groupValues[3])     // 08
    }

    // 命名捕获组写法：(?<名称>...)
    val named = Regex("""(?<year>\d{4})-(?<month>\d{2})""")
    val m = named.find("日期：2026-09")!!
    println(m.groups["year"]?.value)      // 2026
    println(m.groups["month"]?.value)     // 09
}
```

```text
[2026-09-08, 2026, 09, 08]
2026
09
08
2026
09
```

matchEntire() 和 matches() 都要求整个字符串匹配，区别是前者返回 MatchResult?，后者只返回 Boolean。

### 正则选项

构造 Regex 时可以传入 RegexOption 来改变匹配行为，例如忽略大小写、多行模式。

**实例**

```kotlin
fun main() {
    // IGNORE_CASE：忽略大小写
    val regex = Regex("runoob", RegexOption.IGNORE_CASE)
    println(regex.containsMatchIn("欢迎来到 RUNOOB"))   // true
    println(regex.matches("RUNOOB"))                    // true

    // 多个选项用 setOf 传入
    val multi = Regex("""^\d+""", setOf(RegexOption.MULTILINE))
    val text = "123\n456"
    println(multi.findAll(text).map { it.value }.toList())  // [123, 456]
}
```

```text
true
true
[123, 456]
```

> **提示：**如果正则中需要匹配字符 `.`、`*`、`+`、`?`、`(` 等本身，必须加反斜杠转义，或者用 `Regex.escape()` 把普通字符串转成安全的正则片段。

---

## 常见问题

下面是使用字符串和正则时最常见的几个问题。

### 为什么修改字符串后原值没变

因为 String 是不可变的，所有"修改"方法都返回新对象。

要把结果保存下来，必须用变量接收返回值，例如 `val s2 = s.replace("a", "b")`。

### 原始字符串里怎么输出 $

原始字符串不支持反斜杠转义，所以要写成 `${'$'}`。

转义字符串里直接写 `\$` 即可。

### 字符串拼接用 + 还是模板

少量拼接用字符串模板最清晰，可读性也最好。

循环中大量拼接必须用 StringBuilder，否则每次 + 都会创建新字符串。

### matches 和 find 有什么区别

matches() 要求整个字符串完全匹配，返回 Boolean。

find() 只要字符串中任意位置出现匹配就返回结果，返回 MatchResult?。

### 正则里为什么要用三个引号

普通字符串中的反斜杠需要写两次，例如 `"\\d+"`，容易写错。

原始字符串 `"""\d+"""` 里反斜杠只写一次，更接近正则本身的写法。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-string.html)，版权归原作者所有，仅供非商业学习使用。
