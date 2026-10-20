枚举类用来定义一组固定的常量，每个常量都是这个枚举类的一个实例。

相比散落各处的字符串或数字常量，枚举让类型更安全，也让 when 分支可以被编译器检查。

Kotlin 的枚举还可以带构造参数、实现接口，甚至让每个常量拥有自己的方法实现。

---

## 定义枚举类

用 enum class 声明枚举，常量之间用逗号分隔，末尾不需要分号。

**实例**

```kotlin
enum class RunoobColor {
    RED, GREEN, BLUE
}

fun main() {
    val color = RunoobColor.RED
    println(color)                    // 直接打印就是常量名
    println(RunoobColor.RED.name)     // name 属性
    println(RunoobColor.RED.ordinal)  // ordinal 从 0 开始
}
```

```text
RED
RED
0
```

枚举常量本身是单例，用 == 比较即可，不需要也不应该用 === 之外的复杂判断。

---

## 带构造参数的枚举

枚举类可以有主构造器，每个常量在声明时传入自己的参数。

这适合把枚举常量和它的附加信息绑在一起，例如颜色对应的数值。

**实例**

```kotlin
// 主构造器带两个参数，每个常量各自传入不同的值
enum class RunoobColor(val rgb: Int, val hex: String) {
    RED(0xFF0000, "#FF0000"),
    GREEN(0x00FF00, "#00FF00"),
    BLUE(0x0000FF, "#0000FF")
}

fun main() {
    // entries 是 Kotlin 1.9 起推荐的遍历方式，后面会详细讲
    for (color in RunoobColor.entries) {
        println("${color.name} 的十进制值 ${color.rgb}，十六进制 ${color.hex}")
    }
}
```

```text
RED 的十进制值 16711680，十六进制 #FF0000
GREEN 的十进制值 65280，十六进制 #00FF00
BLUE 的十进制值 255，十六进制 #0000FF
```

枚举类的构造器永远是私有的，不允许写成 public，所以外部无法再创建新的常量。

这正是枚举「值集合固定」这一语义的来源。

---

## 匿名类与方法重写

每个枚举常量后面可以跟一对大括号，里面就是这个常量自己的类体。

在类体里可以重写抽象方法，也可以重写带默认实现的方法。

**实例**

```kotlin
enum class RunoobState {
    WAITING {
        override fun signal(): RunoobState = RUNNING
        override fun describe(): String = "等待中"
    },
    RUNNING {
        override fun signal(): RunoobState = WAITING
        override fun describe(): String = "运行中"
    };   // 有成员时，常量列表要用分号结束

    // 抽象方法：每个常量都必须实现
    abstract fun signal(): RunoobState

    // 带默认实现的方法：常量可以选择重写
    open fun describe(): String = "未知状态"
}

fun main() {
    println(RunoobState.WAITING.describe())
    println(RunoobState.WAITING.signal().describe())
}
```

```text
等待中
运行中
```

RunoobState.WAITING.signal() 返回的是 RUNNING，所以第二次打印的是「运行中」。

注意每个常量的类体末尾用逗号或分号与下一个常量分隔，写法与普通枚举常量一致。

---

## 成员与分号分隔

只要枚举类里定义了任何成员，常量列表后面就必须加分号。

这些成员包括普通函数、属性、伴生对象等。

**实例**

```kotlin
enum class RunoobLevel(val score: Int) {
    LOW(1), MID(5), HIGH(10);   // 分号把常量列表和成员分隔开

    // 普通成员函数
    fun isPass(): Boolean = score >= 5

    // 伴生对象也是成员，同样要写在分号之后
    companion object {
        fun fromScore(score: Int): RunoobLevel =
            entries.firstOrNull { it.score == score } ?: LOW
    }
}

fun main() {
    println(RunoobLevel.HIGH.isPass())
    println(RunoobLevel.LOW.isPass())
    println(RunoobLevel.fromScore(5))
}
```

```text
true
false
MID
```

如果枚举类里没有任何成员，末尾的分号可以省略。

---

## entries：Kotlin 1.9 起取代 values()

遍历枚举常量曾经用 values()，Kotlin 1.9 起推荐改用 entries。

values() 每次调用都会复制一个新数组，而 entries 返回的是一个只读列表视图，不会重复分配。

**实例**

```kotlin
enum class RunoobColor { RED, GREEN, BLUE }

fun main() {
    // Kotlin 1.9 起推荐：entries 返回只读的 EnumEntries
    println(RunoobColor.entries.joinToString())
    println(RunoobColor.entries.size)
    println(RunoobColor.entries[1])

    // 遍历并格式化输出
    println(RunoobColor.entries.joinToString(" ") { "${it.ordinal}-${it.name}" })
}
```

```text
RED, GREEN, BLUE
3
GREEN
0-RED 1-GREEN 2-BLUE
```

entries 是只读的，不支持 add 或 remove，这一点与 values() 返回的数组不同。

| 对比项 | values() | entries（Kotlin 1.9 起） |
| --- | --- | --- |
| 返回类型 | 数组 Array<T> | 只读列表 EnumEntries<T> |
| 每次调用 | 复制出一个新数组 | 返回同一个只读视图，不重复分配 |
| 能否增删 | 数组长度固定，元素可改 | 完全只读，不能增删改 |
| 转成数组 | 本身就是数组 | 需要时调用 toTypedArray() |
| 推荐程度 | 仍可用，属于旧写法 | Kotlin 1.9 起的推荐写法 |

**实例**

```kotlin
enum class RunoobColor { RED, GREEN, BLUE }

fun main() {
    // 旧写法：values() 每次调用都会创建一个新数组
    println(RunoobColor.values().joinToString())

    // 新写法（Kotlin 1.9 起）：entries 是只读列表视图，不分配数组
    println(RunoobColor.entries.joinToString())

    // 确实需要数组时，从 entries 转换
    val array: Array<RunoobColor> = RunoobColor.entries.toTypedArray()
    println(array.size)

    // Kotlin 1.9.20 起 enumValues() 已弃用，不要再使用
    // println(enumValues<RunoobColor>().joinToString())
}
```

```text
RED, GREEN, BLUE
RED, GREEN, BLUE
3
```

> **注意：**不要直接写 println(RunoobColor.values())，它打印出来的是数组的地址，形如 [LRunoobColor;@1b6d3586。要得到可读结果，请用 entries 或 joinToString()。

---

## name 与 ordinal

每个枚举常量都有 name 和 ordinal 两个属性。

name 是常量名，ordinal 是它在声明列表中的位置，从 0 开始。

**实例**

```kotlin
enum class RunoobColor { RED, GREEN, BLUE }

fun main() {
    val color = RunoobColor.GREEN
    println(color.name)      // 常量名
    println(color.ordinal)   // 从 0 开始的位置索引

    for (item in RunoobColor.entries) {
        println("${item.ordinal} -> ${item.name}")
    }
}
```

```text
GREEN
1
0 -> RED
1 -> GREEN
2 -> BLUE
```

name 是只读的，不能像 Java 那样重新赋值。

ordinal 依赖声明顺序，一旦调整常量顺序，历史数据里的 ordinal 就会错位，所以不要用它做持久化存储。

---

## valueOf 与 enumValueOf

需要按名字取枚举常量时，用 valueOf 或它的泛型版本 enumValueOf。

名字不存在会抛出 IllegalArgumentException，因此外部输入最好先做安全查找。

**实例**

```kotlin
enum class RunoobColor { RED, GREEN, BLUE }

fun main() {
    // valueOf：按名字取常量
    val red = RunoobColor.valueOf("RED")
    println(red == RunoobColor.RED)

    // enumValueOf：泛型版本，写法更通用
    val blue = enumValueOf<RunoobColor>("BLUE")
    println(blue.ordinal)

    // 安全查找：名字不存在时返回 null，避免抛异常
    val safe = RunoobColor.entries.firstOrNull { it.name == "PURPLE" }
    println(safe ?: "没有 PURPLE")
}
```

```text
true
2
没有 PURPLE
```

valueOf 区分大小写，写 "red" 会直接抛异常，这一点在解析用户输入时要特别注意。

---

## 与 when 配合

枚举与 when 是天然搭档，覆盖全部常量后就不需要 else。

**实例**

```kotlin
enum class RunoobColor { RED, GREEN, BLUE }

// 覆盖了所有常量，作为表达式时不需要 else
fun hex(color: RunoobColor): String = when (color) {
    RunoobColor.RED -> "#FF0000"
    RunoobColor.GREEN -> "#00FF00"
    RunoobColor.BLUE -> "#0000FF"
}

fun main() {
    println(hex(RunoobColor.RED))
    println(hex(RunoobColor.BLUE))
}
```

```text
#FF0000
#0000FF
```

Kotlin 1.6 起，对枚举主语的 when 语句如果分支不穷尽会给出警告；Kotlin 1.7 起改为错误。

新增枚举常量后，所有没处理它的 when 都会立刻报错，改动点一目了然。

---

## 常见问题

下面整理几个使用枚举类时容易遇到的问题。

### 为什么加了成员就编译不过

多半是忘了在常量列表末尾写分号。

只要枚举类里有函数、属性或伴生对象，分号就必须加上。

### values() 还能用吗

还能用，Kotlin 1.9 起推荐改用 entries，因为它不会重复分配数组。

Kotlin 1.9.20 起 enumValues() 已经弃用，新代码不要再调用。

### 枚举能继承其他类吗

不能，枚举类隐式继承了 Enum，因此只能实现接口，不能再继承别的类。

需要携带不同数据时，考虑改用密封类。

### 可以用 ordinal 存数据库吗

不建议，ordinal 完全依赖声明顺序，调整常量顺序就会导致历史数据错乱。

需要稳定标识时，自己定义一个 code 属性并显式赋值。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-enum-classes.html)，版权归原作者所有，仅供非商业学习使用。
