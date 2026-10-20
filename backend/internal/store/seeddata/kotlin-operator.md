运算符重载让自定义类型也能使用 `+`、`-`、`[]` 这些符号，写出来的代码更接近数学表达式。

Kotlin 通过给函数加上 `operator` 关键字来实现重载，本质上是把运算符翻译成一次普通的函数调用。

---

## operator 关键字

重载运算符的写法，是定义一个名字固定的函数，并在前面加 `operator`。

这个函数可以是类的成员函数，也可以是扩展函数，但必须用 `operator` 修饰，否则编译报错。

**实例**

```kotlin
class Point(val x: Int, val y: Int) {
    // 函数名必须叫 plus，并且用 operator 修饰
    operator fun plus(other: Point): Point = Point(x + other.x, y + other.y)

    override fun toString(): String = "($x, $y)"
}

fun main() {
    val a = Point(1, 2)
    val b = Point(3, 4)

    // a + b 会被编译器翻译成 a.plus(b)
    println(a + b)
    println(a.plus(b))
}
```

运行结果：

```text
(4, 6)
(4, 6)
```

> **注意：**运算符重载只是语法糖。编译器把 `a + b` 直接翻译为 `a.plus(b)`，因此重载的只是写法，不是运算符本身的优先级。

---

## 可重载运算符全表

每个运算符都对应一个固定的函数名，函数名写错或参数个数不对都无法重载成功。

| 表达式 | 翻译为 | 说明 |
| --- | --- | --- |
| +a | a.unaryPlus() | 一元正号 |
| -a | a.unaryMinus() | 一元负号 |
| !a | a.not() | 逻辑取反 |
| a++ | a = a.inc() | 自增，要求 a 是 var |
| a-- | a = a.dec() | 自减，要求 a 是 var |
| a + b | a.plus(b) | 加法 |
| a - b | a.minus(b) | 减法 |
| a * b | a.times(b) | 乘法 |
| a / b | a.div(b) | 除法 |
| a % b | a.rem(b) | 取余 |
| a..b | a.rangeTo(b) | 闭区间 |
| a..<b | a.rangeUntil(b) | 左闭右开区间，Kotlin 1.9 起 |
| a in b | b.contains(a) | 包含判断 |
| a[i] | a.get(i) | 索引读取 |
| a[i] = b | a.set(i, b) | 索引赋值 |
| a() | a.invoke() | 像函数一样调用对象 |
| a == b | a?.equals(b) ?: (b === null) | 结构相等 |
| a != b | !(a?.equals(b) ?: (b === null)) | 结构不等 |
| a > b | a.compareTo(b) > 0 | 比较大小 |
| a < b | a.compareTo(b) < 0 | 比较大小 |
| a >= b | a.compareTo(b) >= 0 | 比较大小 |
| a <= b | a.compareTo(b) <= 0 | 比较大小 |
| a += b | a = a.plus(b) 或 a.plusAssign(b) | 复合赋值，二者只能选一 |
| a -= b | a = a.minus(b) 或 a.minusAssign(b) | 复合赋值 |
| a *= b | a = a.times(b) 或 a.timesAssign(b) | 复合赋值 |
| a /= b | a = a.div(b) 或 a.divAssign(b) | 复合赋值 |
| a %= b | a = a.rem(b) 或 a.remAssign(b) | 复合赋值 |

以下运算符不能重载：`&&`、`||`、`===`、`!==`、`is`、`!is`、`?:`、`=`。

---

## 一元运算符与自增自减

一元运算符对应 `unaryPlus`、`unaryMinus` 和 `not` 三个函数，都不接收参数。

自增自减对应 `inc` 和 `dec`，它们返回一个新值，编译器会再把它赋回原变量，所以变量必须是 var。

**实例**

```kotlin
data class Counter(val value: Int) {
    // -counter
    operator fun unaryMinus() = Counter(-value)

    // counter++
    operator fun inc() = Counter(value + 1)

    // counter--
    operator fun dec() = Counter(value - 1)
}

fun main() {
    val c = Counter(10)
    println(-c)

    // ++ 与 -- 会重新赋值给变量，因此变量必须声明为 var
    var n = Counter(0)
    n++
    println(n)
    n--
    println(n)
}
```

运行结果：

```text
Counter(value=-10)
Counter(value=1)
Counter(value=0)
```

> **注意：**Kotlin 不区分前缀与后缀的自增自减，`n++` 和 `++n` 都会调用 `inc()`，也无法像 C++ 那样通过参数区分。它们只改变变量本身，返回值不参与运算。

---

## 复合赋值运算符

复合赋值 `a += b` 有两种翻译方式，取决于类型定义的是 `plus` 还是 `plusAssign`。

如果两个都定义了，编译器无法判断该用哪一个，会直接报错。

| 定义了什么 | a += b 的翻译 | 适用场景 |
| --- | --- | --- |
| 只有 plus | a = a + b | 不可变类型，a 必须是 var |
| 只有 plusAssign | a.plusAssign(b) | 可变类型，a 可以是 val |
| 两者都有 | 编译报错 | 必须删掉一个 |

**实例**

```kotlin
class Basket {
    private val items = mutableListOf<String>()

    // plusAssign 返回 Unit，修改的是对象自身状态
    // 因此 basket 声明为 val 也可以使用 +=
    operator fun plusAssign(item: String) {
        items += item
    }

    override fun toString(): String = items.toString()
}

fun main() {
    val basket = Basket()
    basket += "苹果"
    basket += "香蕉"
    basket += "RUNOOB 周边"
    println(basket)
}
```

运行结果：

```text
[苹果, 香蕉, RUNOOB 周边]
```

---

## 比较运算符

结构相等由 `equals` 决定，大小比较由 `compareTo` 决定。

`equals` 已经在 `Any` 中声明为运算符，所以重写它时只需要写 `override`，不用再加 `operator`。

**实例**

```kotlin
data class Version(val major: Int, val minor: Int) : Comparable<Version> {
    // 实现 Comparable 接口后，> < >= <= 都能直接用
    override fun compareTo(other: Version): Int {
        if (major != other.major) return major - other.major
        return minor - other.minor
    }
}

fun main() {
    val current = Version(2, 2)
    val old = Version(1, 9)

    println(current > old)
    println(current < old)
    println(current >= Version(2, 2))
    println(current == Version(2, 2))
    println(current != old)
}
```

运行结果：

```text
true
false
true
true
true
```

> **契约：**如果 `compareTo` 返回 0，`equals` 也应该返回 true。违反这个约定会让 `sorted()`、`TreeSet` 这类依赖比较的 API 出现难以排查的问题。

---

## 索引访问与 in

方括号读取对应 `get`，方括号赋值对应 `set`，`in` 对应 `contains`。

这三个函数都支持多个参数，因此可以实现二维索引。

**实例**

```kotlin
class Playlist {
    private val songs = mutableListOf<String>()

    // list[0] -> list.get(0)
    operator fun get(index: Int): String = songs[index]

    // list[0] = "x" -> list.set(0, "x")
    operator fun set(index: Int, value: String) {
        songs[index] = value
    }

    // "x" in list -> list.contains("x")
    operator fun contains(title: String): Boolean = songs.any { it.contains(title) }

    operator fun plusAssign(song: String) {
        songs += song
    }
}

fun main() {
    val list = Playlist()
    list += "Runoob 教程"
    list += "Kotlin 入门"
    list += "RUNOOB 实战"

    println(list[0])
    list[1] = "Kotlin 值类"
    println(list[1])
    println("值类" in list)
    println("Java" in list)
}
```

运行结果：

```text
Runoob 教程
Kotlin 值类
true
false
```

---

## invoke：像函数一样调用对象

定义了 `invoke` 之后，对象本身就可以像函数一样被调用。

配合 `vararg` 参数，还能让同一个对象支持多种调用形式。

**实例**

```kotlin
class Formatter(val prefix: String) {
    // f("x") -> f.invoke("x")
    operator fun invoke(text: String): String = "$prefix$text"

    // f("x", "y") -> f.invoke("x", "y")
    operator fun invoke(vararg texts: String): String =
        texts.joinToString(", ") { "$prefix$it" }
}

fun main() {
    val f = Formatter("[RUNOOB] ")
    println(f("第一条"))
    println(f("第一条", "第二条", "第三条"))
}
```

运行结果：

```text
[RUNOOB] 第一条
[RUNOOB] 第一条, [RUNOOB] 第二条, [RUNOOB] 第三条
```

---

## 实践示例：二维向量

向量是运算符重载最自然的应用场景，加减、数乘、取负、按下标取分量都符合数学直觉。

**实例**

```kotlin
data class Vector(val x: Double, val y: Double) {
    operator fun plus(other: Vector) = Vector(x + other.x, y + other.y)

    operator fun minus(other: Vector) = Vector(x - other.x, y - other.y)

    // 数乘：向量 * 标量
    operator fun times(scale: Double) = Vector(x * scale, y * scale)

    operator fun unaryMinus() = Vector(-x, -y)

    // v[0] 取 x，v[1] 取 y
    operator fun get(index: Int): Double = when (index) {
        0 -> x
        1 -> y
        else -> throw IndexOutOfBoundsException("向量只有两个分量，索引为 $index")
    }

    override fun toString(): String = "($x, $y)"
}

fun main() {
    val a = Vector(1.0, 2.0)
    val b = Vector(3.0, 4.0)

    println(a + b)
    println(a - b)
    println(a * 2.0)
    println(-a)
    println(a[0])
    println(a[1])
}
```

运行结果：

```text
(4.0, 6.0)
(-2.0, -2.0)
(2.0, 4.0)
(-1.0, -2.0)
1.0
2.0
```

---

## 实践示例：金额

金额运算同样适合用运算符表达，配合值类还能顺带获得类型安全。

下面的例子把金额以"分"为单位存成 Long，避免浮点数带来的精度问题。

**实例**

```kotlin
import kotlin.math.abs

@JvmInline
value class Money(val cents: Long) {
    operator fun plus(other: Money) = Money(cents + other.cents)

    operator fun minus(other: Money) = Money(cents - other.cents)

    // 数量倍乘
    operator fun times(quantity: Int) = Money(cents * quantity)

    operator fun compareTo(other: Money): Int = cents.compareTo(other.cents)

    // 输出成 19.99 这样的金额格式
    override fun toString(): String {
        val sign = if (cents < 0) "-" else ""
        val absCents = abs(cents)
        return "$sign${absCents / 100}.${(absCents % 100).toString().padStart(2, '0')}"
    }
}

fun main() {
    val price = Money(1999)             // 19.99
    val total = price * 3 + Money(500)  // 19.99 * 3 + 5.00

    println("单价：$price")
    println("总价：$total")
    println("总价大于单价：${total > price}")
    println("差额：${total - price}")
}
```

运行结果：

```text
单价：19.99
总价：64.97
总价大于单价：true
差额：44.98
```

---

## 注意事项：不要滥用

运算符重载能提高可读性，前提是它的语义和符号的常见含义一致。

如果 `+` 做的是删除、`*` 做的是取第一个元素，代码会变得比直接调用函数更难懂。

| 原则 | 说明 |
| --- | --- |
| 语义要直观 | + 表示合并或相加，* 表示缩放或重复 |
| 不要改变自身状态 | plus 应返回新对象；要修改自身请改用 plusAssign |
| 不要同时定义 plus 与 plusAssign | 会导致复合赋值产生歧义 |
| 保持与 equals 一致 | compareTo 返回 0 时 equals 也应为 true |
| 优先可读性 | 如果函数名比运算符更清楚，就不要重载 |
| 别为省字符而重载 | 重载的收益应该是表达力，而不是少敲几个字母 |

---

## 常见问题

为什么 `equals` 不用写 `operator`？

因为 `equals` 已经在 `Any` 中声明为运算符函数，子类重写时只需要 `override`，写 `operator` 反而会报错。

扩展函数能重载运算符吗？

可以，但 `equals` 例外。它必须在类中重写，不能写成扩展函数，因为扩展函数是静态解析的，无法参与多态。

为什么 `a += b` 会报歧义错误？

因为编译器同时找到了 `plus` 和 `plusAssign` 两个候选。保留 `plus` 表示返回新对象，保留 `plusAssign` 表示原地修改，二选一即可。

为什么自定义的 `inc()` 需要 var 变量？

因为 `a++` 会被翻译成 `a = a.inc()`，本质是一次重新赋值，val 变量无法完成这个操作。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-operator.html)，版权归原作者所有，仅供非商业学习使用。
