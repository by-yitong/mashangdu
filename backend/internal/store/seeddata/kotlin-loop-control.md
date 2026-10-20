循环让同一段代码重复执行，是控制程序流程最基本的工具之一。

Kotlin 的循环语法和 Java 很像，但没有传统的三段式 `for (int i = 0; i < n; i++)`，取而代之的是直接遍历集合与区间。

本页介绍 for、while、do...while 三种循环，以及 break、continue 的标签跳转，最后是 Kotlin 2.2 起稳定的非局部 break 与 continue。

---

## for 循环

for 循环用于遍历任何提供了迭代器（iterator）的对象，集合、数组、区间都可以。

语法是 `for (元素 in 可迭代对象) { ... }`，元素不需要声明类型，编译器会自动推断。

**实例**

```kotlin
// 文件路径：LoopFor.kt
fun main() {
    // listOf 创建一个只读列表
    val sites = listOf("Runoob", "www.runoob.com", "RUNOOB")

    // 依次取出每个元素，变量 site 的类型自动推断为 String
    for (site in sites) {
        println(site)
    }
}
```

运行结果如下。

```text
Runoob
www.runoob.com
RUNOOB
```

遍历数组的方式完全一样，因为数组同样提供了迭代器。

**实例**

```kotlin
fun main() {
    // intArrayOf 创建 Int 数组，避免装箱开销
    val numbers = intArrayOf(10, 20, 30)

    for (number in numbers) {
        println("当前元素：$number")
    }
}
```

```text
当前元素：10
当前元素：20
当前元素：30
```

Kotlin 的 for 只负责"取出元素"，不负责维护计数器，因此不会有忘记写 `i++` 导致死循环的问题。

---

## 区间与步长

区间（range）本身就是一个可遍历对象，用 `..`、`until`、`downTo`、`step` 构造。

它们的边界规则各不相同，混用是初学者最容易出错的地方。

| 写法 | 含义 | 遍历结果 |
| --- | --- | --- |
| `1..5` | 闭区间，包含左右两端 | 1 2 3 4 5 |
| `1 until 5` | 左闭右开，不包含右端 | 1 2 3 4 |
| `5 downTo 1` | 从大到小递减 | 5 4 3 2 1 |
| `1..10 step 2` | 指定步长，只取奇数 | 1 3 5 7 9 |
| `1..<5` | 半开区间，等价于 until，Kotlin 1.9 起稳定 | 1 2 3 4 |

下面的例子把这几种写法放在一起对比。

**实例**

```kotlin
fun main() {
    // 闭区间 1..3：包含左右两端
    for (i in 1..3) print("$i")
    println("  => 1..3")

    // until：包含左端，不包含右端
    for (i in 1 until 3) print("$i")
    println("  => 1 until 3")

    // downTo：从大到小递减
    for (i in 3 downTo 1) print("$i")
    println("  => 3 downTo 1")

    // step：指定步长，步长必须为正数
    for (i in 1..6 step 2) print("$i")
    println("  => 1..6 step 2")

    // ..< 半开区间，Kotlin 1.9 起稳定
    for (i in 1..<3) print("$i")
    println("  => 半开区间")
}
```

```text
123  => 1..3
12  => 1 until 3
321  => 3 downTo 1
135  => 1..6 step 2
12  => 半开区间
```

区间不只用于循环，也可以用 `in` 判断某个值是否落在区间内，例如 `if (age in 18..60)`。

> **提示：**直接遍历区间会被编译器优化成普通计数循环，不会为每个元素创建对象。但如果先写 `(1..1000).toList()` 再遍历，就会真的创建一个包含 1000 个元素的列表。

---

## 用下标遍历：indices 与 withIndex

需要同时拿到下标和元素值时，可以用 `indices` 或库函数 `withIndex()`。

`indices` 是下标区间，`withIndex()` 返回一组带下标的元素，可以配合解构声明使用。

**实例**

```kotlin
fun main() {
    val sites = listOf("Runoob", "www.runoob.com", "RUNOOB")

    // indices 返回下标区间 0..2，适合需要按下标再取值的场景
    for (i in sites.indices) {
        println("下标 $i -> ${sites[i]}")
    }

    println("---")

    // withIndex() 同时给出下标和值，(index, value) 是解构声明
    for ((index, value) in sites.withIndex()) {
        println("$index: $value")
    }
}
```

```text
下标 0 -> Runoob
下标 1 -> www.runoob.com
下标 2 -> RUNOOB
---
0: Runoob
1: www.runoob.com
2: RUNOOB
```

Map 也是可迭代对象，遍历时可以直接解构出键和值。

**实例**

```kotlin
fun main() {
    // mapOf 返回保持插入顺序的 Map
    val info = mapOf("name" to "Runoob", "site" to "www.runoob.com")

    for ((key, value) in info) {
        println("$key = $value")
    }
}
```

```text
name = Runoob
site = www.runoob.com
```

---

## while 循环

while 先判断条件，条件为真才执行循环体，可能一次都不执行。

循环次数不确定、依赖运行时状态时，while 比 for 更合适。

**实例**

```kotlin
fun main() {
    var count = 3

    while (count > 0) {
        println("倒计时 $count")
        count--            // 必须改变循环变量，否则会死循环
    }

    println("循环结束")
}
```

```text
倒计时 3
倒计时 2
倒计时 1
循环结束
```

如果条件一开始就是 false，循环体一次也不会执行。

**实例**

```kotlin
fun main() {
    var count = 0

    while (count > 0) {
        println("这一行永远不会输出")
        count--
    }

    println("循环结束，count = $count")
}
```

```text
循环结束，count = 0
```

---

## do...while 循环

do...while 先执行一次循环体，再判断条件，因此循环体至少执行一次。

适合"先做一次、再决定要不要继续"的场景，比如读取输入、重试操作。

**实例**

```kotlin
fun main() {
    var count = 0

    do {
        println("循环体执行：count = $count")
        count++
    } while (count < 0)    // 条件一开始就为 false，但循环体已经执行过一次

    println("循环结束")
}
```

```text
循环体执行：count = 0
循环结束
```

> **注意：**do...while 的 `while` 后面要写分号，而普通 while 和 for 不需要。这是 Kotlin 中少数必须写分号的位置之一。

![循环写法选择流程图：重复次数或遍历对象已知用 for，条件驱动但可能一次都不执行用 while，条件驱动且至少执行一次用 do...while；break 结束整个循环，continue 跳过本次，标签可让跳转作用于外层循环](images/kotlin/kotlin-loop-control/09-loop-choice.svg)

---

## break 与 continue

break 立即结束最内层的循环，continue 跳过本次迭代、直接进入下一次。

两者都只作用于"最直接包围它们的循环"，除非配合标签使用。

**实例**

```kotlin
fun main() {
    for (i in 1..10) {
        if (i == 3) continue   // i 为 3 时跳过，不执行下面的 println
        if (i > 5) break       // i 为 6 时结束整个循环
        println(i)
    }
}
```

```text
1
2
4
5
```

| 跳转表达式 | 作用 | 典型场景 |
| --- | --- | --- |
| `break` | 终止最近的循环 | 找到目标后提前退出，避免无谓遍历 |
| `continue` | 跳过本次迭代，进入下一次 | 过滤掉不满足条件的元素 |
| `return` | 从最近的函数返回 | 结束函数执行并带回结果 |

---

## 标签与标签跳转

标签是标识符后面加 `@`，写在循环或 lambda 前面，用来给 break、continue、return 指定目标。

![标签跳转控制流图：外层 loop@ for 循环里嵌套 for (j in 1..3)，j 等于 2 时 break@loop 一次跳出两层到循环结束，continue@loop 则虚线回到外层循环的下一次迭代](images/kotlin/kotlin-loop-control/09-labeled-jump.svg)

没有标签时，break 只能结束最内层循环；有了标签才能一次跳出多层嵌套。

**实例**

```kotlin
fun main() {
    // loop@ 是外层循环的标签
    loop@ for (i in 1..3) {
        for (j in 1..3) {
            if (j == 2) continue@loop   // 跳过外层循环的本次迭代
            if (i == 3) break@loop      // 直接结束外层循环
            println("i = $i, j = $j")
        }
    }
    println("循环结束")
}
```

```text
i = 1, j = 1
i = 2, j = 1
循环结束
```

标签也可以标在 lambda 上，此时 `return@标签` 表示从这个 lambda 返回，而不是从外层函数返回。

**实例**

```kotlin
fun main() {
    // 给 lambda 起一个显式标签 check
    val check = check@{ value: Int ->
        if (value < 0) return@check "负数"
        "非负数"
    }

    println(check(5))
    println(check(-1))
}
```

```text
非负数
负数
```

> **提示：**标签名和变量名可以重名，但为了可读性，建议给循环和 lambda 起有含义的标签名，例如 `outer@`、`rows@`。

---

## 非局部 break 与 continue（2.2 起稳定）

Kotlin 2.2 起，内联 lambda 中的 break 和 continue 可以直接作用到外层的循环，这种写法叫非局部跳转。

它解决的是"在 lambda 内部想跳过或结束外层循环"的问题，此前只能用 `return@标签` 或者额外的标志变量绕开。

这个特性在 Kotlin 2.1 中作为预览提供，需要编译器选项 `-Xnon-local-break-continue` 才能使用；从 2.2 起默认可用（KT-1436）。

**实例**

```kotlin
fun main() {
    val numbers = listOf(1, null, 3, null, 5)

    for (number in numbers) {
        // run 是内联函数，它 lambda 里的 continue 作用于外层的 for 循环
        val value = number ?: run {
            println("遇到 null，跳过本次循环")
            continue
        }
        println("处理数字：$value")
    }
    println("循环结束")
}
```

```text
处理数字：1
遇到 null，跳过本次循环
处理数字：3
遇到 null，跳过本次循环
处理数字：5
循环结束
```

break 同样可以这样用，效果是直接结束外层的整个循环。

**实例**

```kotlin
fun main() {
    val numbers = listOf(1, 2, 3, 4, 5)

    for (number in numbers) {
        run {
            if (number == 4) break   // 非局部 break：结束外层的 for 循环
        }
        println("当前数字：$number")
    }
    println("循环结束")
}
```

```text
当前数字：1
当前数字：2
当前数字：3
循环结束
```

> **注意：**非局部 break/continue 只对传给内联函数（inline function）的 lambda 有效，例如 `run`、`let`、`forEach` 的 lambda。如果 lambda 被保存成变量再传给普通函数，仍然不允许这样跳转，因为编译器无法保证它一定在原地执行。

---

## return 与标签返回

return 默认从最近的函数返回，但在 lambda 中要区分两种情况：返回外层函数，还是只结束这个 lambda。

`return@标签` 只从标签对应的 lambda 返回，效果相当于 lambda 里的 continue。

**实例**

```kotlin
fun main() {
    val numbers = listOf(1, 2, 0, 4)

    // return@forEach 只结束本次 lambda 调用，等价于跳过 0
    numbers.forEach {
        if (it == 0) return@forEach
        println("forEach：$it")
    }

    println("---")

    // 用 for 循环加 continue 也能达到同样效果
    for (number in numbers) {
        if (number == 0) continue
        println("for：$number")
    }
}
```

```text
forEach：1
forEach：2
forEach：4
---
for：1
for：2
for：4
```

标签名可以省略，此时编译器用接收 lambda 的函数名作为隐式标签，所以 `return@forEach` 里的 `forEach` 就是隐式标签。

> **注意：**`forEach` 是内联函数，所以在它的 lambda 里直接写 `return` 会从外层函数返回，而不是只结束这一次遍历。这种非局部返回的规则会在《Kotlin 内联函数与 reified》一篇详细展开；日常写法中，只跳过当前元素请用 `return@forEach`。

---

## 常见问题

下面整理几个初学者经常遇到的疑问。

| 问题 | 说明 |
| --- | --- |
| for 循环里的区间会创建对象吗 | 直接遍历 `1..10` 会优化成计数循环，不创建额外对象；先转成 List 再遍历则会创建集合 |
| 在 forEach 里写 continue 报错 | forEach 的 lambda 不是循环，改用 `return@forEach`，或者换成 for 循环 |
| do...while 后面为什么有分号 | Kotlin 语法规定 `while (条件)` 之后要写分号，这是分号不能省略的少数位置 |
| 标签写在哪里 | 标签紧跟在被标记对象前面，例如 `loop@ for (...)`、`name@ { ... }` |
| 非局部 break 在旧版本报错 | 该特性 2.1 为预览、2.2 起稳定；旧版本请改用标签返回或标志变量 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-loop-control.html)，版权归原作者所有，仅供非商业学习使用。
