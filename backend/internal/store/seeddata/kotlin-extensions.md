Kotlin 可以在不修改原类、不使用继承、也不套用装饰器模式的前提下，给一个类添加新的函数和属性。

这种能力叫扩展，它让代码可以像调用成员一样调用你补上去的函数，读起来非常自然。

但扩展本质上只是静态的语法糖，它不会真的往被扩展的类里插入任何成员，理解这一点是掌握扩展的关键。

---

## 扩展函数

扩展函数的写法是在函数名前写上接收者类型和一个点号，接收者就是这个函数要扩展的类。

**实例**

```kotlin
class User(var name: String)

// 给 User 类扩展一个 printInfo 函数
fun User.printInfo() {
    println("用户名 $name")
}

fun main() {
    val user = User("Runoob")
    user.printInfo()   // 像调用成员函数一样调用扩展函数
}
```

输出结果为：

```text
用户名 Runoob
```

扩展函数体里的 `this` 指向调用时点号前面的那个对象，也就是接收者。

**实例**

```kotlin
// 给 MutableList<Int> 扩展一个交换函数
fun MutableList<Int>.swap(index1: Int, index2: Int) {
    val tmp = this[index1]        // this 指向调用 swap 的那个列表
    this[index1] = this[index2]
    this[index2] = tmp
}

fun main() {
    val list = mutableListOf(1, 2, 3)
    list.swap(0, 2)               // 交换下标 0 和 2 的元素
    println(list)
}
```

输出结果为：

```text
[3, 2, 1]
```

扩展函数不能访问被扩展类的私有成员，因为它根本没有真的进入那个类。

---

## 扩展是静态解析的

扩展函数不是接收者类型的虚拟成员，调用哪一个扩展函数由调用处对象的声明类型决定，而不是运行时类型。

**实例**

```kotlin
open class C
class D : C()

fun C.foo() = "c"
fun D.foo() = "d"

// 参数 c 的声明类型是 C，所以编译期就绑定到 C.foo()
fun printFoo(c: C) {
    println(c.foo())
}

fun main() {
    printFoo(D())   // 传入 D 的实例，输出的仍然是 c
}
```

输出结果为：

```text
c
```

也就是说，扩展函数的解析只发生在编译期，运行时不参与多态分发。

### 成员函数优先

如果扩展函数的签名和类自己的成员函数一模一样，调用时永远优先使用成员函数。

**实例**

```kotlin
class C {
    fun foo() = "成员函数"
}

fun C.foo() = "扩展函数"

fun main() {
    println(C().foo())   // 成员函数胜出
}
```

输出结果为：

```text
成员函数
```

> **注意：**扩展函数永远无法覆盖成员函数。如果你给某个类写了扩展，而它之后自己新增了同名同参数的方法，你的扩展会在无声无息中失效。给第三方库写扩展时，要留意这一点。

### 可空接收者

接收者类型可以写成可空类型，这样即使对象是 null，扩展函数也能被调用。

在函数体内用 `this == null` 判断即可，判空之后编译器会把 `this` 智能转换为非空类型。

**实例**

```kotlin
// 接收者是 Any?，所以 null 也能调用这个扩展
fun Any?.describe(): String {
    if (this == null) return "空值"
    // 判空之后 this 已经是非空类型
    return "非空：$this"
}

fun main() {
    val text: String? = null
    println(text.describe())
    println("RUNOOB".describe())
}
```

输出结果为：

```text
空值
非空：RUNOOB
```

---

## 扩展属性

除了函数，Kotlin 也允许给类扩展属性，写法是在接收者类型后面写属性名。

因为扩展不会真的往类里插入字段，所以扩展属性没有 backing field，也就不能写初始化器，它的行为完全由显式提供的 getter 和 setter 决定。

**实例**

```kotlin
class Site(val name: String, val url: String)

// 只读扩展属性：只提供 getter
val Site.info: String
    get() = "$name ($url)"

fun main() {
    val site = Site("菜鸟教程", "www.runoob.com")
    println(site.info)
}
```

输出结果为：

```text
菜鸟教程 (www.runoob.com)
```

扩展属性同样可以是 `var`，只要同时提供 getter 和 setter 就行。

**实例**

```kotlin
// var 扩展属性：getter 和 setter 都必须显式写出
var StringBuilder.lastChar: Char
    get() = get(length - 1)              // 读取最后一个字符
    set(value: Char) {
        setCharAt(length - 1, value)     // 修改最后一个字符
    }

fun main() {
    val sb = StringBuilder("RUNOOB")
    println(sb.lastChar)
    sb.lastChar = '!'
    println(sb)
}
```

输出结果为：

```text
B
RUNOO!
```

下面这种写法是非法的，因为扩展属性不允许有初始化器。

**实例**

```kotlin
class Foo

// 错误：扩展属性不能有初始化器，它没有 backing field
val Foo.bar = 1

// 正确写法：提供显式的 getter
val Foo.bar: Int
    get() = 1
```

> **注意：**扩展属性必须是顶层的或者属于某个类，不能定义在函数内部。另外，由于没有 backing field，扩展属性无法缓存计算结果，每次读取都会重新执行 getter 逻辑。

---

## 伴生对象的扩展

如果类有伴生对象，你也可以给伴生对象扩展函数和属性。

由于伴生对象的成员可以用类名直接访问，这些扩展也就表现得像静态成员。

**实例**

```kotlin
class MyClass {
    companion object   // 将被称为 Companion
}

// 给伴生对象扩展函数
fun MyClass.Companion.create(): MyClass = MyClass()

// 给伴生对象扩展属性
val MyClass.Companion.siteName: String
    get() = "菜鸟教程"

fun main() {
    println(MyClass.siteName)        // 用类名访问扩展属性
    println(MyClass.create() is MyClass)
}
```

输出结果为：

```text
菜鸟教程
true
```

如果伴生对象有名字，扩展时把 `Companion` 换成那个名字即可。

---

## 扩展的作用域与导入

扩展通常定义在顶层包下，要使用其他包里定义的扩展，必须像导入普通函数一样导入它。

**实例**

```kotlin
// 文件路径：com/runoob/extensions/SiteExtensions.kt
package com.runoob.extensions

class Site(val name: String, val url: String)

// 顶层扩展函数，属于包 com.runoob.extensions
fun Site.describe(): String = "$name -> $url"
```

在另一个包里使用时，需要导入这个扩展函数的名字。

**实例**

```kotlin
// 文件路径：com/runoob/app/Main.kt
package com.runoob.app

import com.runoob.extensions.Site
import com.runoob.extensions.describe   // 导入扩展函数

// 也可以写 import com.runoob.extensions.* 导入整个包

fun main() {
    val site = Site("菜鸟教程", "www.runoob.com")
    println(site.describe())
}
```

输出结果为：

```text
菜鸟教程 -> www.runoob.com
```

扩展只在它被导入的作用域内可见，同一个扩展在不同包里可以重名，互不影响。

---

## 成员扩展：分发接收者与扩展接收者

扩展也可以声明在类内部，这时它同时拥有两个接收者。

定义扩展的那个类的实例叫分发接收者，被扩展类型的实例叫扩展接收者。

**实例**

```kotlin
class D {
    fun bar() = "D.bar"
}

class C {
    fun baz() = "C.baz"

    // 在 C 内部给 D 定义扩展函数
    fun D.foo(): String {
        val fromExtension = bar()   // 扩展接收者 D 的成员
        val fromDispatch = baz()    // 分发接收者 C 的成员
        return "$fromExtension / $fromDispatch"
    }

    fun caller(d: D) = d.foo()
}

fun main() {
    println(C().caller(D()))
}
```

输出结果为：

```text
D.bar / C.baz
```

如果两个接收者上存在同名成员，扩展接收者优先，要访问分发接收者的成员需要写 `this@类名`。

**实例**

```kotlin
class D {
    fun bar() = "D.bar"
}

class C {
    fun bar() = "C.bar"     // 与 D 的 bar 同名

    fun D.foo(): String {
        val first = bar()         // 扩展接收者优先，调用 D.bar()
        val second = this@C.bar() // 显式指定分发接收者，调用 C.bar()
        return "$first / $second"
    }

    fun caller(d: D) = d.foo()
}

fun main() {
    println(C().caller(D()))
}
```

输出结果为：

```text
D.bar / C.bar
```

以成员形式定义的扩展函数可以声明为 `open`，并且可以在子类中覆盖。

分发过程对分发接收者是虚拟的，对扩展接收者仍然是静态的。

**实例**

```kotlin
open class D
class D1 : D()

open class C {
    open fun D.foo() = "D.foo in C"
    open fun D1.foo() = "D1.foo in C"

    fun caller(d: D) = d.foo()   // 参数声明类型是 D
}

class C1 : C() {
    override fun D.foo() = "D.foo in C1"
    override fun D1.foo() = "D1.foo in C1"
}

fun main() {
    println(C().caller(D()))    // 分发接收者是 C
    println(C1().caller(D()))   // 分发接收者是 C1，虚拟解析
    println(C().caller(D1()))   // 扩展接收者按声明类型 D 静态解析
}
```

输出结果为：

```text
D.foo in C
D.foo in C1
D.foo in C
```

---

## 常见问题

下面整理扩展使用中最容易出错的地方。

| 问题 | 原因 | 解决办法 |
| --- | --- | --- |
| 给子类对象调用扩展，结果执行了父类的扩展 | 扩展按声明类型静态解析 | 把参数类型改成子类，或改用成员函数的重写 |
| 自己写的扩展被类自己的同名方法「顶掉」 | 成员函数永远优先于扩展函数 | 给扩展换个名字，或使用作用域函数规避 |
| 扩展属性写初始化器报错 | 扩展属性没有 backing field | 改为显式提供 getter 和 setter |
| 想在扩展里访问私有成员 | 扩展不是真正的成员 | 通过公开 API 访问，或把扩展定义在同类内部 |
| 别的文件里用不了写好的扩展 | 扩展不会自动跨包可见 | 用 `import` 导入扩展函数或整个包 |
| 在成员扩展里分不清两个 this | 同时存在分发接收者与扩展接收者 | 用 `this@外部类名` 指定分发接收者 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-extensions.html)，版权归原作者所有，仅供非商业学习使用。
