函数是组织代码的基本单位，把一段逻辑封装起来并起个名字，之后可以反复调用。

Kotlin 的函数比 Java 灵活得多：有参数默认值、命名参数、可变参数、局部函数、尾递归和中缀调用，还能用表达式体让写法更短。

本页从最基本的函数定义讲起，重点说明返回类型什么时候可以省略、什么时候必须写。

---

## 函数定义与返回值

Kotlin 用 `fun` 关键字定义函数，参数写在圆括号里，格式是 `参数名: 类型`。

函数体有两种形式：块体（block body）用花括号包起来，表达式体（expression body）用等号直接给出结果。

**实例**

```kotlin
// 文件路径：FunctionBasic.kt

// 块体：有花括号和 return，返回类型必须显式写出
fun add(a: Int, b: Int): Int {
    return a + b
}

// 表达式体：用 = 直接给出结果，返回类型可以推断为 Int
fun sub(a: Int, b: Int) = a - b

// 块体但没有返回值：默认返回 Unit，可以省略 : Unit
fun printSum(a: Int, b: Int) {
    println("$a + $b = ${a + b}")
}

fun main() {
    println(add(1, 2))       // 调用块体函数
    println(sub(5, 3))       // 调用表达式体函数
    printSum(2, 3)
}
```

运行结果如下。

```text
3
2
2 + 3 = 5
```

关于返回类型，网上常见一种说法是"public 函数必须写返回类型"，这是不准确的。

准确的规则是：`表达式体的返回类型总能被推断，与可见性无关`；只有`块体且返回类型不是 Unit` 时才必须显式声明。

| 写法 | 必须写返回类型吗 | 说明 |
| --- | --- | --- |
| `fun f() = a + b` | 不必须 | 表达式体，public、internal、private 都能推断 |
| `fun f(): Int { return a + b }` | 必须 | 块体且返回非 Unit，编译器不做跨语句推断 |
| `fun f() { println(a) }` | 不必须 | 块体返回 Unit，: Unit 可以省略 |

> **提示：**虽然表达式体可以省略返回类型，但如果函数是库的公开 API，显式写出返回类型更利于阅读，也能避免修改实现时不小心改变对外类型。

---

## 单表达式函数

函数体只有一个表达式时，可以省略花括号和 return，写成单表达式函数。

这是 Kotlin 中非常常见的写法，配合 `when` 表达式尤其简洁。

**实例**

```kotlin
// 显式写出返回类型，可读性更好
fun double(x: Int): Int = x * 2

// 返回类型也可以省略，由编译器推断为 Int
fun square(x: Int) = x * x

// 配合 when 表达式，替代一长串 if-else
fun describe(value: Int) = when {
    value < 0 -> "负数"
    value == 0 -> "零"
    else -> "正数"
}

fun main() {
    println(double(4))
    println(square(4))
    println(describe(-1))
    println(describe(0))
    println(describe(7))
}
```

```text
8
16
负数
零
正数
```

单表达式函数和块体函数在语义上完全等价，选择哪种写法主要看函数体的长度：超过一行的逻辑通常用块体更清晰。

---

## 参数默认值

Kotlin 允许给参数指定默认值，调用时可以不传这个参数。

它替代了 Java 中大量重载方法的作用，让同一个函数能应对多种调用方式。

**实例**

```kotlin
// 两个参数都有默认值
fun greet(name: String = "Runoob", site: String = "www.runoob.com"): String {
    return "欢迎 $name 访问 $site"
}

fun main() {
    println(greet())                            // 两个参数都用默认值
    println(greet("RUNOOB"))                    // 只覆盖第一个参数
    println(greet(site = "kotlin.runoob.com"))  // 只覆盖第二个参数，用命名参数
}
```

```text
欢迎 Runoob 访问 www.runoob.com
欢迎 RUNOOB 访问 www.runoob.com
欢迎 Runoob 访问 kotlin.runoob.com
```

默认参数可以出现在无默认值参数的前面，但调用时就只能用命名参数跳过它。

**实例**

```kotlin
// value 有默认值，却写在 unit 前面
fun format(value: Int = 0, unit: String): String = "$value$unit"

fun main() {
    // 不能写 format("px")，那样会把字符串传给 value 导致类型不匹配
    println(format(unit = "px"))
    println(format(12, "px"))
}
```

```text
0px
12px
```

> **注意：**重写父类方法时不能再指定默认值，重写后的方法始终使用父类声明的默认值。另外，默认参数对 Java 调用方不可见，需要配合 `@JvmOverloads` 才会生成重载方法，这部分在《Kotlin Java 互操作》一篇介绍。

---

## 命名参数

调用函数时用 `参数名 = 值` 的形式传参，就是命名参数。

命名参数让调用顺序可以打乱，也能只给关心的参数赋值，代码可读性明显提升。

**实例**

```kotlin
fun createSite(name: String, url: String, port: Int = 80): String {
    return "$name -> $url:$port"
}

fun main() {
    // 顺序打乱也能正确匹配
    println(createSite(url = "www.runoob.com", name = "Runoob"))

    // 位置参数和命名参数混用：位置参数必须写在命名参数前面
    println(createSite("RUNOOB", url = "www.runoob.com", port = 443))
}
```

```text
Runoob -> www.runoob.com:80
RUNOOB -> www.runoob.com:443
```

命名参数最大的价值是消除"参数一多就不知道哪个是哪个"的问题，尤其是连续多个同类型参数的函数。

需要注意的是，Java 方法编译后不保留参数名，因此调用 Java 方法时无法使用命名参数。

---

## 可变参数 vararg 与展开运算符

`vararg` 表示这个参数可以接收任意多个值，在函数内部它被当作数组使用。

一个函数只能有一个 vararg 参数，它通常是最后一个参数。

**实例**

```kotlin
// vararg numbers 在函数内部是 IntArray 类型
fun total(vararg numbers: Int): Int {
    var sum = 0
    for (number in numbers) {
        sum += number
    }
    return sum
}

fun main() {
    println(total(1, 2, 3))       // 传三个值
    println(total())              // 一个都不传，数组为空
    println(total(10, 20, 30, 40))

    // 已经有数组时，用展开运算符 * 把数组拆成独立参数
    val values = intArrayOf(100, 200)
    println(total(*values))
}
```

```text
6
0
100
300
```

展开运算符 `*` 只能用于数组（包括 `IntArray` 这类基本类型数组），不能直接用于 List。

**实例**

```kotlin
fun total(vararg numbers: Int): Int = numbers.sum()

fun main() {
    val list = listOf(1, 2, 3)

    // 错误写法：total(*list) 编译不通过
    // 正确做法是先转成数组再展开
    println(total(*list.toIntArray()))
}
```

```text
6
```

如果 vararg 不是最后一个参数，它后面的参数必须用命名参数传递，否则编译器无法判断哪些值属于 vararg。

---

## Unit 返回类型

没有返回值的函数，返回类型是 `Unit`，可以把它理解成"只有一个实例的类型"。

Kotlin 里 `Unit` 是一个真实存在的类型，而不是像 Java 的 void 那样的关键字。

**实例**

```kotlin
// 显式写出 : Unit，与省略时完全等价
fun sayHello(): Unit {
    println("Hello, Runoob!")
}

// 下面两个函数返回类型都是 Unit
fun log1() {
    println("RUNOOB")
}

fun log2(): Unit = println("RUNOOB")

fun main() {
    sayHello()
    log1()

    // Unit 是类型，所以可以用变量接收它
    val result: Unit = log2()
    println(result)
}
```

```text
Hello, Runoob!
RUNOOB
RUNOOB
kotlin.Unit
```

正因为 Unit 是类型，返回 Unit 的函数才能作为 `() -> Unit` 类型的值传递，这是 Lambda 与高阶函数的基础。

---

## 局部函数

函数内部还可以再定义函数，这种函数叫局部函数（local function）。

局部函数只在定义它的函数体内可见，并且可以访问外层的参数和局部变量。

**实例**

```kotlin
// 顶层函数：直接写在文件里
fun factorial(n: Int): Long {
    // 局部函数：定义在 factorial 内部，可以访问外层的 n
    fun multiply(current: Int, acc: Long): Long {
        return if (current == 1) acc else multiply(current - 1, acc * current)
    }

    // 局部函数也可以写成表达式体，返回类型同样能推断
    fun describe() = "计算 $n 的阶乘"

    println(describe())
    return multiply(n, 1L)
}

fun main() {
    println(factorial(5))
}
```

```text
计算 5 的阶乘
120
```

局部函数常用于把一段只在当前函数里用到的逻辑拆出来，避免污染文件级命名空间，也让代码层次更清楚。

---

## 尾递归 tailrec

如果函数的最后一步操作是调用自己，编译器可以用循环替代递归，从而避免栈溢出，这就是尾递归优化。

用 `tailrec` 修饰函数即可让编译器尝试这种优化。

**实例**

```kotlin
// 递归调用是最后一步操作，可以享受 tailrec 优化
tailrec fun gcd(a: Int, b: Int): Int {
    return if (b == 0) a else gcd(b, a % b)
}

// 普通递归：最后一步是乘法而不是自身调用，不能用 tailrec
fun factorial(n: Int): Long {
    return if (n <= 1) 1L else n * factorial(n - 1)
}

fun main() {
    println(gcd(48, 18))
    println(factorial(5))
}
```

```text
6
120
```

tailrec 的成立条件是：递归调用必须是函数体最后执行的操作，且不能包在 try/catch/finally 里。

> **注意：**如果加了 tailrec 却找不到符合条件的尾调用，编译器会给出警告，提示这个函数实际上没有享受到优化。这时应该检查递归调用是不是被其他运算包住了。

---

## 顶层函数与成员函数

直接写在文件里的函数叫顶层函数，定义在类或对象内部的函数叫成员函数。

两者最大的区别是成员函数需要通过实例调用，而顶层函数直接调用即可。

**实例**

```kotlin
// 顶层函数：不属于任何类
fun topLevel(): String = "我是顶层函数"

class Site(val name: String) {
    // 成员函数：需要通过实例访问
    fun describe(): String = "站点：$name"

    // 成员函数内部可以直接调用顶层函数
    fun info() = "${describe()} / ${topLevel()}"
}

fun main() {
    println(topLevel())

    val runoob = Site("Runoob")
    println(runoob.describe())
    println(runoob.info())
}
```

```text
我是顶层函数
站点：Runoob
站点：Runoob / 我是顶层函数
```

在 JVM 上，同一个文件里的顶层函数会被编译进一个名为 `文件名Kt` 的类，例如 `FunctionBasic.kt` 里的顶层函数会进入 `FunctionBasicKt`。

---

## 函数重载

同名函数只要参数列表不同，就可以共存，这叫函数重载（overloading）。

编译器根据实参的类型和个数决定调用哪一个。

**实例**

```kotlin
// 参数类型不同
fun format(value: Int) = "整数：$value"
fun format(value: Double) = "小数：$value"

// 参数个数不同
fun format(value: String, upper: Boolean) = if (upper) value.uppercase() else value

fun main() {
    println(format(42))
    println(format(3.14))
    println(format("runoob", true))
    println(format("runoob", false))
}
```

```text
整数：42
小数：3.14
RUNOOB
runoob
```

重载只看参数列表，返回类型不参与区分。下面这种写法是非法的，编译器会报 `Conflicting overloads`。

**实例**

```kotlin
// 错误示例：只有返回类型不同，编译不通过
// fun value(): Int = 1
// fun value(): String = "1"
```

> **提示：**不要设计"只靠默认参数区分"的重载，比如 `show(value: Int)` 和 `show(value: Int, prefix: String = "")`。这种重载容易让调用方和阅读者都搞不清最终调用了哪个版本。

---

## 中缀函数 infix

用 `infix` 修饰的函数可以用 `a 函数名 b` 的形式调用，省略点和括号。

标准库里的 `to`、`and`、`shl` 都是中缀函数。

**实例**

```kotlin
class Site(val name: String) {
    // 成员中缀函数：只能有一个参数
    infix fun hostedAt(domain: String): String = "$name 托管在 $domain"
}

// 扩展中缀函数：给已有类型添加中缀调用能力
infix fun Int.biggerThan(other: Int): Boolean = this > other

fun main() {
    val runoob = Site("Runoob")

    // 下面两种写法完全等价
    println(runoob.hostedAt("www.runoob.com"))
    println(runoob hostedAt "www.runoob.com")

    // 等价于 10.biggerThan(3)
    println(10 biggerThan 3)
}
```

```text
Runoob 托管在 www.runoob.com
Runoob 托管在 www.runoob.com
true
```

| 限制 | 说明 |
| --- | --- |
| 必须是成员函数或扩展函数 | 顶层函数不能声明为 infix |
| 只能有一个参数 | 两个及以上参数无法用中缀形式表达 |
| 参数不能是 vararg | 可变参数个数不确定，无法确定中缀的右操作数 |
| 参数不能有默认值 | 中缀调用必须显式写出右操作数 |

中缀调用的优先级低于算术运算符，高于 `&&` 和 `||`，混用时建议加括号，避免误读。

---

## 常见问题

下面整理几个关于函数的常见疑问。

| 问题 | 说明 |
| --- | --- |
| 什么时候必须写返回类型 | 块体且返回类型不是 Unit 时必须写；表达式体任何可见性都能推断 |
| 参数默认值和重载怎么选 | 优先用默认参数，代码更少；需要完全不同的实现逻辑时才用重载 |
| 命名参数能用在 Java 方法上吗 | 不能，Java 字节码默认不保留参数名 |
| vararg 可以传 List 吗 | 不可以，需要用 `*list.toIntArray()` 这类方式先转成数组 |
| tailrec 加了没效果 | 递归调用必须处于最后一步，且不能在 try/catch/finally 中 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-function.html)，版权归原作者所有，仅供非商业学习使用。
