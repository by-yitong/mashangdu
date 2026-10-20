Kotlin 是一门静态类型语言，变量在声明时类型就已经确定，编译器会在编译期检查类型是否正确。

Kotlin 把数据分为数值类型（Byte、Short、Int、Long、Float、Double）、布尔类型 Boolean、字符类型 Char、字符串类型 String 以及数组类型等。

本篇介绍这些基本类型的取值范围、字面量写法和相互转换规则，它们是后面学习函数、集合和面向对象的基础。

---

## 数值类型与位宽

Kotlin 的数值类型与 Java 基本一致，但有一个重要区别：Kotlin 的 Char 不属于数值类型，不能直接参与数值运算。

下表列出了六种数值类型的位宽与取值范围。

| 类型 | 位宽 | 取值范围 | 说明 |
| --- | --- | --- | --- |
| Byte | 8 | -128 ~ 127 | 最小的整数类型 |
| Short | 16 | -32768 ~ 32767 | 较少使用 |
| Int | 32 | -2147483648 ~ 2147483647 | 整数的默认类型 |
| Long | 64 | -9223372036854775808 ~ 9223372036854775807 | 字面量需要加 L 后缀 |
| Float | 32 | 约 ±3.4×10^38 | 单精度，6~7 位有效数字，字面量加 f 后缀 |
| Double | 64 | 约 ±1.8×10^308 | 双精度，15~16 位有效数字，浮点的默认类型 |

在 JVM 平台上，非空的 Int、Long、Double 会直接使用 Java 的 int、long、double 基本类型表示，不会产生额外的对象开销。

只有把它们放进泛型、或者声明为可空类型（例如 Int?）时，才会发生装箱（boxing），变成 Integer、Long 这样的对象。

### 位宽与溢出

每种整数类型的位宽是固定的，运算结果超出范围时会发生溢出，而不是抛出异常。

下面的例子演示了 Int 的边界行为。

**实例**

```kotlin
fun main() {
    val max = Int.MAX_VALUE      // Int 的最大值
    println(max)                 // 2147483647
    println(max + 1)             // -2147483648，溢出后绕回最小值

    val min = Int.MIN_VALUE      // Int 的最小值
    println(min)                 // -2147483648
    println(min - 1)             // 2147483647，向另一个方向溢出

    // 需要更大范围时使用 Long，注意先把 Int 转成 Long 再相加
    val big = Int.MAX_VALUE.toLong() + 1
    println(big)                 // 2147483648
}
```

```text
2147483647
-2147483648
-2147483648
2147483647
2147483648
```

> **注意：**Kotlin 不会为整数溢出报错，这与 Java 的行为一致。涉及金额、时间戳等敏感计算时，应主动检查范围或改用 Long、BigInteger。

---

## 字面常量

字面常量就是直接写在代码里的值，比如 123、0x0F、3.14。

Kotlin 支持十进制、十六进制和二进制三种整数写法，`不支持八进制`，这是它与 C、Java 的一个差异。

下表汇总了各种字面量的写法。

| 写法 | 示例 | 说明 |
| --- | --- | --- |
| 十进制 | 123 | 默认推断为 Int |
| 十六进制 | 0x0F | 0x 前缀，大小写均可 |
| 二进制 | 0b00001011 | 0b 前缀 |
| 八进制 | 无 | Kotlin 不支持八进制字面量 |
| Long | 123L | L 后缀，超出 Int 范围的字面量也会推断为 Long |
| Double | 123.5、123.5e10 | 浮点字面量的默认类型 |
| Float | 123.5f | f 或 F 后缀 |
| 下划线分隔 | 1_000_000 | 仅用于提升可读性，编译器会忽略下划线 |

下划线只能放在数字之间，不能放在开头、结尾，也不能紧挨小数点。

下面的例子覆盖了这些写法。

**实例**

```kotlin
fun main() {
    val dec = 123                  // 十进制
    val hex = 0x0F                 // 十六进制，等于十进制的 15
    val bin = 0b00001011           // 二进制，等于十进制的 11
    val long = 123L                // Long 字面量
    val oneMillion = 1_000_000     // 下划线分隔，方便阅读

    // 十六进制和二进制同样可以用下划线分组
    val hexBytes = 0xFF_EC_DE
    val bytes = 0b1101_0010

    // 浮点字面量默认是 Double，加 f 后缀才是 Float
    val pi = 3.14
    val piFloat = 3.14f
    val sci = 123.5e10             // 科学计数法，等于 1.235E12

    println(dec)
    println(hex)
    println(bin)
    println(long)
    println(oneMillion)
    println(hexBytes)
    println(bytes)
    println(pi)
    println(piFloat)
    println(sci)
}
```

```text
123
15
11
123
1000000
16772318
210
3.14
3.14
1.235E12
```

> **注意：**如果写成 0755 这样的八进制形式，Kotlin 会把它当作十进制 755 处理，不会报错也不会得到八进制的结果，这一点要特别小心。

---

## 数值类型之间没有隐式转换

这是 Kotlin 与 Java、C 的一个关键差异：`较小的数值类型不会自动转换为较大的类型`。

即使是 Byte 转 Int 这种看起来安全的转换，也必须显式调用转换函数。

这样设计是为了避免静默的数据丢失，代价是代码里会多出一些转换调用。

**实例**

```kotlin
fun main() {
    val b: Byte = 1
    // val i: Int = b        // 编译错误：Kotlin 不会把 Byte 隐式转换为 Int
    val i: Int = b.toInt()   // 必须显式调用转换函数
    println(i)               // 1

    // 字面量是例外：编译器在编译期就能确认 100 在 Byte 范围内
    val b2: Byte = 100
    println(b2)              // 100

    // 算术运算可以混合类型，结果类型由操作数决定
    val l = 1L + 3           // Long + Int 得到 Long
    println(l)               // 4
}
```

```text
1
100
4
```

字面量能直接赋值给更小的类型，是因为编译器在编译期就能确定它的值在范围内。

而把变量赋给另一种类型时，编译器无法保证运行时的值不会溢出，所以一律报错。

### 显式类型转换

每种数值类型都提供了一整套转换函数，函数名以 to 开头。

下表列出了 Int 上的全部转换函数。

| 函数 | 返回类型 | 说明 |
| --- | --- | --- |
| toByte() | Byte | 超出 Byte 范围时按位截断 |
| toShort() | Short | 超出 Short 范围时按位截断 |
| toInt() | Int | 返回自身 |
| toLong() | Long | 安全放大 |
| toFloat() | Float | 大数值可能丢失精度 |
| toDouble() | Double | 大数值可能丢失精度 |
| toChar() | Char | 把码点转换为对应字符 |
| toUByte() | UByte | Kotlin 1.5 起 |
| toUShort() | UShort | Kotlin 1.5 起 |
| toUInt() | UInt | Kotlin 1.5 起 |
| toULong() | ULong | Kotlin 1.5 起 |

其他数值类型同样拥有这些函数，只是返回自身类型的那个会原样返回。

下面的例子演示了几种典型的转换结果。

**实例**

```kotlin
fun main() {
    val i: Int = 65

    println(i.toByte())      // 65
    println(i.toShort())     // 65
    println(i.toLong())      // 65
    println(i.toFloat())     // 65.0
    println(i.toDouble())    // 65.0
    println(i.toChar())      // A，65 是字符 A 的码点

    // 浮点转整数会直接丢弃小数部分，而不是四舍五入
    val d: Double = 3.99
    println(d.toInt())       // 3
    println(d.toLong())      // 3

    // 超出目标类型范围时按位截断
    val big: Int = 300
    println(big.toByte())    // 44，300 超出 Byte 范围，保留低 8 位
}
```

```text
65
65
65
65.0
65.0
A
3
3
44
```

> **注意：**浮点转整数是直接截断小数部分，3.99.toInt() 的结果是 3。需要四舍五入请使用 kotlin.math.roundToInt()。

---

## 无符号类型

Kotlin 提供 UByte、UShort、UInt、ULong 四种无符号整数类型，它们只能表示零和正数，但正数范围是有符号类型的两倍。

这四种类型在 Kotlin 1.3 中引入（实验性），`Kotlin 1.5 起稳定`。

与它们配套的 UByteArray 等无符号数组目前仍是 Beta 特性，使用时需要加上 @ExperimentalUnsignedTypes 注解。

| 类型 | 位宽 | 取值范围 |
| --- | --- | --- |
| UByte | 8 | 0 ~ 255 |
| UShort | 16 | 0 ~ 65535 |
| UInt | 32 | 0 ~ 4294967295 |
| ULong | 64 | 0 ~ 18446744073709551615 |

无符号字面量用 u、U、uL、UL 后缀表示，具体类型可以由期望类型推断出来。

**实例**

```kotlin
fun main() {
    val u: UInt = 42u           // u 后缀，配合期望类型得到 UInt
    val ul: ULong = 1u          // 期望类型是 ULong，所以 1u 也按 ULong 处理
    val explicit: ULong = 1uL   // uL 后缀显式指定 ULong
    val byte: UByte = 0xFFu     // 期望类型是 UByte，255 在范围内
    val us: UShort = 1u         // 期望类型是 UShort

    println(u)                  // 42
    println(ul)                 // 1
    println(explicit)           // 1
    println(byte)               // 255
    println(us)                 // 1
    println(UInt.MAX_VALUE)     // 4294967295
    println(UByte.MIN_VALUE)    // 0
    println(u + 1u)             // 43，无符号运算
    println(u.toInt())          // 42，转回有符号 Int
}
```

```text
42
1
1
255
1
4294967295
0
43
42
```

无符号类型不是有符号类型的子类型，两者之间也不能隐式转换，混用会直接编译报错。

> **使用场景：**无符号类型主要用于表示完整的位模式，例如 32 位颜色值 0xFFCC00CCu。它并不适合表达业务上"不能为负"的数值，集合下标仍应使用 Int，因为空集合的 lastIndex 需要返回 -1。

---

## 比较两个数字

Kotlin 提供两种相等性判断：`==` 判断结构相等（值是否相等），`===` 判断引用相等（是否是同一个对象）。

对于 Int、Long、Double 这类在运行时以基本类型表示的值，`===` 等价于 `==`，比较引用没有实际意义。

要观察引用相等的差异，必须使用装箱后的可空类型，例如 Int?。

**实例**

```kotlin
fun main() {
    val a: Int = 5
    val b: Int = 10

    println(a == b)      // false，结构相等比较的是值
    println(a != b)      // true
    println(a < b)       // true
    println(a > b)       // false
    println(a <= b)      // true
    println(a >= b)      // false

    // Int 是基本类型，=== 退化为和 == 相同
    val x: Int = 1000
    val y: Int = 1000
    println(x == y)      // true
    println(x === y)     // true，对基本类型 === 等价于 ==

    // 要观察引用相等，必须使用装箱类型 Int?
    val p: Int? = 1000
    val q: Int? = 1000
    println(p == q)      // true，值相等
    println(p === q)     // false，1000 超出缓存区间，两个不同的装箱对象

    val m: Int? = 100
    val n: Int? = 100
    println(m === n)     // true，命中 JVM Integer 缓存 -128..127
}
```

```text
false
true
true
false
true
false
true
true
true
false
true
```

> **编译器会警告：**上面两处 `===` 都会触发警告 —— 对 `Int` 是 `identity equality for arguments of types 'Int' and 'Int' is deprecated`，对 `Int?` 是 `... is prohibited`。这段代码能编译运行，但正常业务代码里不要对数值使用 `===`，它的唯一用途是判断两个对象引用是否相同。

> **常见错误：**把 `val x: Int = 1000; val y: Int = 1000` 的 `x === y` 说成 false。实际上对 Int 这样的基本类型，`===` 与 `==` 完全等价，结果是 true。只有装箱成 Int? 之后，1000 超出 JVM Integer 缓存区间 -128..127，两次装箱才会产生不同的对象。

不同数值类型之间不能用 `==` 比较，因为 Int 与 Double 类型不同且没有子类型关系，编译器会直接报错。

但 `<`、`>`、`<=`、`>=` 可以跨类型使用，因为标准库为数值类型提供了一系列 compareTo 重载，例如 Int.compareTo(other: Double)。

**实例**

```kotlin
fun main() {
    val i: Int = 5
    val d: Double = 5.0

    // val bad = (i == d)      // 编译错误：Int 与 Double 不能直接用 == 比较

    // 大小比较可以跨类型，走的是 Int.compareTo(Double) 重载
    println(i < d)             // false
    println(i > 4.9)           // true
    println(i.compareTo(d))    // 0，相等时返回 0
}
```

```text
false
true
0
```

> **不要混淆：**Int 与 Double 能比较大小，靠的是重载的 Int.compareTo(Double) 函数，而不是把 Int 自动转换成 Double。Kotlin 没有隐式类型转换。

---

## 布尔类型

布尔类型用 Boolean 表示，它只有 true 和 false 两个值。

布尔值支持短路逻辑运算：`&&` 表示与，`||` 表示或，`!` 表示非。

短路的意思是，当左侧已经能决定结果时，右侧的表达式不会求值。

**实例**

```kotlin
fun main() {
    val t: Boolean = true
    val f: Boolean = false

    println(t && f)      // false
    println(t || f)      // true
    println(!t)          // false

    // 也可以使用函数形式
    println(t.and(f))    // false
    println(t.or(f))     // true
    println(t.xor(f))    // true，异或：两个值不同时为 true
    println(t.not())     // false
}
```

```text
false
true
false
false
true
true
false
```

下面的例子把求值过程打印出来，可以直观看到短路的效果。

**实例**

```kotlin
fun check(): Boolean {
    println("check 被调用")
    return true
}

fun main() {
    val f = false

    println(f && check())     // false，左侧已为 false，右侧不求值
    println(true || check())  // true，左侧已为 true，右侧不求值
    println(true && check())  // true，右侧必须求值
}
```

```text
false
true
check 被调用
true
```

若需要可空的布尔类型 Boolean?，值会被装箱，这一点与可空数值类型相同。

---

## 字符类型 Char

字符用 Char 表示，字面量必须写在单引号里，例如 'A'、'0'。

与 Java 不同，Kotlin 的 Char 不属于数值类型，不能直接赋给 Int，也不能和数字直接比较。

**实例**

```kotlin
fun main() {
    val c: Char = 'A'

    println(c)                  // A
    println(c.code)             // 65，字符的 Unicode 码点
    println(c + 1)              // B，Char + Int 得到新的 Char
    println(c - 'A')            // 0，两个 Char 相减得到 Int
    println('5'.digitToInt())   // 5，把数字字符转换成数字

    // val n: Int = c           // 编译错误：Char 不能直接赋给 Int
    val n: Int = c.code
    println(n)                  // 65
}
```

```text
A
65
B
0
5
65
```

特殊字符用反斜杠转义，下表列出了 Kotlin 支持的转义序列。

| 转义序列 | 含义 |
| --- | --- |
| \t | 制表符 |
| \b | 退格 |
| \n | 换行 |
| \r | 回车 |
| \' | 单引号 |
| \" | 双引号 |
| \\ | 反斜杠 |
| \$ | 美元符号，避免被当作字符串模板 |
| \uXXXX | 四位十六进制 Unicode 字符 |

**实例**

```kotlin
fun main() {
    println("换行符：\n第二行")        // 输出两行
    println("反斜杠：\\")              // 反斜杠：\
    println("双引号：\"")              // 双引号："
    println("美元符号：\$")            // 美元符号：$
    println("Unicode 转义：\u0041")    // Unicode 转义：A
}
```

```text
换行符：
第二行
反斜杠：\
双引号："
美元符号：$
Unicode 转义：A
```

> **提示：**Kotlin 1.5 起用 `Char.code` 获取码点，旧的 `Char.toInt()` 已不推荐使用。把数字字符转成数字请用 `digitToInt()`，非数字字符会抛出异常。

---

## 数组

数组用 Array 类表示，它有 size 属性，并通过运算符重载支持用方括号读写元素。

创建数组常用的两种方式是 arrayOf() 和 Array(size) { ... } 工厂函数。

**实例**

```kotlin
fun main() {
    // arrayOf 根据元素推断类型，得到 Array<Int>
    val a = arrayOf(1, 2, 3)

    // Array(3) { ... } 是工厂函数：it 是下标，从 0 开始
    val b = Array(3) { it * 2 }        // [0, 2, 4]

    println(a[0])                      // 1
    println(b[1])                      // 2
    println(a.size)                    // 3
    println(b.contentToString())       // [0, 2, 4]

    // 方括号等价于调用 get 和 set
    a[0] = 100
    println(a[0])                      // 100
    println(a.contentToString())       // [100, 2, 3]

    // 基本类型数组避免装箱，性能更好
    val ints: IntArray = intArrayOf(1, 2, 3)
    ints[0] = ints[1] + ints[2]
    println(ints.contentToString())    // [5, 2, 3]
}
```

```text
1
2
3
[0, 2, 4]
100
[100, 2, 3]
[5, 2, 3]
```

除了 Array，Kotlin 还提供 ByteArray、ShortArray、IntArray、LongArray、FloatArray、DoubleArray、CharArray 等专用数组，它们不产生装箱开销。

下面的例子演示了几种常见的数组创建方式。

**实例**

```kotlin
fun main() {
    val zeros = IntArray(3) { 0 }           // 指定长度和初始化函数
    val squares = IntArray(5) { it * it }   // it 是下标
    val names = Array(3) { "RUNOOB" }       // 每个元素都用同一个表达式初始化
    val nulls = arrayOfNulls<String>(2)     // 元素全部为 null

    println(zeros.contentToString())        // [0, 0, 0]
    println(squares.contentToString())      // [0, 1, 4, 9, 16]
    println(names.contentToString())        // [RUNOOB, RUNOOB, RUNOOB]
    println(nulls.contentToString())        // [null, null]

    // 二维数组：元素本身还是数组
    val grid = Array(2) { IntArray(3) { 0 } }
    grid[1][2] = 9
    println(grid[1].contentToString())      // [0, 0, 9]
}
```

```text
[0, 0, 0]
[0, 1, 4, 9, 16]
[RUNOOB, RUNOOB, RUNOOB]
[null, null]
[0, 0, 9]
```

### 数组不协变

与 Java 不同，Kotlin 的数组是不协变的（invariant）：Array<String> 不是 Array<Any> 的子类型。

这是为了类型安全。Java 允许把 String[] 赋给 Object[]，运行时写入其他类型才会抛出 ArrayStoreException，Kotlin 把这类错误提前到了编译期。

**实例**

```kotlin
fun main() {
    val strings = arrayOf("Runoob", "www.runoob.com")

    // val anys: Array<Any> = strings   // 编译错误：数组不协变

    // 需要 Array<Any> 时，只能显式复制元素
    val anys: Array<Any> = Array(strings.size) { strings[it] }
    println(anys.contentToString())     // [Runoob, www.runoob.com]
}
```

```text
[Runoob, www.runoob.com]
```

数组是固定长度的，创建后不能增删元素。需要动态长度时请使用 List、MutableList 等集合类型，详见第 28 篇《Kotlin 集合》。

---

## 常见问题

下面是初学者在使用基本数据类型时最常遇到的几个问题。

### 为什么 val b: Byte = 100 可以，val i: Int = b 却不行

100 是字面量，编译器在编译期就能确认它落在 Byte 的范围内，所以允许直接赋值。

b 是变量，运行时的值理论上可能超出目标类型范围，编译器无法证明安全，因此要求显式转换。

### Float 和 Double 应该选哪个

默认使用 Double。它精度更高，也是 Kotlin 浮点字面量的默认类型。

只有明确需要节省内存，或者对接只接受 Float 的 API 时，才使用 Float。

### 什么时候应该用 Long

时间戳（毫秒）、数据库自增 ID、文件大小等容易超过 21 亿的数值都应该用 Long。

写 Long 字面量时不要忘记 L 后缀，否则会被当成 Int 而报错。

### Array<Int> 和 IntArray 有什么区别

IntArray 底层是 Java 的 int[]，不装箱，性能更好。

Array<Int> 存放的是装箱后的 Integer 对象，可以容纳 null（即 Array<Int?>）。

性能敏感的场景优先用 IntArray，需要泛型或可空元素时再用 Array。

### Char 为什么不能和 Int 比较

因为 Kotlin 把 Char 定义为独立类型，而不是数值类型。

需要比较码点时，先用 `.code` 取出 Int 再比较；需要把数字字符转成数字时用 `digitToInt()`。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-basic-types.html)，版权归原作者所有，仅供非商业学习使用。
