类是对数据和行为的封装，对象是类的一个具体实例。

本章节从最简单的空类讲起，逐步覆盖属性、构造器、初始化块、内部类和访问修饰符，这些是后面学习继承与接口的地基。

---

## 类的定义

Kotlin 用 `class` 关键字定义类，类名后面可以跟主构造器，类体写在大括号里。

创建一个对象不需要 `new` 关键字，直接写类名加括号即可，这一点与 Java 不同。

**实例**

```kotlin
// 文件路径：Main.kt

// 空类：没有类体，大括号可以省略
class Runoob

// 带空主构造器的类，与上面写法等价
class RunoobSite()

fun main() {
    // 不需要 new，直接调用类名创建对象
    val a = Runoob()
    val b = RunoobSite()

    println("a 的类型：${a::class.simpleName}")
    println("b 的类型：${b::class.simpleName}")
}
```

输出结果：

```text
a 的类型：Runoob
b 的类型：RunoobSite
```

`class Runoob` 与 `class Runoob()` 在创建对象时行为一致，差别只在有没有显式写主构造器。

---

## 属性与 getter/setter

类体里用 `val` 声明只读属性，用 `var` 声明可变属性。

每个属性都自带 getter，`var` 属性还自带 setter，需要自定义行为时可以自己写。

**实例**

```kotlin
// 文件路径：Main.kt
class Site {
    var name: String = "RUNOOB"           // var 属性：有 getter 和 setter
    val url: String = "www.runoob.com"    // val 属性：只有 getter

    // 自定义 getter：每次访问都重新计算，没有幕后字段
    val info: String
        get() = "$name - $url"

    // 自定义 setter：value 是约定俗成的参数名
    var visits: Int = 0
        set(value) {
            if (value < 0) {
                println("访问量不能为负，已忽略")
            } else {
                field = value
            }
        }
}

fun main() {
    val site = Site()

    println(site.info)

    site.visits = 100
    println("访问量：${site.visits}")

    site.visits = -1
    println("访问量：${site.visits}")
}
```

输出结果：

```text
RUNOOB - www.runoob.com
访问量：100
访问量不能为负，已忽略
访问量：100
```

在 setter 里，`value` 是新值，`field` 是属性真正的存储位置，只能写在 getter 或 setter 内部。

---

## 幕后字段 backing field

Kotlin 不会直接暴露成员变量，而是通过 getter 和 setter 访问，真正存值的那个字段叫做幕后字段。

只有需要真正存储值的属性才会生成幕后字段，用只读计算得到的属性不会有。

**实例**

```kotlin
// 文件路径：Main.kt
class Counter {
    var count: Int = 0
        get() = field        // field 就是幕后字段
        set(value) {
            field = value
        }

    // 只读计算属性：没有幕后字段，每次访问都重新计算
    val doubleCount: Int
        get() = count * 2
}

fun main() {
    val c = Counter()
    c.count = 21

    println("count：${c.count}")
    println("doubleCount：${c.doubleCount}")
}
```

输出结果：

```text
count：21
doubleCount：42
```

> **注意：**如果自定义的 getter 和 setter 都没有用到 field，这个属性就不会生成幕后字段，相当于一个只做计算或转发的入口。

---

## 主构造器与 constructor 省略规则

主构造器写在类名后面，参数前加 `val` 或 `var` 就会同时声明属性。

没有注解、没有可见性修饰符时，`constructor` 关键字可以省略。

**实例**

```kotlin
// 文件路径：Main.kt

// 主构造器直接声明属性：val 只读，var 可变
class Site(val name: String, var visits: Int) {
    // 没写 constructor，因为既没有注解也没有可见性修饰符
    init {
        println("创建站点：$name，初始访问量：$visits")
    }
}

fun main() {
    val site = Site("RUNOOB", 0)
    site.visits = 10
    println("${site.name} 访问量：${site.visits}")
}
```

输出结果：

```text
创建站点：RUNOOB，初始访问量：0
RUNOOB 访问量：10
```

如果参数前不写 `val` 或 `var`，它只是构造器参数，不是属性，只能在初始化块和属性初始化器里使用。

当主构造器带可见性修饰符或注解时，`constructor` 关键字就不能省略了，例如 `private constructor`，后面「私有构造器」一节会看到具体写法。

---

## init 初始化块

`init` 块用来放置对象创建时需要执行的代码，可以写多个。

![Kotlin 类初始化顺序流程图：主构造器参数求值，然后属性初始化与 init 块按书写顺序交错执行，再执行次构造器体，最后对象可用](images/kotlin/kotlin-class-object/14-init-order.svg)

属性初始化器和 `init` 块按书写顺序执行，理解这个顺序对排查初始化问题很重要。

**实例**

```kotlin
// 文件路径：Main.kt
class Demo(val name: String) {
    // 属性初始化器与 init 块按书写顺序执行
    private val first = "第一个属性：$name".also { println(it) }

    init {
        println("init 块：$name")
    }

    private val second = "第二个属性：$name".also { println(it) }
}

fun main() {
    Demo("RUNOOB")
}
```

输出结果：

```text
第一个属性：RUNOOB
init 块：RUNOOB
第二个属性：RUNOOB
```

所以不要在后写的初始化代码里去读取先写但尚未赋值完成的可空属性，否则容易拿到 null。

---

## 次构造器与 this 委托

次构造器用 `constructor` 关键字声明，写在类体里。

如果类有主构造器，每个次构造器都必须直接或间接委托给主构造器，委托用 `this(...)` 完成。

**实例**

```kotlin
// 文件路径：Main.kt
class Site(val name: String, val url: String) {
    var visits: Int = 0

    // 次构造器必须委托给主构造器，这里补上默认地址
    constructor(name: String) : this(name, "www.runoob.com") {
        println("使用次构造器创建：$name")
    }
}

fun main() {
    val a = Site("RUNOOB", "www.runoob.com")
    println("${a.name} -> ${a.url}")

    val b = Site("Runoob")
    println("${b.name} -> ${b.url}")
}
```

输出结果：

```text
RUNOOB -> www.runoob.com
使用次构造器创建：Runoob
Runoob -> www.runoob.com
```

委托链上，主构造器的参数先就绪，随后才是次构造器的代码体，所以打印顺序是上面的样子。

---

## 私有构造器

把主构造器标记为 `private`，外部就不能直接创建对象，只能通过类内部提供的工厂方法获取实例。

这种写法常用于单例、工具类，以及希望控制实例创建过程的场景。

**实例**

```kotlin
// 文件路径：Main.kt
class Token private constructor(val value: String) {
    // 外部无法调用 Token("...")，只能通过这个工厂方法
    companion object {
        fun create(): Token = Token("runoob-token")
    }

    fun describe(): String = "Token($value)"
}

fun main() {
    // val t = Token("abc")   // 编译错误：构造函数是私有的
    val token = Token.create()
    println(token.describe())
}
```

输出结果：

```text
Token(runoob-token)
```

---

## 抽象类

用 `abstract` 修饰的类叫抽象类，它不能被实例化，只能被继承。

抽象类里可以同时有抽象成员和普通成员，抽象成员必须由子类实现。

**实例**

```kotlin
// 文件路径：Main.kt
abstract class Shape {
    // 抽象成员没有实现，子类必须重写
    abstract fun area(): Double

    // 普通成员默认是 final，加 open 才能被重写
    open fun describe(): String = "面积是 ${area()}"
}

class Circle(val radius: Double) : Shape() {
    override fun area(): Double = 3.14 * radius * radius
}

class Square(val side: Double) : Shape() {
    override fun area(): Double = side * side

    override fun describe(): String = "正方形" + super.describe()
}

fun main() {
    // val s = Shape()   // 编译错误：抽象类不能实例化

    val shapes: List<Shape> = listOf(Circle(2.0), Square(3.0))
    for (shape in shapes) {
        println(shape.describe())
    }
}
```

输出结果：

```text
面积是 12.56
正方形面积是 9.0
```

注意 `abstract fun area()` 天然是 open 的，但 `describe()` 想被子类重写，必须显式加 `open`。

---

## 嵌套类与内部类

写在类体里的类叫嵌套类，默认不持有外部类的引用。

如果希望访问外部类的成员，要加 `inner` 关键字，此时它成为内部类，可以用 `this@Outer` 明确指向外部类实例。

**实例**

```kotlin
// 文件路径：Main.kt
class Outer(val name: String = "OUTER") {
    private val secret = "runoob"

    // 嵌套类：不持有外部类实例引用，访问不了 name 和 secret
    class Nested {
        fun hello(): String = "我是嵌套类，拿不到外部类的成员"
    }

    // 内部类：持有外部类实例引用，可以访问外部类成员
    inner class Inner {
        fun hello(): String = "我是内部类，name=$name，secret=$secret"

        // this@Outer 明确指向外部类实例
        fun outerName(): String = this@Outer.name
    }
}

fun main() {
    // 嵌套类直接用外部类名访问，不需要外部类对象
    val nested = Outer.Nested()
    println(nested.hello())

    // 内部类必须依赖外部类实例
    val outer = Outer()
    val inner = outer.Inner()
    println(inner.hello())
    println("this@Outer 拿到：${inner.outerName()}")
}
```

输出结果：

```text
我是嵌套类，拿不到外部类的成员
我是内部类，name=OUTER，secret=runoob
this@Outer 拿到：OUTER
```

嵌套类没有额外的外部引用，更轻量；内部类会隐式持有一个外部类对象，内存上要留意。

---

## 匿名内部类

用对象表达式可以创建一个没有名字的类，它通常用来临时实现某个接口或抽象类。

对象表达式在写下的那一刻就立即创建实例，不需要额外的类声明。

**实例**

```kotlin
// 文件路径：Main.kt
interface ClickListener {
    fun onClick(name: String)
}

fun main() {
    // 对象表达式：临时实现 ClickListener 接口
    val listener = object : ClickListener {
        override fun onClick(name: String) {
            println("点击了：$name")
        }
    }
    listener.onClick("RUNOOB")

    // 不实现任何接口时，也可以直接写一个匿名对象
    val config = object {
        val url = "www.runoob.com"
        val timeout = 3000
    }
    println("${config.url} -> ${config.timeout}ms")
}
```

输出结果：

```text
点击了：RUNOOB
www.runoob.com -> 3000ms
```

> **注意：**匿名对象如果作为公有函数的返回类型，外部只能看到它声明的超类型（例如接口类型），拿不到匿名对象自己新增的成员，这个细节在第 21 篇《Kotlin 对象表达式与对象声明》会展开。

---

## 类修饰符与访问修饰符

类本身可以带多种修饰符，用来控制继承、实例化方式和生成的特殊行为。

| 修饰符 | 含义 |
| --- | --- |
| final | 默认状态，类不可被继承 |
| open | 允许被继承 |
| abstract | 抽象类，不能实例化，成员可以是抽象 |
| sealed | 密封类，子类范围受限，详见第 19 篇《Kotlin 密封类与密封接口》 |
| data | 数据类，自动生成 equals、hashCode、toString、copy，详见第 18 篇《Kotlin 数据类与解构》 |
| enum | 枚举类，详见第 20 篇《Kotlin 枚举类》 |
| inner | 内部类，持有外部类实例引用 |
| value | 值类，配合 @JvmInline 使用，详见第 25 篇《Kotlin 值类》 |

访问修饰符控制成员能被谁看到，共四个。

| 修饰符 | 类成员可见范围 | 顶层声明 |
| --- | --- | --- |
| public（默认） | 任何位置 | 任何位置 |
| internal | 同一模块内 | 同一模块内 |
| protected | 仅本类及其子类内部 | 不允许用于顶层声明 |
| private | 仅本类内部 | 仅本文件内 |

**实例**

```kotlin
// 文件路径：Main.kt
open class Base {
    private val a = "private：仅本类内部可见"
    protected val b = "protected：仅本类及其子类内部可见"
    internal val c = "internal：同一模块内可见"
    val d = "public：默认，任何位置可见"

    fun showBase() {
        println(a)
        println(b)
    }
}

class Derived : Base() {
    fun showDerived() {
        // println(a)   // 编译错误：private 成员连子类也看不到
        println(b)      // 可以：protected 在子类内部可见
        println(c)
        println(d)
    }
}

fun main() {
    val base = Base()
    base.showBase()

    // println(base.b)  // 编译错误：外部无法访问 protected 成员

    val derived = Derived()
    derived.showDerived()
}
```

输出结果：

```text
private：仅本类内部可见
protected：仅本类及其子类内部可见
protected：仅本类及其子类内部可见
internal：同一模块内可见
public：默认，任何位置可见
```

> **重点修正：**Kotlin 的 protected 只在「本类及其子类的内部」可见，与文件、包都没有关系，外部代码即便是同一个文件也访问不到。同一文件内可见是顶层 private 的语义，两者不要混淆。

再强调一次：`protected` 与继承绑定，`internal` 与模块绑定，前者要求是子类，后者只要求在同一模块内。

---

## 常见问题

下面是初学类与对象时最容易卡住的几个点。

### 主构造器参数不加 val 或 var 会怎样

它只是构造器参数，不是属性。它可以被属性初始化器和 init 块使用，但不能通过对象访问。

### init 块和属性初始化器谁先执行

按书写顺序执行，谁写在前面谁先执行，与是不是 init 块无关。

### 次构造器为什么必须调用 this(...)

类有主构造器时，主构造器负责初始化属性，次构造器必须直接或间接委托给它，否则属性无法完成初始化。

### 嵌套类和内部类怎么选

不需要外部类成员就用嵌套类，它更轻量；需要访问外部类成员才用 inner。

### 抽象类能不能有普通成员

可以。抽象类里既有抽象成员，也可以有带实现的普通成员，只是这些普通成员默认是 final，想被重写要加 open。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-class-object.html)，版权归原作者所有，仅供非商业学习使用。
