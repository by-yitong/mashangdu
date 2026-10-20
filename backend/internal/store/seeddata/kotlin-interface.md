接口描述一组能力或契约，它告诉调用方「这个类型能做什么」，但不限制具体怎么实现。

Kotlin 的接口比 Java 更灵活：方法可以带默认实现，属性也可以带默认 getter。

---

## 接口的定义

用 `interface` 关键字定义接口，里面可以写抽象方法，也可以写带方法体的默认实现。

接口成员默认是 public 且 open 的，这一点和类的成员默认 final 正好相反。

**实例**

```kotlin
// 文件路径：Main.kt
interface Site {
    // 抽象方法：没有方法体，实现类必须重写
    fun name(): String

    // 带默认实现的方法：实现类可以直接用，也可以重写
    fun url(): String = "www.runoob.com"

    // 默认实现可以调用其他成员，包括抽象的 name()
    fun info(): String = "站点：${name()}，地址：${url()}"
}

// 全部重写
class RunoobSite : Site {
    override fun name(): String = "RUNOOB"

    override fun url(): String = "https://www.runoob.com"
}

// 只重写抽象方法，url() 和 info() 使用接口的默认实现
class SimpleSite : Site {
    override fun name(): String = "Runoob"
}

fun main() {
    println(RunoobSite().info())
    println(SimpleSite().info())
}
```

输出结果：

```text
站点：RUNOOB，地址：https://www.runoob.com
站点：Runoob，地址：www.runoob.com
```

默认实现让接口可以向后兼容地增加新方法：老实现类不重写也能继续编译。

---

## 实现接口

类实现接口时，把接口名写在冒号后面；类也可以同时有主构造器，两者写在同一条冒号后面。

抽象成员必须全部实现，否则这个类要声明为 abstract。

**实例**

```kotlin
// 文件路径：Main.kt
interface Named {
    fun label(): String
}

// 没有主构造器的实现
class Simple : Named {
    override fun label(): String = "Simple"
}

// 有主构造器的实现：构造器参数写在接口名前面
class Site(val name: String) : Named {
    override fun label(): String = "Site($name)"
}

fun main() {
    // 接口可以作为集合的元素类型，存放不同实现
    val list: List<Named> = listOf(Simple(), Site("RUNOOB"))

    for (item in list) {
        println(item.label())
    }
}
```

输出结果：

```text
Simple
Site(RUNOOB)
```

一个类可以实现多个接口，只要用逗号隔开，这一点弥补了类只能单继承的限制。

---

## 接口属性

接口可以声明属性，但接口没有状态，所以属性不能有幕后字段，也不能写初始化器。

属性有两种写法：只声明类型的是抽象属性，提供 getter 的则带默认实现。

**实例**

```kotlin
// 文件路径：Main.kt
interface Named {
    val name: String              // 抽象属性：实现类必须提供

    // 带默认 getter 的属性：实现类不用重写就能用
    val displayName: String
        get() = "[$name]"

    // 接口里也可以声明 var，但 setter 由实现类负责
    var visits: Int
}

class Site(override val name: String) : Named {
    // var 属性在实现类里补上存储与 setter
    override var visits: Int = 0
}

fun main() {
    val site = Site("RUNOOB")
    println(site.displayName)

    site.visits = 100
    println("${site.name} 访问量：${site.visits}")
}
```

输出结果：

```text
[RUNOOB]
RUNOOB 访问量：100
```

> **重点修正：**接口中的属性不只是抽象的。它可以像 `displayName` 这样带默认 getter，实现类直接继承即可；只有写不出默认值的属性才必须由实现类提供。

但不能在接口里写 `val name: String = "RUNOOB"`，因为接口不保存状态，初始化器会被编译器拒绝。

---

## 函数重写与 super

当多个接口提供了同名成员的默认实现时，实现类必须重写这个方法，否则编译器不知道用哪一个。

重写时用 `super<接口名>` 分别调用各接口的实现，这个语法同样适用于属性。

**实例**

```kotlin
// 文件路径：Main.kt
interface A {
    fun foo(): String = "A.foo"
    val label: String
        get() = "A.label"
}

interface B {
    fun foo(): String = "B.foo"
    val label: String
        get() = "B.label"
}

class C : A, B {
    // 两个接口的默认实现冲突，必须显式重写
    override fun foo(): String = super<A>.foo() + " | " + super<B>.foo()

    override val label: String
        get() = super<A>.label + " | " + super<B>.label
}

fun main() {
    val c = C()
    println(c.foo())
    println(c.label)
}
```

输出结果：

```text
A.foo | B.foo
A.label | B.label
```

如果只有一个接口提供了默认实现，另一个接口只是声明了抽象方法，就不存在冲突，正常重写即可。

---

## 接口继承接口

接口可以继承一个或多个接口，用冒号声明，继承来的抽象成员由最终实现类负责实现。

如果子接口重写了某个默认实现，实现类会优先拿到子接口的版本。

**实例**

```kotlin
// 文件路径：Main.kt
interface Base {
    fun base(): String = "Base"
}

interface Left : Base {
    fun left(): String = "Left"
}

interface Right : Base {
    // 子接口重写了 Base 的默认实现
    override fun base(): String = "Right 重写了 Base"

    fun right(): String = "Right"
}

// Left 和 Right 都继承自 Base，Impl 只需要处理一次
class Impl : Left, Right {
    override fun base(): String = super<Right>.base()
}

fun main() {
    val impl = Impl()
    println(impl.base())
    println(impl.left())
    println(impl.right())
}
```

输出结果：

```text
Right 重写了 Base
Left
Right
```

接口继承形成菱形结构时，Kotlin 要求实现类显式重写发生冲突的成员，规则与上一节一致。

---

## 接口与抽象类的对比

两者都能声明抽象成员，也都能提供默认实现，选择时看是否需要保存状态和是否需要多继承。

| 对比项 | 接口 | 抽象类 |
| --- | --- | --- |
| 能否保存状态 | 不能，属性没有幕后字段 | 可以，属性可以有幕后字段 |
| 能否有构造器 | 不能 | 可以有主构造器和次构造器 |
| 多继承 | 一个类可实现多个接口 | 一个类只能继承一个抽象类 |
| 成员默认可见性 | public，且默认 open | 普通成员默认 final |
| 默认实现 | 支持，方法可带方法体 | 支持，普通方法即可 |
| 典型用途 | 定义能力契约，跨类型共享行为 | 复用公共实现，表达 is-a 关系 |

经验法则是：能表达成「能做某事」的用接口，需要共享状态和公共实现的用抽象类。

---

## 函数式接口 fun interface

只有一个抽象方法的接口叫函数式接口，用 `fun interface` 声明，自 Kotlin 1.4 起可以直接用 lambda 创建实例。

这个转换过程叫 SAM 转换，它让 Kotlin 接口拥有和 Java 函数式接口一样的书写便利。

**实例**

```kotlin
// 文件路径：Main.kt
fun interface Validator {
    // 唯一的抽象方法
    fun validate(text: String): Boolean

    // 非抽象成员不影响函数式接口的判定
    fun describe(): String = "校验器"
}

fun check(text: String, validator: Validator): String =
    if (validator.validate(text)) "「$text」通过校验" else "「$text」未通过校验"

fun main() {
    // 用 lambda 直接构造 fun interface 的实例
    val notEmpty = Validator { it.isNotEmpty() }
    println(check("RUNOOB", notEmpty))
    println(check("", notEmpty))

    val shorter = Validator { it.length <= 10 }
    println(check("www.runoob.com", shorter))
    println(shorter.describe())
}
```

输出结果：

```text
「RUNOOB」通过校验
「」未通过校验
「www.runoob.com」未通过校验
校验器
```

普通接口即便只有一个抽象方法也不能这样写，必须加 `fun` 修饰符。

> **注意：**fun interface 的唯一抽象方法不能是 suspend 函数，这是编译器的限制。

---

## 常见问题

下面几个问题是接口使用中问得最多的。

### 接口里的属性为什么不能写初始化器

接口没有状态，属性不能有幕后字段，所以 `val x: Int = 1` 会报错，需要默认值就写成 getter。

### 接口的方法默认是 final 吗

不是。接口成员默认是 open 的，子接口和实现类都可以重写它。

### 一个类能实现多个接口吗

可以。类之间只能单继承，但接口可以列多个，用逗号分隔，冲突的默认实现要用 super<接口名> 消歧。

### 接口能有构造器吗

不能。接口不保存状态，自然也不需要构造器；需要构造器就要用抽象类。

### 普通接口能不能用 lambda 创建实例

不能，只有 `fun interface` 才行。这个特性自 Kotlin 1.4 起提供。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-interface.html)，版权归原作者所有，仅供非商业学习使用。
