在 Kotlin 里，函数是一等公民（first‑class citizen）：可以赋值给变量、作为参数传递、作为返回值返回。

把函数当作数据来用，就引出了函数类型、Lambda 表达式和高阶函数这几个概念，它们也是 Kotlin 集合操作写法简洁的根本原因。

本章节从函数类型讲起，逐步过渡到 Lambda、闭包、函数引用与 SAM 转换。

---

## 函数类型

函数类型描述"接收什么参数、返回什么值"，写法是 `(参数类型) -> 返回类型`。

函数类型本身也是一种类型，所以可以声明变量、作为参数、作为返回值。

**实例**

```kotlin
// 文件路径：LambdaType.kt

// 接收两个 Int，返回 Int
val sum: (Int, Int) -> Int = { a, b -> a + b }

// 接收一个 String，返回 String
val greet: (String) -> String = { name -> "你好，$name" }

// 不接收参数，不返回有意义的值
val log: () -> Unit = { println("RUNOOB") }

// 整个函数类型的值可以为 null，要加一层括号
var callback: ((Int) -> Int)? = null

fun main() {
    println(sum(1, 2))
    println(greet("Runoob"))
    log()

    callback = { it * 2 }
    // callback 可能为 null，用安全调用 ?.invoke
    println(callback?.invoke(21))
}
```

```text
3
你好，Runoob
RUNOOB
42
```

函数类型里也可以给参数起名字，例如 `(x: Int, y: Int) -> Int`，这些名字只用于提示，不影响类型是否匹配。

还有一种带接收者的函数类型，写法是 `String.(Int) -> String`，表示这个函数要在 String 上调用，这正是扩展函数的函数类型形式。

**实例**

```kotlin
// 带接收者的函数类型：接收者是 String，参数是 Int，返回 String
val repeatFun: String.(Int) -> String = { times -> this.repeat(times) }

fun main() {
    // 既可以像扩展函数一样调用
    println("Run".repeatFun(2))

    // 也可以当作普通函数类型使用，此时接收者变成第一个参数
    val plain: (String, Int) -> String = repeatFun
    println(plain("RUNOOB", 2))
}
```

```text
RunRun
RUNOOBRUNOOB
```

---

## Lambda 表达式语法

Lambda 是一段可以传递的代码块，用花括号包围，参数在 `->` 左边，函数体在右边。

函数体最后一个表达式的值，就是 Lambda 的返回值。

**实例**

```kotlin
fun main() {
    // 完整写法：参数需要标类型时，类型写在参数名后面
    val sum = { a: Int, b: Int -> a + b }
    println(sum(3, 4))

    // 只有一个参数时可以省略参数声明，用隐式参数 it
    val double: (Int) -> Int = { it * 2 }
    println(double(5))

    // 没有参数的 Lambda
    val hello = { println("Hello, Runoob") }
    hello()

    // 多行 Lambda：最后一个表达式作为返回值
    val describe = { value: Int ->
        val text = if (value > 0) "正数" else "非正数"
        "结果是 $text"
    }
    println(describe(1))

    // 用不到的参数可以用下划线占位，Kotlin 1.1 起支持
    val second = { _: Int, value: Int -> value }
    println(second(1, 2))
}
```

```text
7
10
Hello, Runoob
结果是 正数
2
```

> **注意：**Lambda 的类型推断依赖上下文。像 `val f = { x -> x + 1 }` 这样既不写参数类型、上下文又没有明确目标类型时，编译器会报"无法推断参数类型"。解决办法是补上类型标注，或者把 Lambda 直接传给一个签名明确的函数。

---

## 高阶函数

接收函数作为参数，或者返回一个函数的函数，叫做高阶函数（higher-order function）。

它把"做什么"从"怎么做"里抽出来，让调用方决定具体行为。

**实例**

```kotlin
// 接收函数作为参数
fun calculate(a: Int, b: Int, operation: (Int, Int) -> Int): Int {
    return operation(a, b)
}

// 返回一个函数：返回类型是 (Int) -> Int
fun multiplier(factor: Int): (Int) -> Int {
    return { value -> value * factor }
}

fun main() {
    // 尾随 Lambda 写法：Lambda 写在括号外面
    println(calculate(6, 3) { a, b -> a + b })
    println(calculate(6, 3) { a, b -> a * b })

    // 先拿到函数，再调用
    val triple = multiplier(3)
    println(triple(5))

    // 直接调用返回的函数
    println(multiplier(10)(4))
}
```

```text
9
18
15
40
```

当函数的最后一个参数是函数类型时，可以把 Lambda 写在括号外面，这就是尾随 Lambda（trailing lambda）语法。

如果只有这一个参数，括号本身也可以省略，于是就有了 `list.forEach { ... }` 这种写法。

---

## 与集合结合：forEach、filter、map

集合库把高阶函数用到了极致，最常用的三个是 `forEach`、`filter` 和 `map`。

它们接收的 Lambda 决定了每个元素要做什么，返回的是新集合而不是修改原集合。

**实例**

```kotlin
fun main() {
    val sites = listOf("runoob", "RUNOOB", "java", "kotlin")

    // forEach：对每个元素执行一段代码，返回 Unit
    sites.forEach { println(it) }

    println("---")

    // filter：保留让 Lambda 返回 true 的元素，得到新列表
    val upper = sites.filter { it == it.uppercase() }
    println(upper)

    // map：把每个元素转换成另一个值，得到新列表
    val lengths = sites.map { it.length }
    println(lengths)

    // 链式调用：先过滤再转换
    val result = sites
        .filter { it.startsWith("r", ignoreCase = true) }
        .map { it.uppercase() }
    println(result)
}
```

```text
runoob
RUNOOB
java
kotlin
---
[RUNOOB]
[6, 6, 4, 6]
[RUNOOB, RUNOOB]
```

`forEach` 是内联函数，`filter` 和 `map` 同样接收内联的 Lambda，所以这些操作不会为 Lambda 额外创建对象。

需要下标时用 `forEachIndexed`，需要同时拿到键和值时可以对 Map 使用解构。

**实例**

```kotlin
fun main() {
    val sites = listOf("Runoob", "www.runoob.com")

    // forEachIndexed 的 Lambda 接收 (index, value)
    sites.forEachIndexed { index, value ->
        println("$index -> $value")
    }

    // Map 的 forEach 可以直接解构出键和值
    val info = mapOf("name" to "Runoob", "site" to "www.runoob.com")
    info.forEach { (key, value) ->
        println("$key = $value")
    }
}
```

```text
0 -> Runoob
1 -> www.runoob.com
name = Runoob
site = www.runoob.com
```

---

## 闭包与变量捕获

Lambda 可以访问定义它时所在作用域的变量，这种结构叫闭包（closure）。

Kotlin 允许捕获的变量是 var，也允许在 Lambda 内部修改它。

**实例**

```kotlin
fun main() {
    var counter = 0

    // 捕获外部的局部变量 counter，并且修改它
    val increment = { counter++ }

    increment()
    increment()
    println("counter = $counter")

    // 每次调用 makeCounter 都会创建一个独立的闭包
    val c1 = makeCounter()
    val c2 = makeCounter()

    c1()
    c1()
    c2()
    println("c1 = ${c1()}, c2 = ${c2()}")
}

// 返回一个函数，函数内部持有自己的 count
fun makeCounter(): () -> Int {
    var count = 0
    return {
        count++
        count      // 最后一个表达式的值作为返回值
    }
}
```

```text
counter = 2
c1 = 3, c2 = 2
```

两个闭包各自持有一份 `count`，互不影响，这是闭包最典型的用途：把状态封装在函数内部。

---

## 匿名函数

Lambda 不是唯一的函数字面量，还可以用 `fun` 关键字定义没有名字的匿名函数。

匿名函数里的 `return` 只从匿名函数自身返回，不会影响外层函数，这一点和 Lambda 不同。

**实例**

```kotlin
fun main() {
    // 匿名函数：有参数类型和返回类型，用 fun 开头
    val sum = fun(a: Int, b: Int): Int {
        return a + b        // 从匿名函数自身返回
    }
    println(sum(2, 3))

    // 匿名函数也可以用表达式体
    val square = fun(x: Int) = x * x
    println(square(6))

    // 传给高阶函数时，匿名函数里的 return 不会从 main 返回
    listOf(1, 2, 3, 4).forEach(fun(value) {
        if (value == 3) return   // 只结束这一次匿名函数调用
        println(value)
    })
    println("结束")
}
```

```text
5
36
1
2
4
结束
```

匿名函数的另一个特点是返回类型可以显式写出，需要明确控制返回值类型时比 Lambda 更直观。

---

## 函数引用 ::

如果函数已经有名字，可以用 `::` 把它变成函数类型的值，不必再包一层 Lambda。

函数引用分为顶层函数引用、绑定引用（已经绑定到实例）和未绑定引用（需要传入接收者）三种。

**实例**

```kotlin
// 顶层函数
fun isEven(value: Int) = value % 2 == 0

class Site(val name: String) {
    fun hello() = "你好，$name"
}

fun main() {
    val numbers = listOf(1, 2, 3, 4)

    // ::isEven 等价于 { value -> isEven(value) }
    println(numbers.filter(::isEven))

    val site = Site("Runoob")

    // 绑定引用：已经绑定到 site 实例，调用时不用再传接收者
    val bound = site::hello
    println(bound())

    // 未绑定引用：调用时需要把接收者作为第一个参数传入
    val unbound: (Site) -> String = Site::hello
    println(unbound(site))
}
```

```text
[2, 4]
你好，Runoob
你好，Runoob
```

当存在多个同名重载函数时，编译器会根据函数类型的目标类型来选择匹配的那个引用。

---

## 构造器引用与绑定引用

构造函数也可以被引用，写法是 `::类名`，它产生一个返回该类实例的函数。

重载的构造函数同样由目标类型决定选哪一个。

**实例**

```kotlin
class Site(val name: String, val url: String)

fun main() {
    // 构造器引用 ::Site 相当于一个 (String, String) -> Site 的函数
    val create: (String, String) -> Site = ::Site
    val runoob = create("Runoob", "www.runoob.com")
    println("${runoob.name} - ${runoob.url}")

    // 在需要函数的地方直接使用构造器引用
    val pairs = listOf("Runoob" to "www.runoob.com", "RUNOOB" to "kotlin.runoob.com")
    val sites = pairs.map { (name, url) -> create(name, url) }
    println(sites.map { it.name })
}
```

```text
Runoob - www.runoob.com
[Runoob, RUNOOB]
```

上面的 `create` 已经是一个函数类型的值，可以像普通函数一样在 `map` 里调用。

绑定引用除了成员函数，也可以引用属性，例如 `site::name` 会得到一个取值函数。

---

## SAM 转换

SAM 是 Single Abstract Method 的缩写，指只有一个抽象方法的接口。

Kotlin 允许把 Lambda 直接转换成这类接口的实例，这就是 SAM 转换。

**实例**

```kotlin
// Kotlin 的函数式接口：用 fun interface 声明，Kotlin 1.4 起稳定
fun interface StringChecker {
    fun check(value: String): Boolean
}

fun main() {
    // Lambda 自动转换为函数式接口的实例
    val notEmpty = StringChecker { it.isNotEmpty() }
    println(notEmpty.check("Runoob"))
    println(notEmpty.check(""))

    // 与 Java 函数式接口互操作：Runnable 只有一个抽象方法 run()
    val task = Runnable { println("在 Java 线程接口里运行 RUNOOB") }
    task.run()
}
```

```text
true
false
在 Java 线程接口里运行 RUNOOB
```

Kotlin 1.4 起，用 `fun interface` 声明的 Kotlin 接口也支持 SAM 转换；在此之前，SAM 转换只对 Java 接口有效。

普通（非函数式）接口即使只有一个方法，也不能用 Lambda 转换，必须写对象表达式。

---

## 常见问题

下面整理几个关于 Lambda 的常见疑问。

| 问题 | 说明 |
| --- | --- |
| Lambda 里的 return 从哪返回 | 传给内联函数时从外层函数返回（非局部返回）；用 `return@标签` 则只结束 Lambda |
| filter 和 map 会修改原集合吗 | 不会，它们返回新列表，原集合保持不变 |
| it 什么时候能用 | 只有一个参数时可以省略参数声明，多参数必须自己写参数名 |
| 函数引用和 Lambda 怎么选 | 已有命名函数时优先用 `::`，需要额外逻辑时用 Lambda |
| SAM 转换能用于任何接口吗 | 不能，接口必须只有一个抽象方法，Kotlin 接口还要用 fun interface 声明 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-lambda.html)，版权归原作者所有，仅供非商业学习使用。
