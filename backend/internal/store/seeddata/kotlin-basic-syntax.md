本文从包声明和程序入口开始，逐步介绍 Kotlin 最基础也最常用的语法要素。

这些规则几乎会出现在之后每一篇教程里，值得先花时间弄明白。

---

## 包声明与 import

包声明写在源文件最上方，用来给代码分组并避免命名冲突。

包名不要求与目录结构完全一致，但保持一致是通行做法，工程上几乎都会遵守。

**实例**

```kotlin
// 文件路径：com/runoob/Util.kt
package com.runoob                    // 包声明必须在文件第一行（注释除外）

import kotlin.math.PI                 // 导入单个声明
import kotlin.math.sqrt               // 每行导入一个

fun circleArea(r: Double): Double = PI * r * r

fun main() {
    println("半径 2 的圆面积：${sqrt(circleArea(2.0) / PI)}")
}
```

输出结果如下。

```text
半径 2 的圆面积：2.0
```

如果名字冲突，可以用 `as` 给导入的声明起个别名。

**实例**

```kotlin
// 文件路径：Alias.kt
import kotlin.math.PI as PI_VALUE      // 起别名，避免与同名符号冲突
import java.util.Date as JavaDate      // 区分两个不同来源的同名类

fun main() {
    println("圆周率约等于 $PI_VALUE")
    println(JavaDate::class.java.simpleName)
}
```

```text
圆周率约等于 3.141592653589793
Date
```

用 `*` 可以一次性导入某个包下的所有声明。

**实例**

```kotlin
// 文件路径：Wildcard.kt
import kotlin.math.*                   // 导入 kotlin.math 下的全部声明

fun main() {
    println(max(3, 7))                 // 无需再写 kotlin.math.max
    println(abs(-5))
}
```

```text
7
5
```

---

## 默认导入的包

为了减少样板代码，Kotlin 默认已经导入了一批常用包，写代码时无需手动 import。

| 默认导入 | 包含内容 |
| --- | --- |
| kotlin.* | 标准库核心，如 Int、String、println、arrayOf |
| kotlin.annotation.* | 注解相关，如 Target、Retention |
| kotlin.collections.* | 集合类型，如 List、Set、Map |
| kotlin.comparisons.* | 比较器工具，如 compareBy、naturalOrder |
| kotlin.io.* | 输入输出，如 readln、readLine |
| kotlin.ranges.* | 区间，如 IntRange、until |
| kotlin.sequences.* | 序列，如 sequenceOf、generateSequence |
| kotlin.text.* | 字符串与正则，如 Regex、StringBuilder |
| java.lang.* | JVM 平台额外默认导入，仅 Kotlin/JVM 有效 |
| kotlin.jvm.* | JVM 平台相关工具，仅 Kotlin/JVM 有效 |

最后两行是 JVM 后端特有的，编译到 JS 或 Native 时不存在。

因此 `println`、`listOf`、`Regex` 这些都用不着 import。

---

## 程序入口 main

Kotlin 程序的入口是 `main` 函数，它必须写在顶层，也就是不属于任何类。

最简形式不接收参数，等价于 Java 的 `public static void main(String[] args)`。

**实例**

```kotlin
// 文件路径：Main.kt
fun main() {
    println("Hello, Runoob!")
}
```

```text
Hello, Runoob!
```

需要读取命令行参数时，用带参数的写法，参数类型是字符串数组。

**实例**

```kotlin
// 文件路径：Args.kt
fun main(args: Array<String>) {
    println("参数个数：${args.size}")                 // 未传参时为 0
    val name = args.firstOrNull() ?: "Runoob"         // 没有参数时给个默认值
    println("欢迎访问 $name")
}
```

执行 `kotlinc -script` 或直接运行时带上参数，输出如下。

```text
$ kotlinc Args.kt -include-runtime -d args.jar
$ java -jar args.jar 菜鸟教程

参数个数：1
欢迎访问 菜鸟教程
```

Kotlin 1.3 起还支持挂起函数作为入口，写法是 `suspend fun main()`。

它在协程中运行，可以直接调用其他挂起函数，常用于命令行工具和协程示例。

**实例**

```kotlin
// 文件路径：SuspendMain.kt
// suspend fun main 从 Kotlin 1.3 起支持，入口本身就是一个挂起函数
suspend fun fetchSite(): String {
    return "www.runoob.com"        // 真实场景中这里可能是网络请求
}

suspend fun main() {
    println("正在获取站点信息…")
    println("站点地址：" + fetchSite())
}
```

```text
正在获取站点信息…
站点地址：www.runoob.com
```

> **提示：**一个文件里可以同时存在普通 `main` 和 `suspend main` 吗？不行，JVM 入口只能有一个，同时写会编译报错。

---

## 变量与常量

Kotlin 用 `val` 声明不可变变量，用 `var` 声明可变变量。

val 相当于 Java 的 final 变量，一旦赋值就不能再指向别的对象。

**实例**

```kotlin
// 文件路径：Variables.kt
fun main() {
    val siteName = "菜鸟教程"        // val：不可重新赋值
    var count = 1                   // var：可以重新赋值

    count = count + 1               // 合法，count 是 var
    println("$siteName 第 $count 次访问")

    // siteName = "RUNOOB"          // 取消注释会编译报错：Val cannot be reassigned
}
```

```text
菜鸟教程 第 2 次访问
```

官方风格指南建议优先使用 `val`，只有在确实需要修改时才用 `var`。

这样能减少状态变化，让代码更容易推理和测试。

### 类型推断

声明变量时可以省略类型，编译器会根据初始值自动推断。

**实例**

```kotlin
// 文件路径：Inference.kt
fun main() {
    val name = "Runoob"             // 推断为 String
    val age = 25                    // 推断为 Int
    val price = 9.9                 // 推断为 Double
    val isOpen = true               // 推断为 Boolean

    println("$name $age $price $isOpen")
    println(name::class.simpleName) // 打印运行时类型名
}
```

```text
Runoob 25 9.9 true
String
```

也可以显式写出类型，声明与赋值分开时就必须写。

**实例**

```kotlin
// 文件路径：ExplicitType.kt
fun main() {
    val siteName: String = "菜鸟教程"    // 显式指定类型
    var age: Int                         // 只声明不赋值，此时必须写类型

    age = 25                             // 之后再赋值
    println("$siteName，age = $age")
}
```

```text
菜鸟教程，age = 25
```

> **注意：**只声明不赋值时，编译器无法推断类型，必须显式写出。var 允许先声明后赋值，val 则必须在声明处就完成赋值。

---

## 注释

Kotlin 的注释分为单行注释和块注释，写法和 C 系语言一致。

单行注释以两个斜杠开头，块注释用一对斜杠星号包起来。

**实例**

```kotlin
// 文件路径：Comments.kt

// 这是单行注释，从 // 到行尾都会被忽略

/*
 * 这是块注释
 * 可以跨越多行
 */
fun main() {
    println("RUNOOB")     // 行尾注释
}
```

运行结果如下，注释部分不会产生任何输出。

```text
RUNOOB
```

和 Java 不同的是，Kotlin 的块注释可以嵌套。

这个特性在注释掉一段已经含有块注释的代码时非常实用。

**实例**

```kotlin
// 文件路径：NestedComment.kt
/* 外层注释开始
   /* 内层注释，Kotlin 允许块注释嵌套 */
   外层注释继续
   到这里才真正结束 */
fun main() {
    println("注释嵌套测试通过")
}
```

```text
注释嵌套测试通过
```

Java 的块注释不能嵌套，所以同样的写法在 Java 里会导致编译错误。

---

## 字符串模板

字符串模板是 Kotlin 最讨喜的语法之一，可以直接在字符串里引用变量。

用 `$` 加变量名即可，简单表达式用 `${}` 包起来。

**实例**

```kotlin
// 文件路径：Template.kt
fun main() {
    val siteName = "菜鸟教程"
    val url = "www.runoob.com"

    println("欢迎访问 $siteName")                  // 直接引用变量
    println("网址：${url.uppercase()}")            // 花括号里可以放表达式
    println("名称长度：${siteName.length}")         // 调用属性
    println("明年将是 ${2026 - 2010} 周年")         // 算术表达式
}
```

```text
欢迎访问 菜鸟教程
网址：WWW.RUNOOB.COM
名称长度：4
明年将是 16 周年
```

如果 `$` 后面跟的不是合法标识符，就不需要转义。

想在字符串里输出美元符号本身，用反斜杠转义即可。

**实例**

```kotlin
// 文件路径：Dollar.kt
fun main() {
    println("价格是 \$9.9")            // 转义美元符号
    println("5\$ 可以买到 1 份教程")     // 这里的 \$ 也按普通字符处理
}
```

```text
价格是 $9.9
5$ 可以买到 1 份教程
```

---

## 分号可省略

Kotlin 不要求语句末尾写分号，换行本身就代表语句结束。

写成一行时可以用分号分隔，但官方风格指南不推荐。

**实例**

```kotlin
// 文件路径：Semicolon.kt
fun main() {
    val a = 1                      // 推荐：一行一句，不写分号
    val b = 2

    val c = 3; val d = 4           // 合法但不推荐：一行多句用分号

    println("${a + b} ${c + d}")
}
```

```text
3 7
```

要注意换行位置，Kotlin 按换行切分语句，某些跨行表达式会被误解。

**实例**

```kotlin
// 文件路径：LineBreak.kt
fun main() {
    val x = 1 +
            2                      // 运算符在行尾，表达式可以跨行

    val y = 10
    - 3                          // 这里会被当成两条语句：val y = 10 与 -3

    println("x = $x, y = $y")    // y 仍然是 10
}
```

```text
x = 3, y = 10
```

把减号写在上一行行尾，才能得到 `y = 7` 的结果。

---

## 空安全初探

Kotlin 把「可能为 null」这件事编码进类型系统，这是它和 Java 最大的差异之一。

类型后面加问号表示可空，不加问号表示一定不为空。

**实例**

```kotlin
// 文件路径：NullSafety.kt
fun main() {
    val notNull: String = "Runoob"        // 非空类型，不能赋 null
    val maybeNull: String? = null         // 可空类型，允许赋 null

    println(notNull.length)               // 非空类型可以直接访问成员

    // println(maybeNull.length)          // 编译报错：Only safe call allowed
    println(maybeNull?.length)            // 安全调用，结果为 null
    println(maybeNull?.length ?: 0)       // Elvis 运算符，为 null 时给默认值
}
```

```text
6
null
0
```

可空类型不能直接调用成员，必须先用 `?.` 或 `?:` 处理。

正是这条规则，让 Kotlin 在编译期就消除了绝大部分空指针异常。

> **提示：**空安全涉及 `?.`、`?:`、`!!`、`lateinit`、平台类型等多个主题，本文只做初步认识，完整内容见第 27 篇《Kotlin 空安全》。

---

## 常见问题

下面几个坑在初学阶段出现频率最高。

### Val cannot be reassigned

试图给 val 变量重新赋值，改成 var，或者换一个变量名。

### Unresolved reference

拼写错误，或者忘记 import 对应的包。IDEA 里按 Alt+Enter 可以自动补全导入。

### 顶层 main 函数报错

确认 main 写在文件顶层而不是某个类内部，参数类型必须是 `Array<String>`。

### 字符串模板里 $ 后面跟了非法字符

改成 `${'$'}` 或者用反斜杠转义。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-basic-syntax.html)，版权归原作者所有，仅供非商业学习使用。
