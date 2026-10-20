异常是程序运行过程中出现的意外情况，Kotlin 用 try-catch 捕获它们，让程序在出错后仍能继续执行。

与 Java 相比，Kotlin 最大的不同是没有受检异常，编译器不再强迫你为每个方法声明它可能抛出的异常。

本章节从异常层次讲到资源自动关闭，覆盖日常开发中会用到的全部异常处理手段。

---

## 异常层次

Kotlin 的异常体系与 JVM 一致，根类型是 `Throwable`，下面分成 Error 和 Exception 两支。

![Kotlin 异常层次树：Throwable 分为 Exception 与 Error，Exception 下有 RuntimeException 和 IOException，Error 下有 OutOfMemoryError 和 StackOverflowError](images/kotlin/kotlin-exception/31-exception-tree.svg)

| 类型 | 含义 | 典型子类 | 是否应该捕获 |
| --- | --- | --- | --- |
| Throwable | 所有可抛出对象的根类型 | Exception、Error | 一般不直接捕获 |
| Error | JVM 层面的严重错误，程序通常无法恢复 | OutOfMemoryError、StackOverflowError | 不建议捕获 |
| Exception | 程序逻辑或运行环境导致的问题，可以恢复 | IOException、IllegalArgumentException | 应该处理 |
| RuntimeException | 运行时才暴露的异常，Kotlin 中没有受检异常，绝大多数异常属于这一支 | NullPointerException、IndexOutOfBoundsException | 按需处理 |

> **提示：**不要把 Error 也一并捕获。像内存耗尽、栈溢出这类问题，即使捕获了也无从恢复，反而会掩盖真正的故障。

---

## try-catch-finally

try 块放可能出错的代码，catch 块按异常类型依次匹配，finally 块无论是否发生异常都会执行。

catch 的匹配是从上到下的，因此子类型要写在父类型前面。

**实例**

```kotlin
fun main() {
    // 依次处理三种输入，观察不同 catch 分支的匹配
    val inputs = listOf("42", "runoob", null)

    for (input in inputs) {
        try {
            // input 是 String?，!! 在遇到 null 时抛出 NullPointerException
            val value: Int = input!!.toInt()
            println("$input 转换成功：$value")
        } catch (e: NumberFormatException) {
            // 字符串不是合法数字时进入这里
            println("数字格式错误：${e.message}")
        } catch (e: NullPointerException) {
            println("遇到 null 值")
        } finally {
            // 无论成功还是失败都会执行，适合放清理逻辑
            println("--- 处理完一轮 ---")
        }
    }

    println("循环结束，程序继续运行")
}
```

```text
42 转换成功：42
--- 处理完一轮 ---
数字格式错误：For input string: "runoob"
--- 处理完一轮 ---
遇到 null 值
--- 处理完一轮 ---
循环结束，程序继续运行
```

如果某个异常没有被任何 catch 分支匹配，它会继续向上传播给调用者，最终导致程序终止并打印堆栈。

---

## try 作为表达式

在 Kotlin 中 try 是表达式而不是语句，它可以有返回值，返回值是 try 或 catch 块中最后一个表达式的结果。

这一点让「尝试转换，失败时给默认值」这类逻辑可以写得很紧凑。

**实例**

```kotlin
// try 的返回值直接作为函数返回值
fun parseAge(text: String): Int {
    return try {
        text.toInt()          // 成功时整个 try 表达式的值
    } catch (e: NumberFormatException) {
        -1                    // 失败时整个 try 表达式的值
    }
}

fun main() {
    println(parseAge("18"))
    println(parseAge("runoob"))

    // finally 块的返回值会被忽略，不会影响 try 表达式的结果
    val age = try {
        "20".toInt()
    } finally {
        println("finally 块执行了，但不影响 try 的值")
    }
    println(age)
}
```

```text
18
-1
finally 块执行了，但不影响 try 的值
20
```

> **注意：**不要在 finally 块里写 return。这会让 try 和 catch 中的返回值被丢弃，也会吞掉正在传播的异常，是很容易出错的写法。

---

## throw 与 Nothing

用 `throw` 主动抛出异常，表达式本身永远不会有返回值，因此它的类型是 `Nothing`。

`Nothing` 是 Kotlin 所有类型的子类型，表示「此处不会正常返回」，编译器会据此做控制流分析。

**实例**

```kotlin
// 返回类型 Nothing 表示这个函数永远不会正常返回
fun fail(message: String): Nothing {
    throw IllegalArgumentException(message)
}

fun checkAge(age: Int): String {
    // 因为 fail 返回 Nothing，编译器知道这里之后不会继续往下走
    if (age < 0) fail("年龄不能为负数：$age")
    return "年龄合法：$age"
}

fun main() {
    println(checkAge(18))

    try {
        checkAge(-1)
    } catch (e: IllegalArgumentException) {
        println("捕获到异常：${e.message}")
    }
}
```

```text
年龄合法：18
捕获到异常：年龄不能为负数：-1
```

标准库里的 `error()`、`TODO()` 以及 `throw` 表达式，返回类型都是 `Nothing`，它们的作用就是把「不可能继续」这件事告诉编译器。

---

## 自定义异常

当内置异常无法表达业务语义时，可以继承 Exception 定义自己的异常类型。

把出错的上下文作为属性保存下来，捕获时就能拿到更多信息。

**实例**

```kotlin
// 自定义异常通常继承 Exception；把出错的具体字段作为属性保留
class InvalidSiteNameException(val siteName: String) : Exception("非法的站点名称：$siteName")

fun registerSite(name: String) {
    // 站点名必须以 runoob 开头（不区分大小写），否则抛出自定义异常
    if (!name.startsWith("runoob", ignoreCase = true)) {
        throw InvalidSiteNameException(name)
    }
    println("注册成功：$name")
}

fun main() {
    registerSite("runoob")

    try {
        registerSite("example")
    } catch (e: InvalidSiteNameException) {
        // e.siteName 是自定义异常携带的上下文信息
        println("注册失败：${e.message}，问题字段：${e.siteName}")
    }
}
```

```text
注册成功：runoob
注册失败：非法的站点名称：example，问题字段：example
```

命名上建议以 `Exception` 结尾，并保留一个接收 `message` 和 `cause` 的构造器，方便异常链向上传递。

---

## Kotlin 没有受检异常

Java 把异常分为受检异常和非受检异常，受检异常必须显式 try-catch 或在方法签名上声明 throws。

Kotlin 取消了这个区分，所有异常都是非受检的，编译器不会强制你处理它们。

| 对比项 | Java | Kotlin |
| --- | --- | --- |
| 异常分类 | 受检异常 + 非受检异常 | 只有非受检异常 |
| 方法声明 | 受检异常必须写 throws | 不需要声明 |
| 调用方义务 | 编译器强制处理受检异常 | 编译器不强制，自行决定 |
| 与 Java 互操作 | 不适用 | 用 `@Throws` 告知 Java 调用方 |

**实例**

```kotlin
import java.io.IOException

// @Throws 只在 Java 调用方需要 catch 时使用，Kotlin 侧写不写都一样
@Throws(IOException::class)
fun readConfig(path: String): String {
    if (path.isEmpty()) throw IOException("配置路径为空")
    return "配置来自 $path"
}

fun main() {
    // Kotlin 不强制 try-catch，但异常依然会在运行时抛出
    println(readConfig("runoob.conf"))

    try {
        readConfig("")
    } catch (e: IOException) {
        println("读取失败：${e.message}")
    }
}
```

```text
配置来自 runoob.conf
读取失败：配置路径为空
```

> **注意：**取消受检异常不等于不用处理异常。Kotlin 把「是否处理」的决定权交回给开发者，代价是漏掉 catch 时只能在运行时才发现问题。

---

## use 与资源自动关闭

文件、流、数据库连接这类资源使用完必须关闭，否则会泄漏句柄。

Kotlin 用扩展函数 `use` 替代 Java 的 try-with-resources，无论块内是否抛出异常，它都会调用 `close()`。

**实例**

```kotlin
import java.io.File

fun main() {
    // use 会在代码块结束后自动调用 close()，即使块内抛出了异常
    File("runoob.txt").bufferedWriter().use { writer ->
        writer.write("Hello RUNOOB")
        writer.newLine()                  // 写入换行符
        writer.write("Hello Kotlin")
    }

    // 读取刚才写入的内容
    File("runoob.txt").bufferedReader().use { reader ->
        reader.forEachLine { line -> println(line) }
    }

    // useLines 一次读取全部行，块结束后自动关闭文件
    File("runoob.txt").useLines { lines ->
        println("总行数：${lines.count()}")
    }
}
```

```text
Hello RUNOOB
Hello Kotlin
总行数：2
```

`use` 适用于所有实现了 `Closeable` 或 `AutoCloseable` 的对象，返回值为代码块最后一行表达式的结果，因此也可以这样写：

下面的例子沿用上一段示例生成的 runoob.txt，请先运行上一段代码，或者确保当前目录下已存在这个文件。

**实例**

```kotlin
import java.io.File

fun main() {
    // use 的返回值就是块内最后一行，这里得到文件的行数
    val lineCount: Int = File("runoob.txt").useLines { lines -> lines.count() }
    println("文件共有 $lineCount 行")
}
```

```text
文件共有 2 行
```

---

## runCatching

`runCatching` 把「执行 + 捕获」合并成一个表达式，成功和失败都包装进 `Result` 对象。

适合那些「失败是正常分支」的场景，比如解析用户输入、读取可能不存在的配置。

| 方法 | 作用 |
| --- | --- |
| isSuccess / isFailure | 判断结果是成功还是失败 |
| getOrNull | 成功时返回值，失败时返回 null |
| getOrDefault | 失败时返回指定的默认值 |
| getOrElse | 失败时用异常计算一个兜底值 |
| getOrThrow | 失败时重新抛出异常 |
| onSuccess / onFailure | 成功或失败时执行副作用，返回原 Result |

**实例**

```kotlin
fun main() {
    // 成功与失败都会被包装成 Result，不会中断程序
    val ok = runCatching { "42".toInt() }
    val bad = runCatching { "runoob".toInt() }

    println("成功：isSuccess=${ok.isSuccess}，值=${ok.getOrNull()}")
    println("失败：isFailure=${bad.isFailure}，值=${bad.getOrNull()}")
    println("失败时给默认值：${bad.getOrDefault(-1)}")

    // getOrElse 拿到异常，可以据此拼出兜底值
    val fallback = bad.getOrElse { e -> "兜底(${e.message})" }
    println("兜底结果：$fallback")

    // onFailure 适合打日志，不影响后续流程
    runCatching { "x".toInt() }
        .onFailure { println("onFailure：${it.javaClass.simpleName}") }
}
```

```text
成功：isSuccess=true，值=42
失败：isFailure=true，值=null
失败时给默认值：-1
兜底结果：兜底(For input string: "runoob")
onFailure：NumberFormatException
```

`runCatching` 从 Kotlin 1.3 起提供，它返回的 `Result` 类型在 1.5 起稳定。

> **注意：**runCatching 捕获的是 Throwable，会把协程的 CancellationException 也一并吞掉，导致协程无法正常取消。在协程里使用时，要么改用 try-catch 只捕获具体异常，要么在失败分支里把 CancellationException 重新抛出。

---

## 常见问题

下面汇总异常处理中最常见的几个疑问。

| 问题 | 原因 | 建议 |
| --- | --- | --- |
| catch 分支不生效 | 父类型写在子类型前面，先被匹配走了 | 把更具体的异常类型写在前面 |
| 捕获了异常却定位不到问题 | 只打印 message，丢了堆栈 | 用 `e.printStackTrace()` 或日志框架记录完整异常 |
| finally 里的 return 导致结果异常 | finally 的返回值会覆盖 try 的结果 | finally 只做清理，不要写 return |
| 资源没关闭 | 忘了在 finally 里调用 close | 统一改用 use 或 useLines |
| 捕获范围过宽 | 直接 catch Throwable 或 Exception | 尽量捕获具体类型，让意外异常正常暴露 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-exception.html)，版权归原作者所有，仅供非商业学习使用。
