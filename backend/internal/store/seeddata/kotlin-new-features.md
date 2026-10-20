Kotlin 从 2016 年发布 1.0 到 2025 年的 2.2，语言在十年间不断补齐能力、稳定实验特性。

本章节按版本顺序梳理关键新特性，并给出从旧版本升级的迁移建议，方便你在实际项目中判断哪些写法可以用、从哪个版本起可用。

---

## 版本时间线

先建立整体印象：每个大版本解决什么问题，什么时候可以放心使用。

下表列出 1.0 到 2.2 的发布时间与里程碑特性。

| 版本 | 发布时间 | 里程碑特性 |
| --- | --- | --- |
| 1.0 | 2016 年 2 月 | 首个正式版本，JVM 目标稳定 |
| 1.1 | 2017 年 3 月 | 协程实验性引入、typealias、sealed 子类同文件 |
| 1.2 | 2017 年 11 月 | 多平台项目、expect/actual |
| 1.3 | 2018 年 10 月 | 内联类、无符号类型、契约 |
| 1.4 | 2020 年 8 月 | SAM 转换、sealed interface、尾逗号 |
| 1.5 | 2021 年 5 月 | 值类稳定、JVM records、invokedynamic 字符串拼接 |
| 1.6 | 2021 年 11 月 | 密封类 when 语句穷尽、协程稳定 |
| 1.7 | 2022 年 6 月 | K2 编译器 Alpha、..< 运算符 |
| 1.8 | 2022 年 12 月 | Enum.entries、data object |
| 1.9 | 2023 年 7 月 | ..< 稳定、data object 与 entries 稳定 |
| 2.0 | 2024 年 5 月 | K2 编译器正式发布、when 守卫、智能转换增强 |
| 2.1 | 2024 年 11 月 | 上下文参数重构、嵌套 typealias |
| 2.2 | 2025 年 6 月 | when 守卫稳定、非局部 break/continue 稳定 |

![Kotlin 版本演进时间线：从 2016 年 1.0 到 2025 年 2.2，2.0 是 K1 与 K2 的分水岭，每个版本标注关键特性](images/kotlin/kotlin-new-features/40-version-timeline.svg)

> **提示：**本章节以 Kotlin 2.2 为基准。表中带「实验性」「预览」字样的特性需要额外开启或加 @OptIn 注解，正式项目请谨慎使用。

---

## 1.0 到 1.4：补齐语言基础能力

这四个版本主要解决「Kotlin 能不能做某件事」的问题，很多今天我们习以为常的语法都是在这个阶段引入的。

### 1.1：协程、typealias 与 sealed 同文件

协程在这个版本首次以实验特性出现，后来成为 Kotlin 处理异步任务的核心方案。

typealias 让复杂类型有了短名字，函数类型和泛型签名因此清爽很多。

sealed 类的子类限制也从「必须内嵌」放宽为「同一文件即可」。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/TypeAliasDemo.kt
package com.runoob

// Kotlin 1.1 起支持类型别名
typealias UserId = Int

// Kotlin 1.1 起，sealed 类的子类只需在同一个文件里
sealed class State
class Loading : State()
class Done : State()

fun findUserName(id: UserId): String = "用户 $id"

fun main() {
    println(findUserName(1001))
}
```

输出结果如下。

```text
用户 1001
```

到了 Kotlin 1.5，sealed 类的子类限制进一步放宽到「同一个包和模块」，不再要求同一个文件。

### 1.2：expect/actual 与多平台

1.2 让 Kotlin 真正具备多平台能力，公共代码用 expect 声明，各平台用 actual 提供实现。

这是 Kotlin Multiplatform 的基础机制。

**实例**

```kotlin
// 文件路径：src/commonMain/kotlin/com/runoob/Platform.kt
// 公共源码集：只声明，不实现
expect fun platformName(): String

fun greet(): String = "运行平台：${platformName()}"
```

**实例**

```kotlin
// 文件路径：src/jvmMain/kotlin/com/runoob/Platform.jvm.kt
// JVM 源码集：提供与 expect 对应的 actual 实现
actual fun platformName(): String = "JVM"
```

调用 greet() 时，JVM 平台上的输出如下。

```text
运行平台：JVM
```

### 1.3：内联类、无符号类型与契约

无符号整数类型补齐了 UInt、ULong 等类型，处理二进制协议时不必再绕开符号位。

契约（contracts）让开发者能告诉编译器函数的行为，从而改善智能转换。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/UnsignedDemo.kt
package com.runoob

import kotlin.contracts.ExperimentalContracts
import kotlin.contracts.contract

// Kotlin 1.3 起引入无符号整数类型，1.5 起稳定
val maxValue: UInt = UInt.MAX_VALUE

// Kotlin 1.3 起引入契约：函数正常返回就说明参数不为 null
// 契约 API 目前仍是实验性的，需要加 @OptIn 才能使用
@OptIn(ExperimentalContracts::class)
fun requireText(value: String?): String {
    contract { returns() implies (value != null) }
    if (value == null) throw IllegalArgumentException("内容不能为空")
    return value
}

fun main() {
    println(maxValue)
    println(0xFFu)
    val text: String? = "RUNOOB"
    println(requireText(text).length)
}
```

输出结果如下。

```text
4294967295
255
6
```

这个版本引入的 inline class 在 1.5 中改名为 value class，详见下一节。

### 1.4：SAM 转换、sealed interface 与尾逗号

fun interface 让 Kotlin 自己的接口也能用 lambda 实现，不必再为 Java 接口专设转换。

sealed interface 补上了密封体系里缺失的一环，尾逗号则让多行列表的 diff 更干净。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/SamDemo.kt
package com.runoob

// Kotlin 1.4 起，声明为 fun interface 的接口支持 SAM 转换
fun interface ClickHandler {
    fun onClick(name: String)
}

// Kotlin 1.4 起支持 sealed interface
sealed interface Result
data class Success(val data: String) : Result
data class Failure(val message: String) : Result

fun main() {
    // 用 lambda 直接实现接口
    val handler = ClickHandler { println("点击了 $it") }
    handler.onClick("RUNOOB")

    // 多行参数列表的尾逗号，1.4 起允许
    val site = mapOf(
        "name" to "Runoob",
        "url" to "www.runoob.com",
    )
    println(site)
}
```

输出结果如下。

```text
点击了 RUNOOB
{name=Runoob, url=www.runoob.com}
```

---

## 1.5 到 1.9：稳定与实用化

这几个版本的关键词是「稳定」，大量实验特性转为正式特性，同时 K2 编译器开始酝酿。

### 1.5：值类、JVM records 与 invokedynamic

内联类正式改名为值类并稳定，用它包装基本类型可以避免额外对象分配。

JVM 9 及以上目标默认使用 invokedynamic 做字符串拼接，运行效率更高。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/ValueClassDemo.kt
package com.runoob

// Kotlin 1.5 起值类稳定，编译后多数场景不产生包装对象
@JvmInline
value class UserId(val value: Int)

fun main() {
    val id = UserId(1001)
    println(id.value)
    println(id)
}
```

输出结果如下。

```text
1001
UserId(value=1001)
```

如果需要与 Java 的 record 互操作，可以用 @JvmRecord 注解数据类，前提是 JDK 16 及以上。

**实例**

```kotlin
// Kotlin 1.5 起支持声明 JVM record，要求 JDK 16+
@JvmRecord
data class Point(val x: Int, val y: Int)
```

### 1.6：密封 when 与稳定协程

when 语句此前只在作为表达式时才要求穷尽，1.6 起作为语句也要求覆盖所有分支。

协程在这一版进入稳定阶段，挂起函数还可以作为父类型使用。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/SealedWhenDemo.kt
package com.runoob

sealed class State
object Loading : State()
object Done : State()

// Kotlin 1.6 起，when 语句（不只是表达式）也必须穷尽所有分支
fun describe(state: State) {
    when (state) {
        Loading -> println("加载中")
        Done -> println("完成")
    }
}

fun main() {
    describe(Loading)
    describe(Done)
}
```

输出结果如下。

```text
加载中
完成
```

### 1.7：K2 Alpha 与 ..< 运算符

K2 是 Kotlin 的新一代编译器前端，1.7 起进入 Alpha 阶段，可以用参数提前体验。

同一版本引入了左闭右开区间运算符 ..<，遍历到边界时不用再写减一。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/RangeDemo.kt
package com.runoob

fun main() {
    // Kotlin 1.7 起引入 ..< 运算符，1.9 起稳定
    for (i in 0..<3) {
        println(i)
    }
}
```

输出结果如下。

```text
0
1
2
```

### 1.8：Enum.entries 与 data object

entries 取代 values()，返回的是不可变列表，语义更清晰也更高效。

data object 让单例对象也拥有自动生成的 toString 与 equals。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/EntriesDemo.kt
package com.runoob

enum class Color { RED, GREEN, BLUE }

// Kotlin 1.8 起支持 data object
data object Runoob {
    const val SITE = "www.runoob.com"
}

fun main() {
    // 1.8 起推荐用 entries 代替 values()
    Color.entries.forEach { println(it) }
    println(Runoob)
    println(Runoob.SITE)
}
```

输出结果如下。

```text
RED
GREEN
BLUE
Runoob
www.runoob.com
```

### 1.9：..< 与 entries、data object 稳定

1.9 把 1.7 与 1.8 引入的实验特性转为正式特性，可以放心在生产环境使用。

同时 values() 在 1.9.20 起被标记为弃用，新代码应统一改用 entries。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/StableDemo.kt
package com.runoob

enum class Color { RED, GREEN, BLUE }

data object Runoob {
    const val SITE = "www.runoob.com"
}

fun main() {
    // ..< 在 1.9 起稳定
    println((0..<3).toList())
    // entries 在 1.9 起稳定
    println(Color.entries.map { it.name })
    // data object 在 1.9 起稳定
    println(Runoob)
}
```

输出结果如下。

```text
[0, 1, 2]
[RED, GREEN, BLUE]
Runoob
```

---

## 2.0 到 2.2：K2 时代

这三个版本围绕 K2 编译器展开，语言特性从「能用」走向「好用」。

### 2.0：K2 编译器正式发布

K2 是重写后的编译器前端，编译速度更快，类型推断和智能转换的能力也更强。

when 守卫条件在这一版以实验特性引入，可以在分支上加一个额外判断。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/WhenGuardDemo.kt
package com.runoob

sealed interface Response

data class Ok(val body: String) : Response
data class Error(val code: Int) : Response

fun handle(response: Response): String = when (response) {
    is Ok -> "成功：${response.body}"
    // 守卫条件：2.0 起引入，2.2 起稳定
    is Error if response.code == 404 -> "页面不存在"
    is Error -> "错误码 ${response.code}"
}

fun main() {
    println(handle(Ok("RUNOOB")))
    println(handle(Error(404)))
    println(handle(Error(500)))
}
```

输出结果如下。

```text
成功：RUNOOB
页面不存在
错误码 500
```

K2 还增强了智能转换，例如变量在检查后被其他代码修改的场景，编译器也能给出更准确的推断。

### 2.1：上下文参数重构与嵌套 typealias

2.1 把原来的上下文接收者重构为 context parameters，写法更接近普通参数。

该特性在 2.2 仍属预览，编译时需要加上 `-Xcontext-parameters` 参数，否则会报 "the feature "context parameters" is experimental"。

嵌套 typealias 允许在类或接口内部声明类型别名，封装性更好。

它同样需要显式开启，编译参数是 `-Xnested-type-aliases`。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/ContextDemo.kt
package com.runoob

class Logger {
    fun log(message: String) = println(message)
}

// Kotlin 2.1 起引入 context parameters 语法（预览特性）
context(logger: Logger)
fun greet(name: String) {
    logger.log("Hello, $name")
}

fun main() {
    // 通过隐式接收者提供上下文参数
    with(Logger()) {
        greet("Runoob")
    }
}
```

输出结果如下。

```text
Hello, Runoob
```

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/NestedAliasDemo.kt
package com.runoob

class User {
    // Kotlin 2.1 起支持嵌套类型别名（预览特性）
    typealias Id = Int

    fun find(id: Id): String = "用户 $id"
}

fun main() {
    println(User().find(1001))
}
```

输出结果如下。

```text
用户 1001
```

### 2.2：when 守卫稳定与非局部 break/continue

when 守卫条件在 2.2 转为稳定特性，不再需要加 @OptIn 注解。

非局部 break 与 continue 也稳定下来，lambda 里的跳转可以直接作用于外层循环。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/NonLocalBreakDemo.kt
package com.runoob

fun main() {
    // 2.2 起稳定：lambda 里的 break 可以跳出外层 for 循环
    for (i in 1..3) {
        listOf(1, 2, 3).forEach {
            if (it == 2) break   // 直接跳出外层循环
            print("$i-$it ")
        }
    }
    println()
}
```

输出结果如下。

```text
1-1
```

循环在第一轮内层遍历到 2 时直接跳出，因此只打印了 1-1 就结束。

---

## 迁移建议

升级 Kotlin 版本不是简单地改一个数字，需要按顺序处理兼容性问题。

新项目直接使用 Kotlin 2.2 与 K2 编译器，不需要考虑历史包袱。

存量项目建议逐个大版本升级，每次升完先跑通测试再继续，不要一次跨多个大版本。

| 阶段 | 要做的事 | 注意事项 |
| --- | --- | --- |
| 升级前 | 确认 Gradle、IDE、编译器插件的兼容版本 | kapt、Compose、序列化插件要同步升级 |
| 升到 1.9 | 把 values() 换成 entries，toUpperCase() 换成 uppercase() | 1.9.20 起 values() 已弃用 |
| 升到 2.0 | 切换到 K2 编译器，清理已废弃的语法 | 先在小模块验证，再全量切换 |
| 升到 2.1 | 评估 context parameters 与嵌套 typealias | 均为预览特性，生产代码谨慎使用 |
| 升到 2.2 | 启用 when 守卫与非局部 break/continue | 移除对应的 @OptIn 注解 |

Gradle 项目可以在 kotlin 配置块中通过 languageVersion 与 apiVersion 控制兼容性，逐步放开。

**实例**

```kotlin
// 文件路径：build.gradle.kts

kotlin {
    compilerOptions {
        // 语言版本决定哪些语法可用，先与旧版本保持一致再逐步提升
        languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_2)
        // API 版本决定能调用哪些标准库 API，应小于等于语言版本
        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_2)
    }
}
```

升级过程中最常见的报错来自已废弃的 API，把编译器警告当成待办清单逐条处理，往往比一次性升级更稳妥。

> **注意：**预览特性需要显式开启才能使用，并且可能在后续版本中改变语法。生产项目引入前请先确认官方文档中的稳定性说明。

---

## 常见问题

下面这些问题在选版本和升级时经常被问到。

### K2 是什么，和 Kotlin 版本是什么关系

K2 是新一代编译器前端的代号，不是独立的语言版本。

它在 Kotlin 1.7 进入 Alpha，1.9 进入 Beta，2.0 正式成为默认编译器。

### 怎么查看当前项目使用的 Kotlin 版本

命令行执行 kotlinc -version，或在 Gradle 项目中执行 ./gradlew buildEnvironment 查看插件版本。

### 预览特性怎么开启

使用对应的编译器参数开启，或在代码中加 @OptIn 注解。

例如 when 守卫在 2.0 与 2.1 需要开启预览参数，2.2 稳定后不再需要。

### 升级后编译报错怎么办

先看错误信息里的版本提示，多数是某个 API 已被移除或语法已变更。

可以先用 languageVersion 锁回旧版本，把问题逐个改完再放开。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-new-features.html)，版权归原作者所有，仅供非商业学习使用。
