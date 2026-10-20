泛型就是「参数化类型」，把类型也当成参数来使用。

有了泛型，同一个类或函数就能安全地处理多种类型的数据，同时把类型检查交给编译器完成。

Kotlin 的泛型与 Java 类似，但用声明处型变取代了通配符，写法更统一，用起来也更安全。

---

## 泛型类

在类名后面加一对尖括号声明类型参数，这个参数就可以在类的属性和方法里当类型使用。

**实例**

```kotlin
// T 是类型参数，创建实例时再确定它具体是什么类型
class Box<T>(t: T) {
    var value = t
}

fun main() {
    val boxInt = Box<Int>(10)          // 显式指定 T 为 Int
    val boxString = Box("RUNOOB")      // 省略类型参数，编译器推断为 Box<String>
    println(boxInt.value)
    println(boxString.value)
}
```

输出结果为：

```text
10
RUNOOB
```

类型参数可以声明多个，也可以给它加约束，这些内容后面几节会展开。

---

## 泛型函数

泛型函数的类型参数写在 `fun` 关键字和函数名之间。

**实例**

```kotlin
class Box<T>(t: T) {
    var value = t
}

// 类型参数 T 放在 fun 和函数名之间
fun <T> boxIn(value: T) = Box(value)

fun main() {
    val box1 = boxIn<Int>(1)        // 显式指定类型参数
    val box2 = boxIn("runoob")      // 编译器推断类型参数
    println(box1.value)
    println(box2.value)
}
```

输出结果为：

```text
1
runoob
```

泛型函数内部可以用 `is` 对参数做类型判断，从而针对不同类型走不同分支。

**实例**

```kotlin
fun main() {
    val age = 23
    val name = "runoob"
    val bool = true

    doPrintln(age)      // 推断为 doPrintln<Int>
    doPrintln(name)     // 推断为 doPrintln<String>
    doPrintln(bool)     // 推断为 doPrintln<Boolean>
}

fun <T> doPrintln(content: T) {
    when (content) {
        is Int -> println("整型数字为 $content")
        // uppercase() 在 Kotlin 1.5 起取代了已弃用的 toUpperCase()
        is String -> println("字符串转换为大写：${content.uppercase()}")
        else -> println("T 不是整型，也不是字符串")
    }
}
```

输出结果为：

```text
整型数字为 23
字符串转换为大写：RUNOOB
T 不是整型，也不是字符串
```

---

## 类型推断

Kotlin 编译器会尽量从参数和返回值中推断出类型参数，能推断出来时就可以省略尖括号里的内容。

推断不出来时才需要显式写出来，比如参数位置无法提供类型信息，或者你想要一个更宽泛的类型。

**实例**

```kotlin
// 没有参数可以推断 T，只能靠赋值目标或显式指定来确定
fun <T> nothing(): T? = null

fun main() {
    val inferred = listOf("runoob", "kotlin")        // 推断为 List<String>
    val explicit: List<Any> = listOf("runoob", 42)   // 由声明类型推断为 List<Any>
    val empty: String? = nothing()                   // 由赋值目标推断 T 为 String
    println(inferred)
    println(explicit)
    println(empty)
}
```

输出结果为：

```text
[runoob, kotlin]
[runoob, 42]
null
```

> **注意：**类型参数只在编译期存在，运行时会做类型擦除。`List<Int>` 和 `List<String>` 在运行时是同一个类，因此不能直接写 `value is T`，需要配合 `reified` 才行，这一点在本章节最后一节会说明。

---

## 泛型约束

约束用来限定类型参数允许的取值范围，写法是在类型参数后面加冒号和上界。

### 上界约束

最常见的约束是上界，表示 `T` 必须是某个类型的子类型。

**实例**

```kotlin
// T 必须是 Comparable<T> 的子类型，这样才能比较大小
fun <T : Comparable<T>> sort(list: List<T>): List<T> = list.sorted()

fun main() {
    println(sort(listOf(3, 1, 2)))
    println(sort(listOf("runoob", "kotlin", "www.runoob.com")))
}
```

输出结果为：

```text
[1, 2, 3]
[kotlin, runoob, www.runoob.com]
```

如果把一个不满足约束的类型传进去，编译期就会直接报错。

例如 `HashMap<Int, String>` 不是 `Comparable<HashMap<Int, String>>` 的子类型，所以 `sort(listOf(HashMap<Int, String>()))` 无法通过编译。

### 默认上界 Any?

不写约束时，类型参数的默认上界是 `Any?`，也就是说 T 允许是可空类型。

**实例**

```kotlin
// 没有写约束，上界默认为 Any?，因此 T 可以取可空类型
fun <T> echo(value: T): String = "收到：$value"

fun main() {
    println(echo("runoob"))
    println(echo(42))
    println(echo<String?>(null))   // 显式指定 T 为 String?
}
```

输出结果为：

```text
收到：runoob
收到：42
收到：null
```

如果希望类型参数必须是非空的，把上界写成 `Any` 即可，此时 `echo<String?>(null)` 会编译失败。

### where 多约束

需要同时满足多个上界时，用 `where` 子句把它们并列写出。

**实例**

```kotlin
// T 同时满足两个约束：是 CharSequence 的子类型，且可比较
fun <T> copyWhenGreater(list: List<T>, threshold: T): List<String>
        where T : CharSequence,
              T : Comparable<T> {
    return list.filter { it > threshold }.map { it.toString() }
}

fun main() {
    val list = listOf("runoob", "kotlin", "www.runoob.com")
    println(copyWhenGreater(list, "kotlin"))
}
```

输出结果为：

```text
[runoob, www.runoob.com]
```

---

## 型变

型变解决的是「`Box<String>` 能不能当作 `Box<Any>` 用」这类问题。

![声明处型变方向对照图：class Producer 用 out T 时箭头从类向外，class Consumer 用 in T 时箭头从外向内](images/kotlin/kotlin-generics/22-variance.svg)

Kotlin 没有 Java 那样的通配符类型，它提供两种手段：声明处型变和使用处型变。

### 声明处型变 out 与 in

在类型参数上加 `out` 表示协变，它只能出现在输出位置，也就是作为返回值。

**实例**

```kotlin
// out A：A 只作为返回值出现，因此 Producer<String> 可以赋给 Producer<Any>
class Producer<out A>(private val value: A) {
    fun get(): A = value
}

fun main() {
    val strProducer: Producer<String> = Producer("RUNOOB")
    val anyProducer: Producer<Any> = strProducer   // 协变：子类型赋给父类型
    println(anyProducer.get())
}
```

输出结果为：

```text
RUNOOB
```

在类型参数上加 `in` 表示逆变，它只能出现在输入位置，也就是作为参数。

**实例**

```kotlin
// in A：A 只作为参数出现，因此 Consumer<Any> 可以赋给 Consumer<String>
class Consumer<in A> {
    fun consume(value: A) {
        println("消费：$value")
    }
}

fun main() {
    val anyConsumer: Consumer<Any> = Consumer<Any>()
    val strConsumer: Consumer<String> = anyConsumer   // 逆变：父类型赋给子类型
    strConsumer.consume("runoob")
}
```

输出结果为：

```text
消费：runoob
```

一句话记忆：生产者用 `out`，消费者用 `in`。

加了 `out` 的参数如果被用作参数类型，或者加了 `in` 的参数被用作返回类型，编译器都会报错。

### 使用处型变（类型投影）

有些类型不由你定义，没法在声明处加修饰符，这时可以在使用的地方做类型投影。

**实例**

```kotlin
// Array 是不变的，Array<String> 不能直接当作 Array<Any>
// 参数写成 Array<out Any> 后就可以接收任意元素为 Any 子类型的数组
fun copy(from: Array<out Any>, to: Array<Any>) {
    for (i in from.indices) {
        to[i] = from[i]
    }
}

fun main() {
    val src = arrayOf("runoob", "kotlin")   // Array<String>
    val dst = Array<Any>(2) { "" }          // Array<Any>
    copy(src, dst)
    println(dst.joinToString())
}
```

输出结果为：

```text
runoob, kotlin
```

反过来，如果某个参数只用于写入，可以投影为 `in`，表示可以接收更宽泛的类型。

---

## 星号投射

当你完全不关心类型参数是什么，只希望安全地使用这个泛型类型时，可以用星号投射 `*`。

星号投射可以理解为一种「只读或只写的安全投影」，它的具体含义由类型参数的型变决定。

| 类型声明 | Foo<*> 等价于 | 能否安全读取 | 能否安全写入 |
| --- | --- | --- | --- |
| `class Foo<out T : TUpper>` | `Foo<out TUpper>` | 可以读出 TUpper 类型的值 | 不能写入 |
| `class Foo<in T>` | `Foo<in Nothing>` | 没有可安全读出的值 | 不能写入任何值 |
| `class Foo<T : TUpper>` | 读：`Foo<out TUpper>`；写：`Foo<in Nothing>` | 可以读出 TUpper 类型的值 | 不能写入 |

用起来最常见的场景是 `List<*>`，它表示一个元素类型未知的只读列表，遍历读取是安全的。

**实例**

```kotlin
// 接收任意元素类型的只读列表
fun printAll(list: List<*>) {
    for (item in list) {
        println(item)
    }
}

fun main() {
    printAll(listOf(1, 2, 3))
    printAll(listOf("runoob", "kotlin"))
}
```

输出结果为：

```text
1
2
3
runoob
kotlin
```

如果一个泛型类型有多个类型参数，每个参数都可以单独投射。

以标准库的 `Function1<in P1, out R>` 为例，`Function1<*, String>` 等价于 `Function1<in Nothing, String>`，`Function1<Int, *>` 等价于 `Function1<Int, out Any?>`，而 `Function1<*, *>` 等价于 `Function1<in Nothing, out Any?>`。

> **注意：**星号投射与 Java 的原生类型看起来很像，但星号投射是安全的，编译器会阻止你把值写进去；而 Java 的原生类型会绕过类型检查。另外，`MutableList<*>` 只能读出 `Any?`，调用 `add` 会编译失败，因为编译器无法确定应该写入什么类型。

---

## 泛型与 reified

普通泛型在运行时会被类型擦除，无法直接做 `is T` 判断或调用 `T::class`。

把函数声明为 `inline` 并给类型参数加 `reified`，编译器就会把类型实参直接内联进代码，从而保留类型信息。

**实例**

```kotlin
// reified 只能用在 inline 函数的类型参数上
inline fun <reified T> typeName(): String = T::class.simpleName ?: "未知"

inline fun <reified T> isType(value: Any): Boolean = value is T

fun main() {
    println(typeName<String>())
    println(typeName<Int>())
    println(isType<String>("RUNOOB"))
    println(isType<Int>("RUNOOB"))
}
```

输出结果为：

```text
String
Int
true
false
```

标准库里的 `filterIsInstance<T>()` 就是靠 `reified` 实现的，它能在运行时按类型过滤集合元素。

**实例**

```kotlin
fun main() {
    val mixed: List<Any> = listOf("runoob", 42, "kotlin", 3.14)
    val strings = mixed.filterIsInstance<String>()
    println(strings)
}
```

输出结果为：

```text
[runoob, kotlin]
```

> **注意：**`reified` 的代价是函数必须内联，代码会被复制到每个调用处，体积会变大。它从 Kotlin 1.0 起就可用，但不是所有场景都适合，只在确实需要运行时类型信息时才使用。

---

## 常见问题

下面整理泛型使用中最常见的几个问题。

| 问题 | 原因 | 解决办法 |
| --- | --- | --- |
| 运行时无法判断 `value is T` | 泛型会被类型擦除 | 给 `inline` 函数的类型参数加 `reified` |
| `Array<String>` 不能传给 `Array<Any>` | 数组是不变的 | 参数声明为 `Array<out Any>` 做类型投影 |
| 加了 `out` 后方法参数报错 | 协变类型参数不能出现在输入位置 | 去掉 `out`，或改用使用处投影 |
| 传 null 给泛型函数报错 | 上界被限制为非空类型 | 把上界放宽为 `Any?` 或显式指定可空类型参数 |
| `MutableList<*>` 无法调用 `add` | 编译器不知道应该写入什么类型 | 改用具体类型，或改成只读的 `List<*>` |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-generics.html)，版权归原作者所有，仅供非商业学习使用。
