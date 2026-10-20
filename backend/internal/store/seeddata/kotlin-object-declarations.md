Kotlin 用 `object` 关键字把「创建对象」和「声明类」两件事合在了一起。

对象表达式用来在代码现场创建一个对某个类做了轻微改动的匿名对象，不需要为它单独声明一个子类。

对象声明则用来声明一个全局唯一的对象，也就是设计模式中的单例。

两者语法相似，语义却完全不同，本章节会把它们的区别讲清楚。

---

## 对象表达式

对象表达式写作 `object : 超类型 { ... }`，它在你写下这行代码的位置立即创建并执行一个匿名对象。

最常见的用途是实现一个接口，然后把对象直接交给某个方法使用。

**实例**

```kotlin
// 定义一个接口
interface Greeter {
    fun greet(): String
}

fun main() {
    // object : Greeter 表示创建一个实现了 Greeter 接口的匿名对象
    val runoob = object : Greeter {
        override fun greet() = "Hello, RUNOOB"
    }
    println(runoob.greet())
}
```

输出结果为：

```text
Hello, RUNOOB
```

对象表达式可以同时继承一个类并实现多个接口，多个超类型之间用逗号分隔。

如果超类型带有构造器，必须把构造参数传给它。

**实例**

```kotlin
open class A(x: Int) {
    open val y: Int = x
}

interface B {
    fun hello(): String
}

fun main() {
    // 同时继承 A(1) 并实现 B，A 的构造参数 1 必须显式传入
    val ab = object : A(1), B {
        override val y = 15
        override fun hello() = "菜鸟教程"
    }
    println(ab.y)
    println(ab.hello())
}
```

输出结果为：

```text
15
菜鸟教程
```

如果只是想要一个带几个字段的临时对象，可以连超类型都不写，直接用 `object { ... }`。

**实例**

```kotlin
fun main() {
    // 没有任何超类型，直接得到一个匿名对象
    val site = object {
        var name: String = "菜鸟教程"
        var url: String = "www.runoob.com"
    }
    println(site.name)
    println(site.url)
}
```

输出结果为：

```text
菜鸟教程
www.runoob.com
```

对象表达式内部可以直接读写外层作用域里的变量，这一点在事件回调中非常实用。

**实例**

```kotlin
interface ClickListener {
    fun onClick()
}

fun countClicks(listener: ClickListener) {
    listener.onClick()
}

fun main() {
    var clickCount = 0
    // 匿名对象捕获了外层的 clickCount 变量
    val listener = object : ClickListener {
        override fun onClick() {
            clickCount++
            println("被点击了 $clickCount 次")
        }
    }
    countClicks(listener)
    countClicks(listener)
}
```

输出结果为：

```text
被点击了 1 次
被点击了 2 次
```

### 匿名对象作为公有返回类型的陷阱

匿名对象可以用作局部变量或私有声明的类型，此时编译器能看见它的真实类型，匿名对象里新增的成员可以正常访问。

但如果你把匿名对象当作公有函数的返回类型或公有属性的类型，它的真实类型就会退化为声明的超类型，没有声明超类型时就退化为 `Any`。

**实例**

```kotlin
class C {
    // 私有函数：返回类型就是匿名对象的真实类型
    private fun foo() = object {
        val x: String = "RUNOOB"
    }

    // 公有函数：返回类型退化为 Any
    fun publicFoo() = object {
        val x: String = "RUNOOB"
    }

    fun bar() {
        val x1 = foo().x          // 可以访问
        println(x1)
        // val x2 = publicFoo().x // 编译错误：Any 上没有成员 x
    }
}

fun main() {
    C().bar()
}
```

输出结果为：

```text
RUNOOB
```

> **注意：**匿名对象只在本地作用域和私有作用域中才能保留自己的完整类型。一旦出现在公有 API 的返回类型上，新增成员就再也访问不到了，这正是很多初学者遇到「未解析的引用」报错的原因。需要对外暴露额外成员时，请为它单独声明一个具名类或接口。

---

## 对象声明

把 `object` 写在顶层或类内部，后面直接跟对象名，这就是对象声明。

对象声明不是表达式，不能出现在赋值号右边，它声明的是一个唯一的实例，因此天然就是单例。

**实例**

```kotlin
// 对象声明：全局唯一的单例
object Site {
    var url: String = ""
    val name: String = "菜鸟教程"
}

fun main() {
    val s1 = Site
    val s2 = Site
    s1.url = "www.runoob.com"
    println(s1.url)
    println(s2.url)
    println(s1 === s2)   // 两者是同一个实例
}
```

输出结果为：

```text
www.runoob.com
www.runoob.com
true
```

对象声明也可以继承类或实现接口，这时它就是一个有超类型的单例。

**实例**

```kotlin
interface Formatter {
    fun format(value: String): String
}

// 对象声明实现接口，可以直接通过对象名使用
object UpperFormatter : Formatter {
    override fun format(value: String) = value.uppercase()
}

fun main() {
    println(UpperFormatter.format("runoob"))
}
```

输出结果为：

```text
RUNOOB
```

### 嵌套在类内部的对象声明

对象声明写在另一个类内部时，它不会持有外部类的实例。

因此它既不能访问外部类的实例成员，也不能通过外部类的实例来访问，只能用外部类名加点号访问。

**实例**

```kotlin
class Site {
    var name = "菜鸟教程"

    object DeskTop {
        var url = "www.runoob.com"
        // fun showName() = name  // 编译错误：不能访问外部类的实例成员
    }
}

fun main() {
    println(Site.DeskTop.url)   // 只能用类名访问
}
```

输出结果为：

```text
www.runoob.com
```

> **注意：**对象声明不允许写在函数内部。如果需要在函数体内现场创建对象，请改用对象表达式。另外，Kotlin 1.9 起还支持 `data object`，它会在 `toString()`、`equals()` 上给出更符合数据语义的实现。

---

## 伴生对象

用 `companion` 标记的类内部对象叫伴生对象，它与外部类绑定，可以用外部类名直接访问其成员。

伴生对象看起来像其他语言的静态成员，但运行时它仍然是一个真实对象的实例成员。

**实例**

```kotlin
class MyClass {
    // 具名伴生对象，名字叫 Factory
    companion object Factory {
        fun create(): MyClass = MyClass()
    }
}

fun main() {
    val instance = MyClass.create()          // 直接用类名调用
    println(instance is MyClass)
    println(MyClass.Factory.create() is MyClass)   // 也可以用伴生对象的名字调用
}
```

输出结果为：

```text
true
true
```

伴生对象的名字可以省略，省略后用默认名 `Companion` 引用。

**实例**

```kotlin
class MyClass {
    companion object {
        const val SITE = "www.runoob.com"
    }
}

fun main() {
    val companion = MyClass.Companion
    println(companion.SITE)
    println(MyClass.SITE)
}
```

输出结果为：

```text
www.runoob.com
www.runoob.com
```

一个类最多只能有一个伴生对象，`companion` 关键字在一个类中只能出现一次。

### 伴生对象实现接口

既然伴生对象是一个真实对象，它当然可以实现接口，从而被当作接口实例传递。

**实例**

```kotlin
interface Factory<T> {
    fun create(): T
}

class MyClass {
    // 伴生对象实现 Factory 接口
    companion object : Factory<MyClass> {
        override fun create(): MyClass = MyClass()

        var count = 0
    }
}

fun main() {
    // 把伴生对象当作 Factory 实例使用
    val factory: Factory<MyClass> = MyClass.Companion
    val a = factory.create()
    MyClass.count = 3
    println(a is MyClass)
    println(MyClass.count)
}
```

输出结果为：

```text
true
3
```

---

## 对象表达式与对象声明的语义差异

两者的语法只差一个冒号，但初始化时机完全不同，这是面试和实际排错中经常考到的点。

| 写法 | 创建时机 | 实例数量 | 典型用途 |
| --- | --- | --- | --- |
| `object : A() { }` 对象表达式 | 执行到该表达式时立即创建 | 每次执行都创建一个新实例 | 事件监听、一次性实现接口 |
| `object Foo { }` 对象声明 | 第一次被访问时延迟初始化 | 全局唯一 | 单例、工具对象 |
| `companion object` 伴生对象 | 随外部类被初始化时一起初始化 | 每个类一个，全局唯一 | 工厂方法、静态风格常量 |

![三种 object 的初始化时机时间轴：对象表达式执行到该处立即初始化，对象声明首次被访问时懒加载初始化，伴生对象随外部类加载时初始化](images/kotlin/kotlin-object-declarations/21-object-init.svg)

下面这段代码把三种时机放在一起，观察输出顺序就能看清差别。

**实例**

```kotlin
// 对象声明：首次访问时才初始化
object Singleton {
    init {
        println("Singleton 初始化")
    }

    fun hello() = "hello"
}

// 伴生对象：随外部类初始化
class Holder {
    companion object {
        init {
            println("Holder 的伴生对象初始化")
        }
    }
}

fun main() {
    println("main 开始")
    val holder = Holder()            // 触发 Holder 类初始化，伴生对象随之初始化
    println("创建了 Holder 实例")
    println(Singleton.hello())       // 首次访问，Singleton 此时才初始化
    println("访问了 Singleton")
    println(holder is Holder)
}
```

输出结果为：

```text
main 开始
Holder 的伴生对象初始化
创建了 Holder 实例
Singleton 初始化
hello
访问了 Singleton
true
```

> **注意：**伴生对象的初始化与 Java 的静态初始化器语义一致，只要外部类被初始化就会执行。对象声明则是懒加载的，如果程序从头到尾没有访问过它，它的 `init` 块永远不会运行。

---

## 常见问题

下面整理对象表达式与对象声明最容易踩的几个坑。

| 问题 | 原因 | 解决办法 |
| --- | --- | --- |
| 公有函数返回匿名对象后访问不到新增成员 | 返回类型退化为超类型或 `Any` | 改为私有函数，或声明具名的类 / 接口 |
| 在函数内部写对象声明报错 | 对象声明不能是局部的 | 改用对象表达式 |
| 嵌套对象里访问外部类字段报错 | 嵌套对象不持有外部类实例 | 把字段作为参数传入，或改用 `inner` 内部类 |
| 通过外部类实例访问嵌套对象报错 | 嵌套对象属于类本身而非实例 | 用 `外部类名.对象名` 访问 |
| Java 代码调用伴生对象成员需要额外写法 | 伴生对象是实例成员，不是真正的静态成员 | 加 `@JvmStatic` 注解 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-object-declarations.html)，版权归原作者所有，仅供非商业学习使用。
