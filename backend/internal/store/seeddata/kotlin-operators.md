运算符是用来对数据做运算的符号，例如加法 `+`、比较 `>`、逻辑与 `&&`。

Kotlin 的算术、赋值、比较、逻辑运算符与 Java 基本一致，但位运算没有符号，改用具名函数。

本篇还会介绍区间运算符 `..` 和 `..<`，它们是 Kotlin 里非常常用的语法糖。

---

## 算术运算符

Kotlin 支持加、减、乘、除、取余五种二元算术运算符，以及正负号和自增自减。

需要特别注意的是整数除法：两个整数相除，结果仍然是整数，小数部分被直接丢弃。

**实例**

```kotlin
fun main() {
    println(7 + 3)      // 10
    println(7 - 3)      // 4
    println(7 * 3)      // 21
    println(7 / 3)      // 2，整数除法直接截断小数部分
    println(7 % 3)      // 1，取余
    println(7.0 / 3)    // 2.3333333333333335，有一个是浮点结果就是浮点
    println(-7 % 3)     // -1，余数的符号与被除数一致

    // 整数除以零会抛异常
    // println(1 / 0)   // 抛出 ArithmeticException: / by zero
    // 浮点除以零不会抛异常
    println(1.0 / 0.0)  // Infinity
    println(0.0 / 0.0)  // NaN

    // 一元运算符
    println(-5)         // -5
    println(+5)         // 5

    // 自增自减
    var i = 1
    println(i++)        // 1，先取值再加 1
    println(i)          // 2
    println(++i)        // 3，先加 1 再取值
    println(i--)        // 3
    println(i)          // 2
}
```

```text
10
4
21
2
1
2.3333333333333335
-1
Infinity
NaN
-5
5
1
2
3
3
2
```

> **注意：**Kotlin 没有幂运算符，不要写 `2 ** 10`。整数幂用 `1 shl 10`，浮点幂用 `kotlin.math.pow`。

整数除法的截断行为容易出错，例如计算百分比时应该先转成浮点数。

**实例**

```kotlin
fun main() {
    val done = 3
    val total = 4

    // 两个 Int 相除，结果被截断成 0
    println(done / total)                    // 0

    // 先转成 Double 再做除法
    println(done.toDouble() / total)         // 0.75

    // 或者用乘法先放大
    println(done * 100 / total)              // 75
}
```

```text
0
0.75
75
```

---

## 赋值与复合赋值

Kotlin 的赋值运算符是 `=`，此外还有五种复合赋值运算符，把运算和赋值合并在一起。

| 运算符 | 等价写法 | 说明 |
| --- | --- | --- |
| += | a = a + b | 加后赋值 |
| -= | a = a - b | 减后赋值 |
| *= | a = a * b | 乘后赋值 |
| /= | a = a / b | 除后赋值 |
| %= | a = a % b | 取余后赋值 |

**实例**

```kotlin
fun main() {
    var a = 10

    a += 5      // 等价于 a = a + 5
    println(a)  // 15

    a -= 3
    println(a)  // 12

    a *= 2
    println(a)  // 24

    a /= 5
    println(a)  // 4

    a %= 3
    println(a)  // 1
}
```

```text
15
12
24
4
1
```

> **注意：**Kotlin 中赋值不是表达式，`a = b` 没有返回值。所以 `while ((line = read()) != null)` 这种 Java 写法在 Kotlin 里无法通过编译，要拆成两步。位运算也没有对应的复合赋值，不存在 `shl=`，只能写成 `a = a shl 2`。

---

## 比较运算符

比较运算符用于判断大小或相等关系，结果一定是 Boolean。

`==` 比较值（结构相等），`===` 比较引用（是否是同一个对象），两者的区别在第 05 篇《Kotlin 基本数据类型》有详细说明。

**实例**

```kotlin
fun main() {
    println(3 == 3)           // true
    println(3 != 4)           // true
    println(3 < 4)            // true
    println(3 > 4)            // false
    println(3 <= 3)           // true
    println(3 >= 4)           // false

    // 字符串按字典序比较
    println("abc" < "abd")    // true

    // 不同类型可以用大小比较，走的是 compareTo 重载
    println(3 < 3.5)          // true
}
```

```text
true
true
true
false
true
false
true
true
```

自定义类型想支持比较运算符，需要实现 Comparable 接口并重写 compareTo 方法，这一点在运算符重载一篇中会详细介绍。

---

## 逻辑运算符

逻辑运算符有三个：`&&`（与）、`||`（或）、`!`（非），操作数必须是 Boolean。

`&&` 和 `||` 都是短路运算符：左侧已经能决定结果时，右侧不会求值。

**实例**

```kotlin
fun check(): Boolean {
    println("check 被调用")
    return true
}

fun main() {
    val t = true
    val f = false

    println(t && f)          // false
    println(t || f)          // true
    println(!t)              // false

    // 短路演示
    println(f && check())    // false，左侧已为 false，右侧不求值
    println(t || check())    // true，左侧已为 true，右侧不求值
    println(t && check())    // true，右侧必须求值
}
```

```text
false
true
false
false
true
check 被调用
true
```

短路特性常用于避免空指针：先判断对象不为 null，再访问它的成员。

**实例**

```kotlin
fun main() {
    val name: String? = null

    // 左侧为 false 时，右侧的 name.length 不会执行
    if (name != null && name.length > 0) {
        println("名字长度：${name.length}")
    } else {
        println("名字为空")   // 名字为空
    }
}
```

```text
名字为空
```

---

## 位运算

Kotlin 没有 `<<`、`>>`、`&`、`|` 这类位运算符，取而代之的是一组具名函数。

这些函数以中缀形式调用，可读性更好，例如 `a shl 2` 表示左移两位。

| 函数 | 含义 | 对应 Java 写法 |
| --- | --- | --- |
| shl | 左移，低位补 0 | << |
| shr | 有符号右移，高位补符号位 | >> |
| ushr | 无符号右移，高位补 0 | >>> |
| and | 按位与 | & |
| or | 按位或 | \| |
| xor | 按位异或 | ^ |
| inv | 按位取反，是普通函数要加括号 | ~ |

**实例**

```kotlin
fun main() {
    val a = 0b1100    // 十进制 12
    val b = 0b1010    // 十进制 10

    println(a and b)     // 8，0b1000
    println(a or b)      // 14，0b1110
    println(a xor b)     // 6，0b0110
    println(a.inv())     // -13，按位取反

    println(a shl 1)     // 24，左移一位等于乘 2
    println(a shr 1)     // 6，右移一位等于除以 2
    println(-8 shr 1)    // -4，有符号右移保留符号位
    println(-8 ushr 1)   // 2147483644，无符号右移高位补 0

    // 中缀函数优先级低于算术运算符
    println(1 + 2 shl 3) // 24，先算 1 + 2 再左移 3 位
}
```

```text
8
14
6
-13
24
6
-4
2147483644
24
```

> **注意：**位运算函数只定义在 Int 和 Long（以及 UInt、ULong）上，Byte 和 Short 需要先调用 `toInt()` 转换，否则编译不通过。

下面的例子演示了位运算的两个常见用途：取出某几位、以及用位掩码表示多个开关。

**实例**

```kotlin
fun main() {
    val color = 0xFFCC00   // 一个 24 位的 RGB 颜色

    // 右移 16 位再取低 8 位，得到红色分量
    val red = (color shr 16) and 0xFF
    val green = (color shr 8) and 0xFF
    val blue = color and 0xFF

    println("R=$red G=$green B=$blue")   // R=255 G=204 B=0

    // 用位掩码表示多个开关
    val READ = 0b001
    val WRITE = 0b010
    val EXEC = 0b100

    var permission = READ or WRITE        // 拥有读和写权限
    println(permission)                   // 3
    println((permission and READ) != 0)   // true，有读权限
    println((permission and EXEC) != 0)   // false，没有执行权限
}
```

```text
R=255 G=204 B=0
3
true
false
```

---

## 区间运算符

区间表示一段连续的值，Kotlin 提供了闭区间 `..` 和开区间 `..<` 两种写法。

`1..5` 包含 1 到 5 全部五个数，`1..<5` 包含 1 到 4，不包含 5。

`..<` 在 Kotlin 1.7.20 中作为实验特性引入，`Kotlin 1.9 起稳定`。

| 写法 | 含义 | 示例结果 |
| --- | --- | --- |
| 1..5 | 闭区间，包含右端点 | [1, 2, 3, 4, 5] |
| 1..<5 | 开区间，不含右端点，Kotlin 1.9 起稳定 | [1, 2, 3, 4] |
| 1 until 5 | 与 1..<5 等价 | [1, 2, 3, 4] |
| 5 downTo 1 | 递减区间 | [5, 4, 3, 2, 1] |
| 1..10 step 3 | 指定步长 | [1, 4, 7, 10] |

**实例**

```kotlin
fun main() {
    val closed = 1..5
    println(closed)                    // 1..5
    println(5 in closed)               // true
    println(closed.toList())           // [1, 2, 3, 4, 5]

    val open = 1..<5
    println(open)                      // 1..4
    println(5 in open)                 // false
    println(open.toList())             // [1, 2, 3, 4]

    println((1 until 5).toList())      // [1, 2, 3, 4]
    println((5 downTo 1).toList())     // [5, 4, 3, 2, 1]
    println((1..10 step 3).toList())   // [1, 4, 7, 10]
    println((10 downTo 1 step 3).toList())  // [10, 7, 4, 1]

    // 字符也可以构成区间
    println(('a'..'e').toList())       // [a, b, c, d, e]
}
```

```text
1..5
true
[1, 2, 3, 4, 5]
1..4
false
[1, 2, 3, 4]
[1, 2, 3, 4]
[5, 4, 3, 2, 1]
[1, 4, 7, 10]
[10, 7, 4, 1]
[a, b, c, d, e]
```

downTo 的步长必须为正数，step 的值也必须大于 0，否则会抛出异常。

> **常见误用：**`5..1` 是一个空区间，不会自动递减。要表示从 5 到 1 必须写 `5 downTo 1`。

---

## in 与 !in

`in` 用来判断一个值是否属于某个区间、集合或字符串，`!in` 是它的取反。

它本质上是调用对象的 contains 函数，因此只要是实现了 contains 的类型都可以用。

**实例**

```kotlin
fun main() {
    // 判断数字是否在区间内
    println(3 in 1..5)                  // true
    println(9 !in 1..5)                 // true

    // 判断字符是否在字符区间内
    println('c' in 'a'..'z')            // true
    println('C' in 'a'..'z')            // false

    // 判断子串是否出现在字符串中
    val site = "www.runoob.com"
    println("runoob" in site)           // true
    println("RUNOOB" in site)           // false，区分大小写
    println('r' in site)                // true

    // 判断元素是否在集合中
    val names = listOf("Runoob", "Kotlin")
    println("Runoob" in names)          // true
    println("Java" !in names)           // true
}
```

```text
true
true
true
false
true
false
true
true
true
```

在 for 循环中，`in` 的含义是"遍历"，这一点在循环控制一篇中介绍。

---

## 运算符优先级

同一个表达式中出现多个运算符时，优先级高的先计算。

下表按优先级从高到低排列，同一行内按从左到右结合。

| 优先级 | 运算符 | 说明 |
| --- | --- | --- |
| 1 | . ?. ++ -- | 后缀、成员访问 |
| 2 | - + ++ -- ! | 前缀 |
| 3 | * / % | 乘除取余 |
| 4 | + - | 加减 |
| 5 | .. ..< | 区间 |
| 6 | shl shr ushr and or xor until downTo step to | 具名中缀函数 |
| 7 | ?: | Elvis 运算符 |
| 8 | in !in is !is | 包含与类型判断 |
| 9 | < > <= >= | 大小比较 |
| 10 | == != === !== | 相等性 |
| 11 | && | 逻辑与 |
| 12 | \|\| | 逻辑或 |
| 13 | = += -= *= /= %= | 赋值 |

记不住优先级时，加括号是最稳妥的做法，也让代码更易读。

**实例**

```kotlin
fun main() {
    // && 的优先级高于 ||
    println(true || false && false)     // true，等价于 true || (false && false)

    // 区间运算符的优先级高于中缀函数
    println(1..5 step 2)                // 1..5 step 2

    // 中缀函数优先级低于算术运算符
    println(1 + 2 shl 3)                // 24，等价于 (1 + 2) shl 3

    // 加括号让意图更清晰
    println((true || false) && false)   // false
}
```

```text
true
1..5 step 2
24
false
```

`1..5 step 2` 的结果是 IntProgression，打印出来是 1..5 step 2，转成列表就是 [1, 3, 5]。

---

## 常见问题

下面是运算符使用中最容易出错的几个问题。

### 为什么 5 / 2 的结果是 2 而不是 2.5

因为两个操作数都是 Int，Kotlin 执行的是整数除法，小数部分被直接截断。

想要小数结果，把其中一个操作数用 toDouble() 转换即可。

### Kotlin 有没有三元运算符

没有。Kotlin 用 if 表达式代替，例如 `val max = if (a > b) a else b`，可读性更好。

### 为什么 && 和 || 不总是两个都算

因为它们采用短路求值，左侧能决定结果时右侧不求值。

这个特性既提升性能，也常用来避免空指针，但要注意右侧的副作用可能不会执行。

### 位移和乘除法的关系

左移一位相当于乘 2，右移一位相当于整除 2，只在没有溢出的前提下成立。

有符号右移 shr 会保留符号位，无符号右移 ushr 高位补 0，处理负数时结果完全不同。

### 为什么 a = b 不能写在条件里

因为 Kotlin 的赋值不是表达式，没有返回值，无法参与判断。

把读取和判断拆成两步写，代码反而更清晰。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-operators.html)，版权归原作者所有，仅供非商业学习使用。
