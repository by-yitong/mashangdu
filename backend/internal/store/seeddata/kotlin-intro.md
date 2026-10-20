Kotlin 是一门静态类型语言，代码在编译期就会检查类型，因此很多错误在运行之前就能被发现。

它由 JetBrains 于 2011 年首次公开，2016 年发布 1.0 正式版，名字来自俄罗斯圣彼得堡附近的科特林岛（Kotlin Island）。

Kotlin 最初的目标是给 JVM 提供一门比 Java 更简洁、更安全的语言，如今已经可以编译到多个平台。

同一个 `.kt` 源文件，既可以编译成 JVM 字节码，也可以编译成 JavaScript、Wasm 或本地机器码。

![](images/kotlin/kotlin-intro/1e73ad5f-5f39-495f-a450-48b2f1688429.webp)

> **注意：**Kotlin 与 Java 是互操作关系而不是替代关系。在同一个项目中，两种语言可以同时存在，Kotlin 代码能直接调用 Java 类库，Java 代码也能调用 Kotlin 类。

---

## Kotlin 发展历程

了解版本时间线，能帮你在阅读旧资料时判断哪些写法已经过时。

| 年份 | 版本 / 事件 | 说明 |
| --- | --- | --- |
| 2011 | Kotlin 首次公开 | JetBrains 在 JVM 语言峰会上公布该项目 |
| 2016 | Kotlin 1.0 | 第一个正式稳定版本发布 |
| 2017 | Google I/O 宣布 | Kotlin 成为 Android 官方支持的开发语言 |
| 2019 | Kotlin-first | Google 宣布 Android 开发以 Kotlin 为首选语言 |
| 2020 | Kotlin 1.4 | 引入 SAM 转换、sealed interface、尾逗号 |
| 2021 | Kotlin 1.5 | 值类稳定、JVM records 支持 |
| 2022 | Kotlin 1.7 | K2 编译器进入 Alpha 阶段 |
| 2023 | Kotlin 1.9 | 区间操作符 `..<` 与枚举 `entries` 稳定 |
| 2024 | Kotlin 2.0 | K2 编译器正式发布，编译速度与智能转换显著提升 |
| 2025 | Kotlin 2.2 | when 守卫条件稳定、非局部 break/continue 稳定 |

Kotlin 2.0 是一次重要转折，K2 编译器重写了前端，让编译更快、类型推断更聪明。

本教程所有示例都以 Kotlin 2.2 为准，涉及版本差异的地方会明确标注「X.Y 起」。

---

## 为什么选择 Kotlin

选择一门语言，本质上是在选择它的生态和它帮你避免的问题。

Kotlin 在这几个方面的表现尤其突出。

| 优势 | 具体表现 |
| --- | --- |
| 简洁 | 一行代码可以完成 Java 中需要多行样板代码的工作，例如数据类、属性访问器 |
| 安全 | 类型系统区分可空类型与非空类型，把空指针异常挡在编译期 |
| 互操作 | 与 Java 双向调用，现有 Java 项目可以逐步迁移而不用重写 |
| 多平台 | 同一份业务逻辑可以编译到 JVM、JS、Wasm、iOS、Linux、Windows |
| 工具友好 | IntelliJ IDEA 与 Android Studio 原生支持，官方工具链成熟 |

如果你已经熟悉 Java，学习 Kotlin 的成本主要在函数式写法和空安全规则上，语法本身并不难。

---

## Kotlin 能做什么

Kotlin 的编译器后端决定了它能覆盖哪些平台。

目前官方支持四个后端，每个后端对应一类应用场景。

| 后端 | 目标平台 | 典型用途 |
| --- | --- | --- |
| Kotlin/JVM | Java 虚拟机 | Android 应用、Spring Boot 服务端、桌面工具 |
| Kotlin/JS | 浏览器与 Node.js | 前端页面、全栈 Kotlin 项目 |
| Kotlin/Wasm | WebAssembly | 浏览器中运行的高性能模块 |
| Kotlin/Native | 原生机器码 | iOS、macOS、Linux、Windows 原生程序与嵌入式 |

除此之外，Kotlin 还常用于数据科学（KotlinDL、DataFrame）、脚本编写（`.kts` 文件）以及 Gradle 构建脚本。

Android 开发是目前使用 Kotlin 最广泛的领域，Google 官方的大部分新示例都使用 Kotlin 编写。

---

## 第一个 Kotlin 程序

先看最简单的形式：一个文件、一个入口函数、一行输出。

Kotlin 程序的入口是 `main` 函数，文件名可以任意，但习惯上使用 `hello.kt` 这类小写名称。

**实例**

```kotlin
// 文件路径：hello.kt
// 第一个 Kotlin 程序
fun main() {
    println("Hello, Runoob!")            // 打印一行文本并换行
    println("欢迎来到 www.runoob.com")     // 中文同样可以直接输出
}
```

编译并运行后，终端会输出两行内容。

```text
Hello, Runoob!
欢迎来到 www.runoob.com
```

Kotlin 也支持面向对象的写法，用类来组织数据和行为。

下面的例子定义一个描述网站的类，并调用它的方法。

**实例**

```kotlin
// 文件路径：Site.kt
// 用类描述一个网站，主构造器直接声明属性
class Site(val name: String, val url: String) {

    // 表达式体函数，返回值类型由编译器推断为 String
    fun introduce(): String = "欢迎访问 $name（$url）"
}

fun main() {
    // 创建对象，参数按顺序传入
    val runoob = Site("菜鸟教程", "www.runoob.com")

    println(runoob.introduce())                    // 调用成员函数
    println("站点名称长度：${runoob.name.length}")   // 字符串模板里可以放表达式
}
```

运行结果如下，「菜鸟教程」四个汉字长度为 4。

```text
欢迎访问 菜鸟教程（www.runoob.com）
站点名称长度：4
```

> **提示：**上面的代码可以直接粘贴到 [play.kotlinlang.org](https://play.kotlinlang.org/) 在线运行，不需要在本地安装任何环境。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-intro.html)，版权归原作者所有，仅供非商业学习使用。
