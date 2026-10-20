条件控制让程序根据不同的情况执行不同的代码。

Kotlin 提供 if 和 when 两种条件结构，它们都是表达式，可以直接把结果赋给变量。

本篇介绍 if 的各种写法、when 的分支条件与穷尽性规则，以及 Kotlin 2.2 起稳定的 when 守卫条件。

---

## if 表达式

if 的基本写法与 Java 类似，括号里是条件，条件为真时执行花括号里的代码。

当分支里只有一条语句时，花括号可以省略，但建议保留，可读性更好。

**实例**

```kotlin
fun main() {
    val age = 18

    if (age >= 18) {
        println("已成年")
    }

    // 单条语句可以省略花括号
    if (age >= 18) println("已成年（省略花括号）")

    // 条件不成立时执行 else
    if (age < 18) {
        println("未成年")
    } else {
        println("成年")
    }
}
```

```text
已成年
已成年（省略花括号）
成年
```

Kotlin 的 if 是表达式而不是语句，这一点在下一节会看到明显的区别。

---

## if 作为表达式赋值

因为 if 有返回值，可以直接把它的结果赋给变量，相当于其他语言里的三元运算符。

作为表达式使用时，else 分支是必须的，否则编译器无法确定变量的类型。

**实例**

```kotlin
fun main() {
    val a = 10
    val b = 20

    // 相当于 Java 的 a > b ? a : b
    val max = if (a > b) a else b
    println(max)          // 20

    // 分支块的最后一行就是返回值
    val desc = if (a > b) {
        println("a 更大")
        "a"
    } else {
        println("b 更大")
        "b"
    }
    println(desc)         // b

    // 没有 else 时只能当语句用，不能赋值
    // val bad = if (a > b) a   // 编译错误
}
```

```text
20
b 更大
b
```

> **注意：**Kotlin 没有三元运算符 `? :`，一律用 if 表达式代替。写成多行时反而更清晰，也更适合调试。

---

## if-else if-else 链

多个条件可以用 else if 串起来，程序从上到下依次判断，命中一个就跳出整个链条。

下面的例子把分数转换成等级。

**实例**

```kotlin
fun scoreToGrade(score: Int): String {
    return if (score >= 90) {
        "A"
    } else if (score >= 80) {
        "B"
    } else if (score >= 60) {
        "C"
    } else {
        "D"
    }
}

fun main() {
    println(scoreToGrade(95))   // A
    println(scoreToGrade(85))   // B
    println(scoreToGrade(60))   // C
    println(scoreToGrade(59))   // D
}
```

```text
A
B
C
D
```

条件的顺序很重要：如果把 score >= 60 写在最前面，所有及格分数都会先命中它，后面的判断就永远不会执行。

---

## 使用区间判断

配合 in 运算符，可以用区间让条件更直观，也避免写成一长串 &&。

Kotlin 1.9 起 `..<` 稳定，它表示不包含右端点的开区间，等价于 until。

**实例**

```kotlin
fun main() {
    val score = 85

    if (score in 90..100) {
        println("优秀")
    } else if (score in 80..<90) {      // ..< 不包含右端点 90
        println("良好")
    } else if (score in 60 until 80) {  // until 等价于 ..<
        println("及格")
    } else {
        println("不及格")
    }

    // !in 表示不在区间内
    val c = 'x'
    if (c !in 'a'..'z') {
        println("不是小写字母")
    } else {
        println("是小写字母")
    }
}
```

```text
良好
是小写字母
```

区间判断对字符同样适用，例如判断字符是否属于某个字母范围，比逐个比较码点清楚得多。

---

## when 表达式

when 用来替代多个 else if，它把主语放在括号里，每个分支用箭头指向结果。

when 也是表达式，分支块的最后一行就是返回值，所以可以直接用表达式体函数简写。

**实例**

```kotlin
fun describe(x: Any): String = when (x) {
    1 -> "数字 1"
    "Runoob" -> "菜鸟教程"
    is Long -> "Long 类型"
    !is String -> "不是字符串"
    else -> "其他"
}

fun main() {
    println(describe(1))        // 数字 1
    println(describe("Runoob")) // 菜鸟教程
    println(describe(100L))     // Long 类型
    println(describe(3.14))     // 不是字符串
    println(describe("hello"))  // 其他
}
```

```text
数字 1
菜鸟教程
Long 类型
不是字符串
其他
```

### 分支条件的写法

when 的分支条件非常灵活，下表汇总了常见的写法。

| 写法 | 示例 | 说明 |
| --- | --- | --- |
| 常量 | 1 -> ... | 与主语相等时命中 |
| 逗号多值 | 1, 2, 3 -> ... | 任意一个相等即命中 |
| 属于区间 | in 1..10 -> ... | 属于该区间时命中 |
| 不属于区间 | !in 1..10 -> ... | 不属于该区间时命中 |
| 类型判断 | is String -> ... | 是某类型时命中，并自动智能转换 |
| 类型排除 | !is String -> ... | 不是某类型时命中 |
| 任意布尔表达式 | n % 2 == 0 -> ... | 无参 when 中为 true 时命中 |

**实例**

```kotlin
fun main() {
    // 逗号多值：任意一个相等就命中
    val day = 6
    val type = when (day) {
        1, 2, 3, 4, 5 -> "工作日"
        6, 7 -> "周末"
        else -> "无效的日期"
    }
    println(type)                      // 周末

    // 区间条件
    val score = 85
    val grade = when (score) {
        in 90..100 -> "优秀"
        in 80..<90 -> "良好"
        in 60 until 80 -> "及格"
        else -> "不及格"
    }
    println(grade)                     // 良好

    // is 判断会智能转换，分支内可以直接访问成员
    val value: Any = "www.runoob.com"
    val len = when (value) {
        is String -> value.length      // 这里 value 已被当作 String
        is Int -> value
        else -> 0
    }
    println(len)                       // 14
}
```

```text
周末
良好
14
```

智能转换是 is 分支的额外好处：判断过类型之后，分支内部不需要再手动强转。

---

## when 无参数形式

不写主语时，每个分支条件都是布尔表达式，只要为 true 就命中，等价于一串 else if。

这种写法适合条件之间没有共同主语、或者需要多个不同判断的场合。

**实例**

```kotlin
fun checkNumber(n: Int): String = when {
    n < 0 -> "负数"
    n == 0 -> "零"
    n in 1..9 -> "个位数"
    else -> "多位数"
}

fun main() {
    println(checkNumber(-3))    // 负数
    println(checkNumber(0))     // 零
    println(checkNumber(7))     // 个位数
    println(checkNumber(100))   // 多位数
}
```

```text
负数
零
个位数
多位数
```

无参形式的 when 作为表达式时必须有 else，因为编译器无法判断条件是否覆盖了所有情况。

![条件分支写法选择流程图：需要条件分支时，单个布尔条件用 if 或 if-else，值匹配多个候选用 when (x) { }，多个布尔条件用 when { }；if 和 when 都是表达式可直接赋值，但 when 作表达式时必须穷尽分支，sealed、enum、Boolean 主语可省略 else](images/kotlin/kotlin-condition-control/08-if-when-flow.svg)

---

## when 的穷尽性

穷尽性指是否覆盖了所有可能的情况，这取决于 when 用在表达式位置还是语句位置。

作为表达式使用时，when 必须产生一个值，所以必须穷尽；作为语句使用时，普通类型不要求穷尽。

但对于 enum、密封类和 Boolean 主语，Kotlin 1.6 起会给出警告，`Kotlin 1.7 起直接报错`，要求必须穷尽。

| 主语类型 | 作为表达式 | 作为语句 |
| --- | --- | --- |
| Int、String 等普通类型 | 必须有 else | 可以不穷尽 |
| enum | 覆盖全部枚举值即可，不必写 else | 必须穷尽（Kotlin 1.7 起） |
| sealed class / sealed interface | 覆盖全部子类型即可 | 必须穷尽（Kotlin 1.7 起） |
| Boolean | true 与 false 都覆盖即可 | 必须穷尽（Kotlin 1.7 起） |
| 无主语 when | 必须有 else | 不要求 else |

**实例**

```kotlin
enum class Status { LOADING, SUCCESS, ERROR }

// 枚举主语：覆盖所有枚举值，不需要 else
fun message(status: Status): String = when (status) {
    Status.LOADING -> "加载中"
    Status.SUCCESS -> "成功"
    Status.ERROR -> "失败"
}

// Boolean 主语：true 和 false 都覆盖，不需要 else
fun label(flag: Boolean): String = when (flag) {
    true -> "开"
    false -> "关"
}

fun main() {
    println(message(Status.SUCCESS))   // 成功
    println(label(true))               // 开
}
```

```text
成功
开
```

密封类与 when 配合最为常见，编译器能验证是否覆盖了所有子类型，新增子类时遗漏分支会立即报错。

**实例**

```kotlin
sealed class Result
data class Success(val data: String) : Result()
data class Failure(val reason: String) : Result()

fun render(result: Result): String = when (result) {
    is Success -> "成功：${result.data}"
    is Failure -> "失败：${result.reason}"
}

fun main() {
    println(render(Success("RUNOOB")))     // 成功：RUNOOB
    println(render(Failure("网络超时")))    // 失败：网络超时
}
```

```text
成功：RUNOOB
失败：网络超时
```

> **注意：**else 分支必须放在最后。如果 else 后面还有其他分支，编译器会直接报错。

---

## when 守卫条件

守卫条件（guard condition）让你在分支的主条件之后再追加一个布尔判断，只有两者都成立才进入该分支。

写法是在主条件后面直接跟 `if 表达式`，中间不写箭头。

守卫条件在 Kotlin 2.0 中实现并以预览形式提供（KT-67787，需要命令行参数开启），`Kotlin 2.2 起稳定`（KT-13626）。

**实例**

```kotlin
sealed interface Response
data class Ok(val body: String) : Response
data class Error(val reason: String) : Response

fun handle(response: Response): String = when (response) {
    // 主条件成立后，再判断守卫条件
    is Ok if response.body.isNotEmpty() -> "成功：${response.body}"
    is Ok -> "成功但内容为空"
    is Error if response.reason.isNotBlank() -> "失败：${response.reason}"
    is Error -> "失败：原因未知"
}

fun main() {
    println(handle(Ok("RUNOOB")))    // 成功：RUNOOB
    println(handle(Ok("")))          // 成功但内容为空
    println(handle(Error("超时")))    // 失败：超时
    println(handle(Error("   ")))    // 失败：原因未知
}
```

```text
成功：RUNOOB
成功但内容为空
失败：超时
失败：原因未知
```

守卫条件的使用有几条限制，需要特别注意。

第一，守卫条件只能用在带主语的 when 中，无参形式不支持。

第二，逗号分隔的多个条件不能配合守卫，例如 `0, 1 ->` 后面不能再加 if。

第三，一个分支需要多个守卫时，用 `&&` 或 `||` 组合，并建议加上括号。

**实例**

```kotlin
sealed interface Animal {
    data class Cat(val mouseHunter: Boolean, val hungry: Boolean) : Animal
    data class Dog(val breed: String) : Animal
}

fun feed(animal: Animal): String = when (animal) {
    is Animal.Dog -> "喂狗"
    // 多个守卫条件用 && 组合
    is Animal.Cat if (!animal.mouseHunter && animal.hungry) -> "喂猫"
    is Animal.Cat -> "不喂猫"
}

fun main() {
    println(feed(Animal.Dog("Beagle")))                            // 喂狗
    println(feed(Animal.Cat(mouseHunter = false, hungry = true)))  // 喂猫
    println(feed(Animal.Cat(mouseHunter = true, hungry = true)))   // 不喂猫
}
```

```text
喂狗
喂猫
不喂猫
```

主条件成立但守卫条件不成立时，程序不会跳出 when，而是继续匹配后面的分支。

正因如此，`is Ok if ...` 后面通常还要再写一个不带守卫的 `is Ok` 兜底，否则该类型可能没有分支可以命中。

> **提示：**守卫条件也支持 `else if` 写法，例如 `else if animal.eatsPlants -> ...`，可以用来处理多个兜底分支。守卫条件要求 when 必须有主语，无参 when 请改用 `&&` 把条件合并到分支里。

---

## 常见问题

下面是条件控制中最常见的几个问题。

### if 的 else 什么时候必须写

当 if 用作表达式，也就是把结果赋给变量或作为返回值时，else 是必须的。

当 if 只用作语句、不关心返回值时，else 可以省略。

### when 和 if 该怎么选

判断同一个主语的多个取值时，用 when 比一长串 else if 更清晰。

条件之间没有共同主语时，用 if-else 链或无参 when 都可以，按可读性选择。

### 为什么枚举的 when 不写 else 也能通过编译

因为编译器能验证所有枚举值都已被覆盖，这个 when 已经是穷尽的。

如果以后给枚举新增了值而忘了加分支，Kotlin 1.7 起会直接报错，这正是穷尽性检查的价值。

### 守卫条件和在分支里写 if 有什么区别

守卫条件不成立时会继续匹配后面的分支。

而进入分支后再写 if，只是让分支内部少执行一段代码，不会再去尝试其他分支，两者的控制流完全不同。

### when 的 else 可以放在中间吗

不可以，else 必须作为最后一个分支。

如果确实需要多个兜底条件，用无参 when 配合 &&、||，或者在守卫条件中使用 else if 写法。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-condition-control.html)，版权归原作者所有，仅供非商业学习使用。
