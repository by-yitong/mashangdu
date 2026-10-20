能跑通的代码只是及格线，团队协作还要求代码风格一致、写法地道。

本章节整理 Kotlin 官方推荐的命名约定、格式化规则，以及初学者最容易写错的常见惯用法。

---

## 为什么需要统一风格

代码的阅读次数远远多于编写次数，风格统一能显著降低阅读成本。

命名一致让调用者不用猜函数是做什么的，格式一致让代码评审聚焦在逻辑而不是空格上。

Kotlin 官方发布了代码风格约定，IntelliJ IDEA 内置的格式化器默认就遵循这套约定。

社区还提供了 ktlint 和 detekt 两个工具，可以把风格检查接入构建流程，在提交前自动发现问题。

| 工具 | 定位 | 典型用法 |
| --- | --- | --- |
| IDEA 格式化器 | 编辑器内置，快捷键即可格式化 | Ctrl+Alt+L 或 Cmd+Option+L |
| ktlint | 轻量风格检查与自动修复 | ./gradlew ktlintFormat |
| detekt | 静态代码分析，覆盖复杂度与坏味道 | ./gradlew detekt |

---

## 命名约定

命名是代码里出现频率最高的元素，统一的命名规则比任何注释都有效。

Kotlin 的命名约定与 Java 基本一致，只有常量和测试方法等少数几处有 Kotlin 特色。

| 元素 | 约定 | 示例 |
| --- | --- | --- |
| 包名 | 全小写，不用下划线，多个单词直接相连 | com.runoob.demo |
| 类与接口 | 大驼峰 UpperCamelCase | SiteInfo、DataRepository |
| 函数与方法 | 小驼峰 lowerCamelCase | getSiteName()、findById() |
| 常量 | 全大写下划线分隔，配合 const val 或 val | const val MAX_COUNT = 100 |
| 属性与局部变量 | 小驼峰，避免无意义的单字母 | siteName、pageSize |
| 类型参数 | 单个大写字母，或大驼峰加 T 后缀 | T、TResult |
| 枚举值 | 全大写下划线分隔 | RED、DARK_BLUE |
| 文件与目录 | 与文件中的顶层类名保持一致 | SiteInfo.kt |
| 测试方法 | JVM 上可用反引号包裹自然语言描述 | fun `add returns sum`() |

包名不要使用下划线，这一点和部分其他语言的习惯不同，com.runoob_demo 是错误写法。

布尔类型的属性建议用 is、has、can 开头，让语义一目了然。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/Site.kt
package com.runoob

// 类名大驼峰
data class Site(val name: String, val url: String) {
    // 布尔属性用 is 开头，读起来像一句话
    val isSecure: Boolean
        get() = url.startsWith("https://")
}

// 顶层常量全大写
const val MAX_SITE_COUNT = 100

// 顶层函数小驼峰
fun describeSite(site: Site): String = "${site.name} -> ${site.url}"

fun main() {
    val site = Site("Runoob", "https://www.runoob.com")
    println(describeSite(site))
    println("是否安全连接：${site.isSecure}")
    println("最大站点数：$MAX_SITE_COUNT")
}
```

输出结果如下。

```text
Runoob -> https://www.runoob.com
是否安全连接：true
最大站点数：100
```

> **提示：**反引号命名只适用于 JVM 目标，Kotlin/JS 与 Kotlin/Native 上不支持带空格或特殊字符的标识符，跨平台项目请改用普通命名。

---

## 格式化与缩进

格式化的目标不是美观，而是让 diff 尽量小、让评审不被打扰。

官方约定里最需要记住的是四条：缩进 4 空格、行宽 120、左花括号不换行、冒号前不留空格。

| 规则 | 约定 | 说明 |
| --- | --- | --- |
| 缩进 | 4 个空格 | 禁止使用 Tab，避免不同编辑器宽度不一致 |
| 最大行宽 | 120 个字符 | 超出时在运算符或逗号后换行 |
| 左花括号 | 跟在声明行末尾 | 不单独占一行 |
| 类型声明冒号 | 冒号前无空格，冒号后一个空格 | val name: String |
| 继承冒号 | 冒号前一个空格，冒号后一个空格 | class Dog : Animal() |
| 逗号 | 后面一个空格 | fun add(a: Int, b: Int) |
| 尾逗号 | 多行参数列表建议加上 | Kotlin 1.4 起支持，便于后续增删参数 |
| import | 按字母序排列，不使用通配符 | 避免命名冲突，也便于看清依赖 |
| 空行 | 用空行分隔逻辑块 | 不要连续出现三行以上空行 |

尾逗号是 Kotlin 1.4 引入的特性，在多行参数或元素列表的最后一个元素后加逗号不会报错。

**实例**

```kotlin
// 文件路径：src/main/kotlin/com/runoob/Config.kt
package com.runoob

// 多行参数列表使用尾逗号，之后增删参数时 diff 只影响一行
fun createSiteMap(
    name: String,
    url: String,
    port: Int,
): Map<String, Any> {
    return mapOf(
        "name" to name,
        "url" to url,
        "port" to port,
    )
}

fun main() {
    println(createSiteMap("Runoob", "www.runoob.com", 443))
}
```

输出结果如下。

```text
{name=Runoob, url=www.runoob.com, port=443}
```

IDEA 的格式化快捷键是 Ctrl+Alt+L，macOS 上是 Cmd+Option+L，养成提交前格式化一次的习惯。

---

## 惯用法

Kotlin 提供了很多简化样板代码的语法，用对了代码量能减少一半以上。

下面六条是日常开发中出现频率最高的惯用法。

### 优先使用 val

只有在确实需要重新赋值时才用 var，其余一律用 val。

不可变引用能排除「值在别处被改掉」这类难以排查的 bug，也让编译器可以做更多优化。

**实例**

```kotlin
fun main() {
    // 推荐：值确定后不再变化，用 val
    val siteName = "Runoob"
    val url = "www.runoob.com"

    // 需要累加时才用 var
    var visitCount = 0
    visitCount += 1

    println("$siteName -> $url，访问次数 $visitCount")
}
```

输出结果如下。

```text
Runoob -> www.runoob.com，访问次数 1
```

> **注意：**val 只保证引用本身不可变，不保证对象内容不可变。val list = mutableListOf(1) 之后仍然可以 list.add(2)。

### 用数据类代替手写模板代码

需要承载数据的类，一律用 data class，编译器会自动生成 equals、hashCode、toString、copy 和解构方法。

手写这些方法不仅冗长，还容易在新增字段时忘记同步修改。

**实例**

```kotlin
// 一行声明换来五个自动生成的方法
data class Site(val name: String, val url: String)

fun main() {
    val site = Site("Runoob", "www.runoob.com")
    // toString 自动生成
    println(site)
    // copy 复制对象并修改指定字段
    val mobile = site.copy(url = "m.runoob.com")
    println(mobile)
    // equals 按内容比较
    println(site == Site("Runoob", "www.runoob.com"))
}
```

输出结果如下。

```text
Site(name=Runoob, url=www.runoob.com)
Site(name=Runoob, url=m.runoob.com)
true
```

### 用扩展函数代替工具类

Java 里习惯写 StringUtils、DateUtils 这类工具类，Kotlin 中更自然的做法是扩展函数。

扩展函数把调用点变成「对象.方法()」的形式，链式调用时尤其顺手。

**实例**

```kotlin
// 推荐：给 String 加一个扩展函数，而不是新建工具类
fun String.toDomain(): String =
    substringAfter("://").substringBefore("/")

fun main() {
    val url = "https://www.runoob.com/kotlin"
    println(url.toDomain())
}
```

输出结果如下。

```text
www.runoob.com
```

扩展函数是静态解析的，不要把它当作多态手段，需要多态时仍然要用继承或接口。

### 用作用域函数简化对象操作

apply 返回对象本身，适合集中初始化；let 返回 lambda 结果，适合做转换；also 适合插入日志等副作用。

选择哪一个取决于你要的是对象本身还是 lambda 的结果。

**实例**

```kotlin
data class Site(var name: String, var url: String)

fun main() {
    // apply 的返回值就是配置好的对象，省去临时变量
    val site = Site("", "").apply {
        name = "Runoob"
        url = "www.runoob.com"
    }

    // also 返回对象本身，常用于打日志
    val upper = site.also { println("配置完成：$it") }
        .url.uppercase()

    println(upper)
}
```

输出结果如下。

```text
配置完成：Site(name=Runoob, url=www.runoob.com)
WWW.RUNOOB.COM
```

### 用 when 代替长 if-else 链

分支超过两个时，when 表达式的可读性明显优于 if-else 链。

配合 sealed 类或枚举，when 还能做到穷尽检查，漏掉分支编译器会直接报错。

**实例**

```kotlin
sealed interface Result

data class Success(val data: String) : Result
data class Failure(val message: String) : Result

// 作为表达式使用时，sealed 的所有子类型都覆盖了，不需要 else 分支
fun describe(result: Result): String = when (result) {
    is Success -> "成功：${result.data}"
    is Failure -> "失败：${result.message}"
}

fun main() {
    println(describe(Success("RUNOOB")))
    println(describe(Failure("网络超时")))
}
```

输出结果如下。

```text
成功：RUNOOB
失败：网络超时
```

### 用空安全代替非空断言

!! 会在值为 null 时直接抛出空指针异常，把问题推迟到运行时。

优先使用安全调用 ?. 与 Elvis 运算符 ?:，把为空的情况显式处理掉。

**实例**

```kotlin
fun main() {
    val name: String? = null

    // 安全调用加 Elvis，为空时给出默认值
    println(name?.length ?: 0)
    println(name?.uppercase() ?: "未知")

    val site: String? = "www.runoob.com"
    // 非空时才执行后续操作
    site?.let { println("站点长度：${it.length}") }
}
```

输出结果如下。

```text
0
未知
站点长度：14
```

只有在逻辑上已经确保不为空、且为空就说明程序有严重缺陷时，才使用 !! 让问题尽早暴露。

---

## 反模式对照表

下面这些写法在初学阶段很常见，对照修改即可让代码质量提升一个档次。

| 不推荐写法 | 推荐写法 | 原因 |
| --- | --- | --- |
| var count = 0（之后不再修改） | val count = 0 | 不可变引用更安全 |
| if (x != null) { x.foo() } | x?.foo() | 空安全调用更简洁 |
| x!!.foo() | x?.foo() ?: return | 避免运行时空指针异常 |
| 手写 equals、hashCode、toString | data class | 编译器自动生成，不会漏字段 |
| object StringUtils 里的静态方法 | 扩展函数或顶层函数 | 调用处更自然 |
| for (i in 0 until list.size) | for (item in list) | 避免索引越界 |
| 多层嵌套 if-else | when 表达式 | 分支结构更清晰 |
| 返回 null 表示失败 | sealed 类或 Result | 失败原因可携带，语义明确 |
| StringBuilder 拼接字符串 | 字符串模板 "$name" | 可读性更好 |
| 写 getter 方法 getSiteName() | 属性语法 siteName | Kotlin 会自动生成访问器 |

这些规则并非绝对，例如在性能敏感的循环里，显式索引有时比迭代器更快。

但默认选择推荐写法，只在有明确理由时才偏离。

---

## 常见问题

下面几个问题在落地编码规范时最常被问到。

### 团队规范与官方规范冲突怎么办

以团队约定为准，但要写进配置文件，让工具自动检查，而不是靠口头提醒。

ktlint 的 .editorconfig 和 detekt 的 detekt.yml 都可以定制规则。

### 扩展函数会不会污染全局命名空间

扩展函数需要导入才能使用，不会自动可见。

把它们放在专门的包或文件里，通过 import 控制作用域即可。

### 尾逗号会不会影响兼容性

尾逗号是 Kotlin 1.4 起支持的语言特性，使用低于 1.4 的编译器会报错。

新项目无需担心，老项目升级编译器后再启用。

### 反引号命名在测试之外能用吗

语法上可以，但只建议在测试方法上使用，业务代码仍应遵循标准命名。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-style.html)，版权归原作者所有，仅供非商业学习使用。
