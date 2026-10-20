数据类专门用来保存数据，只要在 class 前面加上 data，编译器就会自动生成一组常用方法。

这些方法包括 equals、hashCode、toString、componentN 和 copy，省去大量重复代码。

配合解构声明，还能把对象里的属性一次性拆到多个变量中。

---

## 定义一个数据类

数据类的写法很简单，主构造器里至少要有一个参数，并且参数都要标上 val 或 var。

**实例**

```kotlin
// data 关键字写在 class 之前
data class RunoobSite(val name: String, val url: String, val age: Int)

fun main() {
    val site = RunoobSite("菜鸟教程", "www.runoob.com", 12)

    println(site)      // 自动生成的 toString()
    println(site.name) // 属性照常访问

    val same = RunoobSite("菜鸟教程", "www.runoob.com", 12)
    println(site == same)                              // 自动生成的 equals()
    println(site.hashCode() == same.hashCode())        // 自动生成的 hashCode()
}
```

```text
RunoobSite(name=菜鸟教程, url=www.runoob.com, age=12)
菜鸟教程
true
true
```

如果用普通 class 写同样的内容，这些方法都得自己实现，非常啰嗦。

---

## 自动生成的成员

data class 生成的方法都有固定的语义，下面这张表可以当作速查。

| 成员 | 签名 | 作用 |
| --- | --- | --- |
| equals() | equals(other: Any?): Boolean | 按主构造器属性逐个比较 |
| hashCode() | hashCode(): Int | 与 equals 保持一致，保证放进散列表时行为正确 |
| toString() | toString(): String | 输出「类名(属性=值, 属性=值)」 |
| componentN() | component1()、component2() 等 | 支持解构声明，顺序与主构造器参数一致 |
| copy() | copy(...): 类名 | 复制出一个新对象，可以只改其中几个属性 |

只有主构造器里的属性会参与 equals、hashCode、toString 和 componentN。

写在类体里的属性不参与这些方法的生成。

---

## 生成条件

并不是随便加个 data 就能变成数据类，下面几条必须同时满足。

| 条件 | 说明 | 反例 |
| --- | --- | --- |
| 主构造器至少一个参数 | 没有参数无法生成有意义的方法 | data class Empty() |
| 参数必须标 val 或 var | 否则参数不是属性，无法参与生成 | data class User(name: String) |
| 不能是 abstract | 抽象类无法实例化 | abstract data class A(val id: Int) |
| 不能是 open | 数据类本身是 final | open data class B(val id: Int) |
| 不能是 sealed | 密封类属于另一套体系 | sealed data class C(val id: Int) |
| 不能是 inner | 内部类无法作为数据类 | inner data class D(val id: Int) |

**实例**

```kotlin
// 正确：主构造器至少一个参数，且都是 val / var
data class RunoobA(val id: Int)

// 错误：主构造器没有参数
// data class RunoobB()   // Data class must have at least one primary constructor parameter

// 错误：参数没有 val / var，只是一个普通形参
// data class RunoobC(name: String)

// 错误：不能是 abstract / open / sealed / inner
// abstract data class RunoobD(val id: Int)
// open data class RunoobE(val id: Int)

fun main() {
    println(RunoobA(1))
}
```

```text
RunoobA(id=1)
```

数据类可以实现接口，但本身是 final 的，不能再被继承。

它也可以带类体，在类体里定义额外的函数和属性。

---

## copy() 与部分修改

数据类适合存放不可变数据，修改某个字段时通常用 copy 生成一个新对象，而不是改原对象。

copy 的每个参数都有默认值，默认取原对象对应的属性，因此可以只写要改的那几个。

**实例**

```kotlin
data class RunoobSite(val name: String, val url: String, val age: Int)

fun main() {
    val site = RunoobSite("菜鸟教程", "www.runoob.com", 12)

    // 只改 url，其余字段保持原值
    val mirror = site.copy(url = "m.runoob.com")
    println(mirror)

    // 一次改多个字段
    val renamed = site.copy(name = "RUNOOB 教程", age = 13)
    println(renamed)

    // 不传任何参数 = 浅拷贝一个新对象
    val same = site.copy()
    println(same == site)    // 属性相同，结构相等
    println(same === site)   // 但不是同一个对象
}
```

```text
RunoobSite(name=菜鸟教程, url=m.runoob.com, age=12)
RunoobSite(name=RUNOOB 教程, url=www.runoob.com, age=13)
true
false
```

copy 是浅拷贝，对象里的引用类型字段仍然指向同一个实例。

---

## 解构声明

数据类会自动生成 component1、component2 等函数，因此可以把对象拆成多个变量。

变量的顺序对应主构造器参数的顺序，不是属性在类体里的书写顺序。

**实例**

```kotlin
data class RunoobSite(val name: String, val url: String, val age: Int)

fun main() {
    val site = RunoobSite("菜鸟教程", "www.runoob.com", 12)

    // 按主构造器参数顺序解构
    val (name, url, age) = site
    println("名称：$name，网址：$url，年龄：$age")

    // 只关心其中一个字段，其余用下划线占位（Kotlin 1.1 起）
    val (_, siteUrl, _) = site
    println("只要网址：$siteUrl")

    // 遍历 Map 时同样使用解构
    val scores = mapOf("runoob" to 95, "RUNOOB" to 88)
    for ((key, value) in scores) {
        println("$key -> $value")
    }
}
```

```text
名称：菜鸟教程，网址：www.runoob.com，年龄：12
只要网址：www.runoob.com
runoob -> 95
RUNOOB -> 88
```

普通类只要自己声明 componentN 运算符函数，也能支持解构。

**实例**

```kotlin
class RunoobPoint(val x: Int, val y: Int) {
    // 手动声明 componentN，让普通类也支持解构
    operator fun component1() = x
    operator fun component2() = y
}

fun main() {
    val (x, y) = RunoobPoint(3, 4)
    println("x=$x, y=$y")
}
```

```text
x=3, y=4
```

> **注意：**解构中的下划线占位符从 Kotlin 1.1 开始支持。老版本里如果想跳过某个位置，只能给它取个用不到的名字。

---

## 数据类的相等性

数据类的 equals 只比较主构造器属性，类体里的属性不参与。

这意味着两个对象可能相等，但它们的类体属性并不相同。

**实例**

```kotlin
data class RunoobUser(val name: String) {
    var city: String = "北京"   // 类体属性，不参与 equals / hashCode
}

fun main() {
    val a = RunoobUser("runoob")
    val b = RunoobUser("runoob")
    a.city = "上海"
    b.city = "广州"

    println(a == b)            // 只比较 name，所以是 true
    println(a.city == b.city)  // 类体属性单独比较，false
}
```

```text
true
false
```

这也提醒我们：需要参与相等性判断的字段，都应该放进主构造器。

---

## Pair 与 Triple

标准库提供了两个现成的数据类，用来临时组合两到三个值。

Pair 表示两个值，Triple 表示三个值，它们都支持解构和 copy。

**实例**

```kotlin
fun main() {
    // to 是中缀函数，等价于 Pair("runoob", 95)
    val score: Pair<String, Int> = "runoob" to 95
    println(score.first)    // 第一个值
    println(score.second)   // 第二个值

    // 解构 Pair
    val (name, value) = score
    println("$name 的分数是 $value")

    // Triple 表示三个值
    val info = Triple("RUNOOB", "www.runoob.com", 2026)
    val (site, url, year) = info
    println("$site - $url - $year")

    // Pair 也是数据类，同样有 copy
    println(score.copy(second = 100))
}
```

```text
runoob
95
runoob 的分数是 95
RUNOOB - www.runoob.com - 2026
(runoob, 100)
```

Pair 和 Triple 适合函数临时返回多个值，字段含义不明确时建议改用自定义数据类。

---

## data object（Kotlin 1.9 起）

普通 object 打印出来是一串对象地址，data object 会自动生成有意义的 toString。

Kotlin 1.9 起可以用 data object 声明单例，它还会生成 equals 和 hashCode。

**实例**

```kotlin
// Kotlin 1.9 起：data object 自动生成 toString / equals / hashCode
data object RunoobConfig {
    val siteName: String = "RUNOOB"
}

fun main() {
    println(RunoobConfig)                    // 输出对象名，而不是地址
    println(RunoobConfig == RunoobConfig)    // 单例，永远相等
    println(RunoobConfig.siteName)
}
```

```text
RunoobConfig
true
RUNOOB
```

data object 最常见的用途是放在密封类层次里表示没有数据的分支。

**实例**

```kotlin
sealed interface RunoobState {
    data object Loading : RunoobState                        // 无数据的单例分支
    data object Empty : RunoobState                          // 无数据的单例分支
    data class Success(val data: String) : RunoobState       // 带数据的分支
}

fun describe(state: RunoobState): String = when (state) {
    RunoobState.Loading -> "加载中"
    RunoobState.Empty -> "暂无数据"
    is RunoobState.Success -> "成功：${state.data}"
}

fun main() {
    println(describe(RunoobState.Loading))
    println(describe(RunoobState.Empty))
    println(describe(RunoobState.Success("www.runoob.com")))
}
```

```text
加载中
暂无数据
成功：www.runoob.com
```

---

## 常见问题

下面整理几个使用数据类时容易遇到的问题。

### 为什么改完属性没有生效

数据类的属性通常声明为 val，本身不可修改，正确做法是用 copy 生成新对象。

如果确实需要可变属性，把它写成 var，但要留意它仍然会参与 equals 和 hashCode。

### 类体里的属性为什么不参与比较

这是编译器的约定：只有主构造器参数才会生成到 equals、hashCode 和 toString 中。

需要比较的字段就放进主构造器，不要放在类体里。

### copy 之后两个对象共享内部对象怎么办

copy 只复制引用，不复制引用指向的对象，所以是浅拷贝。

如果内部有可变集合，需要自己手动深拷贝一份。

### Pair 和自定义数据类怎么选

只在函数内部临时返回两三个值，用 Pair 或 Triple 更省事。

一旦这些值会跨越模块传递，或者需要明确的字段名，就换成自定义数据类。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-data-class.html)，版权归原作者所有，仅供非商业学习使用。
