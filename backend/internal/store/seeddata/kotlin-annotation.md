注解（Annotation）是一种给代码附加元数据的机制，它本身不影响程序逻辑，但能被编译器、框架和注解处理器读取。

Kotlin 的注解既能作用于 Kotlin 自身的声明，也能精确指定落到 JVM 的哪个位置，比如字段、getter 或 setter。

本章节讲注解的定义与元注解、参数类型、使用处目标，以及日常开发最常用的内置注解。

---

## 注解的定义与使用

用 `annotation class` 定义一个注解，它也可以有构造参数。

使用注解时把 `@注解名` 放在目标声明之前，带参数的注解用括号传入实参。

**实例**

```kotlin
// 定义一个注解：@Target 限定能用在哪里，@Retention 决定能否在运行时读到
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION)
@Retention(AnnotationRetention.RUNTIME)
@MustBeDocumented
annotation class ApiDoc(
    val author: String,                  // 必填参数
    val version: String = "1.0",         // 可选参数，有默认值
    val tags: Array<String> = []         // 数组参数
)

@ApiDoc(author = "RUNOOB", version = "2.2", tags = ["collection", "annotation"])
class SiteService {
    @ApiDoc(author = "RUNOOB")
    fun listSites(): List<String> = listOf("runoob", "RUNOOB")
}

fun main() {
    // 通过 Java 反射读取运行时注解，不需要额外引入 kotlin-reflect
    val clazz = SiteService::class.java
    val classDoc = clazz.getAnnotation(ApiDoc::class.java)
    println("类注解：author=${classDoc.author}, version=${classDoc.version}, tags=${classDoc.tags.toList()}")

    // 方法上的注解同样可以读取
    val method = clazz.getDeclaredMethod("listSites")
    val methodDoc = method.getAnnotation(ApiDoc::class.java)
    println("方法注解：author=${methodDoc.author}, version=${methodDoc.version}")
}
```

```text
类注解：author=RUNOOB, version=2.2, tags=[collection, annotation]
方法注解：author=RUNOOB, version=1.0
```

> **提示：**方法注解只写了 author，version 就取默认值 "1.0"。如果 `@Retention` 不是 RUNTIME，反射就读取不到这个注解。

---

## 元注解

元注解是「用来修饰注解的注解」，它们决定一个注解能用在哪里、保留到什么时候。

| 元注解 | 作用 | 可选值 |
| --- | --- | --- |
| @Target | 限定注解可以标注哪些目标 | CLASS、FUNCTION、PROPERTY、FIELD、VALUE_PARAMETER、CONSTRUCTOR、EXPRESSION、FILE 等 |
| @Retention | 决定注解保留到哪个阶段 | SOURCE、BINARY（默认）、RUNTIME |
| @Repeatable | 允许同一注解在同一位置重复出现 | 无参数，Kotlin 1.6 起支持 |
| @MustBeDocumented | 把注解包含进生成的 API 文档 | 无参数 |

三种保留级别对应不同的可见范围，选错级别会导致框架读不到注解。

| 保留级别 | 保存在何处 | 典型用途 |
| --- | --- | --- |
| SOURCE | 只存在于源码，编译后丢弃 | 编译期检查，如 @Suppress |
| BINARY | 写入 class 文件，但反射读不到 | Kotlin 的默认值，供注解处理器使用 |
| RUNTIME | 写入 class 文件且反射可读 | 运行时框架，如序列化、依赖注入 |

> **注意：**Kotlin 中不写 `@Retention` 时默认是 BINARY，而 Java 的默认是 CLASS，两者行为一致。想让反射读到，必须显式写成 RUNTIME。

---

## 注解参数

注解参数不是任意值都能写，它们必须是编译期就能确定的常量。

允许的类型包括基本类型、String、KClass、枚举、其他注解，以及这些类型的数组。

**实例**

```kotlin
// 枚举类型也可以作为注解参数
enum class Level { LOW, HIGH }

// 再定义一个注解，用于嵌套
annotation class Author(val name: String)

@Target(AnnotationTarget.CLASS)
@Retention(AnnotationRetention.RUNTIME)
annotation class Config(
    val count: Int,                        // 基本类型
    val label: String,                     // String
    val type: Level,                       // 枚举
    val target: kotlin.reflect.KClass<*>,  // 类字面量
    val owner: Author,                     // 嵌套的另一个注解
    val aliases: Array<String> = []        // 数组
)

@Config(
    count = 2,
    label = "runoob",
    type = Level.HIGH,
    target = String::class,
    owner = Author("RUNOOB"),
    aliases = ["www.runoob.com", "RUNOOB"]
)
class Site

fun main() {
    val config = Site::class.java.getAnnotation(Config::class.java)
    println("count=${config.count}, label=${config.label}, type=${config.type}")
    println("target=${config.target.java.simpleName}, owner=${config.owner.name}")
    println("aliases=${config.aliases.toList()}")
}
```

```text
count=2, label=runoob, type=HIGH
target=String, owner=RUNOOB
aliases=[www.runoob.com, RUNOOB]
```

> **限制：**注解参数不能是可空类型，也不能是任意对象；传入的值必须是字面量或 `const val` 常量，不能在运行时计算。

---

## 使用处目标

一个 Kotlin 属性在 JVM 上会同时产生字段、getter 和 setter，注解到底标在哪一个上，需要用使用处目标来指定。

| 目标 | 作用位置 | 示例 |
| --- | --- | --- |
| @file: | 整个文件，必须写在包声明之前 | `@file:JvmName("RunoobUtils")` |
| @field: | 属性背后的 JVM 字段 | `@field:Transient` |
| @property: | Kotlin 属性本身，Java 侧看不到 | `@property:Marker("...")` |
| @get: | 属性的 getter 方法 | `@get:JvmName("getName")` |
| @set: | 属性的 setter 方法 | `@set:JvmName("setName")` |
| @param: | 构造器参数 | `@param:Marker("...")` |
| @setparam: | setter 的参数 | `@setparam:Nullable` |
| @receiver: | 扩展函数或扩展属性的接收者 | `@receiver:Marker("...")` |
| @delegate: | 委托属性保存委托对象的字段 | `@delegate:Transient` |

不写使用处目标时，Kotlin 按 param、property、field 的优先级自动选择。

**实例**

```kotlin
// 自定义注解，允许用在属性、字段、getter、setter、构造参数上
@Target(
    AnnotationTarget.PROPERTY,
    AnnotationTarget.FIELD,
    AnnotationTarget.PROPERTY_GETTER,
    AnnotationTarget.PROPERTY_SETTER,
    AnnotationTarget.VALUE_PARAMETER
)
@Retention(AnnotationRetention.RUNTIME)
annotation class Marker(val desc: String)

class Site(
    @get:Marker("作用于 getter")        // 只标注在生成的 getter 上
    val name: String = "runoob",

    @param:Marker("作用于构造参数")      // 构造器参数的默认位置就是 param
    val age: Int = 12
) {
    @field:Marker("作用于 JVM 字段")
    @Transient                           // 等价于 @field:Transient，字段不参与序列化
    var cache: String = ""

    @property:Marker("作用于属性本身")    // 属性本身，仅 Kotlin 代码中可见
    val host: String = "www.runoob.com"
}

fun main() {
    val site = Site()
    println("${site.name} / ${site.age} / ${site.host}")

    // 用反射验证注解确实落在 getter 上
    val getter = Site::class.java.getDeclaredMethod("getName")
    println("getter 上的注解：${getter.getAnnotation(Marker::class.java).desc}")
}
```

```text
runoob / 12 / www.runoob.com
getter 上的注解：作用于 getter
```

文件级注解必须放在文件最顶部，包声明之前，下面是它的真实写法。

**实例**

```kotlin
// 文件路径：RunoobUtils.kt
// @file:JvmName 修改整个文件编译后生成的类名
@file:JvmName("RunoobUtils")

package com.runoob.demo

// 顶层函数会被放进 RunoobUtils 类，Java 调用时写 RunoobUtils.getHost()
fun getHost(): String = "www.runoob.com"
```

> **注意：**`@property:` 标注的注解在 Java 侧完全不可见，因为 JVM 上根本没有「属性」这个概念；如果 Java 框架需要读取，请改用 `@field:` 或 `@get:`。

---

## 常用内置注解

Kotlin 标准库和 JVM 扩展提供了大量开箱即用的注解，下面按用途分类介绍。

| 注解 | 作用 | 适用范围 |
| --- | --- | --- |
| @Deprecated | 标记过时 API，可指定提示语、替代写法和级别 | 类、函数、属性等 |
| @JvmStatic | 为伴生对象或单例的方法生成真正的静态方法 | object、companion object 的成员 |
| @JvmField | 把属性暴露为字段，不再生成 getter/setter | 有 backing field 的非私有属性 |
| @JvmOverloads | 为带默认参数的函数生成多个重载版本 | 函数、构造器 |
| @JvmName | 修改编译后在 JVM 上看到的名字 | 函数、属性访问器、文件 |
| @Synchronized | 给方法加锁，等价于 JVM 的 synchronized | 函数、属性访问器 |
| @Throws | 向 Java 调用方声明可能抛出的受检异常 | 函数、构造器 |
| @OptIn | 显式选择使用被标记为实验性的 API | 类、函数、表达式 |

**实例**

```kotlin
class SiteUtils {
    companion object {
        @JvmStatic                            // 生成静态方法，Java 可写 SiteUtils.getHost()
        fun getHost(): String = "www.runoob.com"

        @JvmField                             // 暴露为静态字段，不再生成 getter
        val DEFAULT_NAME: String = "RUNOOB"
    }

    // 为带默认参数的函数生成多个重载，方便 Java 调用
    @JvmOverloads
    fun greet(name: String = "runoob", times: Int = 1): String {
        return buildString {
            repeat(times) { append("Hello $name! ") }
        }.trim()
    }

    // 修改 JVM 上看到的方法名
    @JvmName("runoobGreet")
    fun greetRunoob(): String = "Hello RUNOOB"

    // 声明 Java 调用方需要处理的受检异常
    @Throws(java.io.IOException::class)
    fun readConfig(): String {
        if (DEFAULT_NAME.isEmpty()) throw java.io.IOException("配置为空")
        return DEFAULT_NAME
    }
}

// @Deprecated 的第二个参数给出替代写法，第三个参数决定警告级别
@Deprecated("请改用 SiteUtils", ReplaceWith("SiteUtils()"), DeprecationLevel.WARNING)
class OldSiteUtils

fun main() {
    val utils = SiteUtils()
    println(utils.greet())
    println(utils.greet(times = 2))
    println(utils.greetRunoob())
    println(SiteUtils.getHost())
    println(SiteUtils.DEFAULT_NAME)
    println(utils.readConfig())
}
```

```text
Hello runoob!
Hello runoob! Hello runoob!
Hello RUNOOB
www.runoob.com
RUNOOB
RUNOOB
```

`@Synchronized` 和 `@Volatile` 用于并发场景，它们只在 JVM 平台有效。

**实例**

```kotlin
class Counter {
    private var count = 0

    @Synchronized                    // 给方法加锁，保证多线程下计数不丢失
    fun increment(): Int {
        count++
        return count
    }

    @Volatile                        // 保证修改对其他线程立即可见
    var stopped: Boolean = false
}

fun main() {
    val counter = Counter()
    println(counter.increment())
    println(counter.increment())

    counter.stopped = true
    println("stopped=${counter.stopped}")
}
```

```text
1
2
stopped=true
```

`@Repeatable` 让同一个注解可以重复标注，Kotlin 1.6 起会自动生成容器注解。

**实例**

```kotlin
// @Repeatable：同一个注解可以在同一位置出现多次
@Repeatable
@Target(AnnotationTarget.CLASS)
@Retention(AnnotationRetention.RUNTIME)
annotation class Tag(val name: String)

@Tag("collection")
@Tag("annotation")
class Site

fun main() {
    // Kotlin 自动生成容器注解，Java 侧用 getAnnotationsByType 读取全部
    val tags = Site::class.java.getAnnotationsByType(Tag::class.java).map { it.name }
    println(tags)
}
```

```text
[collection, annotation]
```

使用实验性 API 时，需要先用 `@RequiresOptIn` 标记它，调用方再用 `@OptIn` 表态。

**实例**

```kotlin
// 用 @RequiresOptIn 标记一个实验性 API，两个注解从 Kotlin 1.4 起提供
@RequiresOptIn(
    message = "这是实验性 API，未来版本可能变更",
    level = RequiresOptIn.Level.WARNING
)
@Retention(AnnotationRetention.BINARY)
@Target(AnnotationTarget.FUNCTION)
annotation class ExperimentalSiteApi

@ExperimentalSiteApi
fun fetchSite(): String = "www.runoob.com"

// 使用方显式声明"我已知晓风险并同意使用"
@OptIn(ExperimentalSiteApi::class)
fun main() {
    println(fetchSite())
}
```

```text
www.runoob.com
```

> **提示：**不想在每个调用处都写 `@OptIn`，可以在编译参数里加上 `-opt-in=ExperimentalSiteApi`，让整个模块默认选择使用该 API。

---

## 注解处理：KSP 与 kapt

注解本身只是元数据，真正干活的是注解处理器，它在编译期扫描注解并生成代码。

Kotlin 生态里有两套方案，KSP 是官方主推的新方案，kapt 则用于兼容已有的 Java 注解处理器。

| 对比项 | KSP | kapt |
| --- | --- | --- |
| 全称 | Kotlin Symbol Processing | Kotlin Annotation Processing Tool |
| 工作方式 | 直接读取 Kotlin 符号与语法树 | 先生成 Java 桩代码，再交给 Java 处理器 |
| 编译速度 | 快 | 慢，桩生成开销明显 |
| 多平台支持 | 支持 | 不支持，仅限 JVM |
| 典型使用者 | Room、Moshi、Hilt | 依赖 Java 处理器的旧项目 |
| 当前状态 | 官方主推，KSP2 随 Kotlin 2.0 推出 | Kotlin 1.9 起进入维护模式 |

在 Gradle 中启用 KSP 只需要加一个插件，然后把注解处理器的依赖从 kapt 换成 ksp。

**实例**

```kotlin
// 文件路径：build.gradle.kts
plugins {
    kotlin("jvm") version "2.2.0"
    id("com.google.devtools.ksp") version "2.2.0-2.0.2"   // KSP 版本号跟随 Kotlin 版本
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.51")
    ksp("com.google.dagger:hilt-android-compiler:2.51")   // 用 ksp 代替 kapt
}

// 如果注解处理器只支持 Java，才需要退回 kapt：
// plugins { kotlin("kapt") }
// dependencies { kapt("com.example:processor:1.0") }
```

> **注意：**KSP 与 kapt 不能对同一个注解处理器同时启用，迁移时要把 `kapt(...)` 整行替换为 `ksp(...)`，并删除 kapt 插件。

---

## 常见问题

下面汇总注解使用中最容易遇到的几个问题。

| 问题 | 原因 | 解决办法 |
| --- | --- | --- |
| 反射读不到注解 | 保留级别是默认的 BINARY | 加上 `@Retention(AnnotationRetention.RUNTIME)` |
| 注解写不到字段上 | 默认位置落在了 property 而不是 field | 显式写成 `@field:注解名` |
| Java 框架读不到 Kotlin 属性注解 | JVM 上没有属性概念 | 改用 `@get:` 或 `@field:` |
| @JvmField 报错 | 属性是 private、override 或委托属性 | 去掉 private，或改用普通属性 |
| 重复标注同一注解编译失败 | 注解没有加 @Repeatable | 给注解类加上 `@Repeatable` |
| 调用实验性 API 出现警告 | 该 API 被 @RequiresOptIn 标记 | 在调用处加 `@OptIn`，或配置编译参数 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-annotation.html)，版权归原作者所有，仅供非商业学习使用。
