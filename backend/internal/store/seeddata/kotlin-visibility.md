可见性修饰符决定一个类、函数或属性能在多大的范围内被访问。

Kotlin 提供四个修饰符：public、internal、protected 和 private。

合理使用它们可以隐藏实现细节，避免外部代码依赖不该依赖的东西。

---

## 四个修饰符总览

不同位置能使用的修饰符并不相同，下表先给出一个全局印象。

| 修饰符 | 顶层声明 | 类成员 | 可见范围 |
| --- | --- | --- | --- |
| public | 可用（默认） | 可用（默认） | 任何地方 |
| internal | 可用 | 可用 | 同一个模块内 |
| protected | 不可用 | 可用 | 本类及其子类的内部 |
| private | 可用 | 可用 | 顶层声明：本文件；类成员：本类 |

Kotlin 没有 Java 那样的「包级可见性」。

不写修饰符就是 public，包名不影响可见范围。

> **提醒：**protected 不能用于顶层声明，只能写在类或接口的成员上。

---

## private：顶层同文件，类内仅本类

private 的含义取决于它修饰的是顶层声明还是类成员，这两者容易混淆。

修饰顶层声明时，private 表示只在这个源文件内可见，其他文件即使包名相同也无法访问。

**实例**

```kotlin
// 文件：RunoobFile.kt
private const val SITE: String = "www.runoob.com"   // 顶层 private：仅本文件可见

fun printSite() {
    println(SITE)   // 同一个文件内可以访问
}

// 文件：Main.kt（与 RunoobFile.kt 一起编译）
fun main() {
    printSite()      // 可以调用，printSite 是 public
    // println(SITE) // 编译错误：Cannot access 'SITE': it is private in file
}
```

```text
www.runoob.com
```

修饰类成员时，private 表示只有这个类自己的内部能访问，子类也不行。

**实例**

```kotlin
class RunoobAccount {
    private var balance: Double = 0.0   // 仅本类可见

    fun deposit(amount: Double) {
        // 内部可以自由读写 private 属性
        require(amount > 0) { "金额必须大于 0" }
        balance += amount
    }

    fun showBalance(): String = "余额：$balance 元"
}

fun main() {
    val account = RunoobAccount()
    account.deposit(100.0)
    println(account.showBalance())
    // println(account.balance)   // 编译错误：balance 是 private
}
```

```text
余额：100.0 元
```

private 成员同样不能被子类直接访问。

如果希望子类能用到，应该改用 protected，或者提供一个 public 方法间接暴露。

---

## protected：仅子类内部可见

protected 是四个修饰符里最容易被写错的一个。

Kotlin 的 protected 只在`本类以及子类的内部`可见，出了这个范围，即使是同一个文件或同一个包也访问不到。

这一点和 Java 不同：Java 的 protected 还允许同包访问，Kotlin 不允许。

**实例**

```kotlin
open class RunoobAnimal {
    protected var name: String = "Runoob 猫"   // 子类内部可见

    protected fun showName(): String = "动物名称：$name"
}

class RunoobCat : RunoobAnimal() {
    fun introduce() {
        name = "Runoob 小猫"   // 子类内部可以访问 protected 属性
        println(showName())    // 子类内部可以调用 protected 方法
    }
}

fun main() {
    val cat = RunoobCat()
    cat.introduce()
    // println(cat.name)   // 编译错误：protected 成员在类外不可见
    // cat.showName()      // 编译错误：同上
}
```

```text
动物名称：Runoob 小猫
```

protected 也不能用在顶层声明上，下面的写法无法通过编译。

**实例**

```kotlin
// 编译错误：Modifier 'protected' is not applicable to top-level declarations
// protected fun runoobHelp(): String = "帮助中心"

// 正确写法：顶层要么 public，要么 private / internal
fun runoobHelp(): String = "帮助中心"

fun main() {
    println(runoobHelp())
}
```

```text
帮助中心
```

> **注意：**Kotlin 的 protected 不是「同一个文件中或子类可见」。同文件可见是顶层 private 的语义；protected 只在类及其子类的内部可见，并且与包无关。

---

## internal：模块内可见

internal 表示「同一个模块内可见，模块外不可见」。

它适合放那些不打算作为公开 API、但又需要被同一项目多个文件共享的实现。

**实例**

```kotlin
// 文件：Logger.kt
internal fun log(message: String) {
    println("[RUNOOB] $message")
}

internal class RunoobLogger {
    internal val tag: String = "RUNOOB"
}

// 文件：Main.kt（与 Logger.kt 属于同一个模块）
fun main() {
    log("模块内可以直接调用")
    val logger = RunoobLogger()
    println(logger.tag)
}
```

```text
[RUNOOB] 模块内可以直接调用
RUNOOB
```

如果另一个模块引用这个项目，它就无法访问 log 和 RunoobLogger，编译器会提示 it is internal in 模块名。

---

## public：默认的可见性

不写任何修饰符时，声明的可见性就是 public。

public 成员在任何地方都可以访问，下面三种写法完全等价。

**实例**

```kotlin
public class RunoobSite          // 显式写 public
class RunoobMirror               // 省略修饰符，默认就是 public

public fun runoobHello(): String = "Hello RUNOOB"
fun runoobHi(): String = "Hi www.runoob.com"

public val siteName: String = "RUNOOB"
val siteUrl: String = "www.runoob.com"

fun main() {
    println(runoobHello())
    println(runoobHi())
    println("$siteName - $siteUrl")
}
```

```text
Hello RUNOOB
Hi www.runoob.com
RUNOOB - www.runoob.com
```

一般只在需要强调「这就是公开 API」时才显式写 public。

---

## 「模块」的定义

internal 的边界是「模块」，因此必须先说清楚模块指什么。

模块是一起编译的一组 Kotlin 源文件，常见的几种形态如下。

| 模块的形态 | 说明 |
| --- | --- |
| IntelliJ IDEA 模块 | 由 .iml 文件描述的一个项目模块 |
| Maven 项目 | 一个 pom.xml 描述的项目 |
| Gradle 源集（source set） | 如 main、test 这样的源集 |
| 一次 kotlinc 调用 | 命令行上一次编译的全部文件 |

Gradle 会额外把 main 源集的输出作为 friend module 传给 test 源集的编译，所以测试代码可以访问 main 中的 internal 声明。

反过来，两个彼此独立的 Gradle 项目即使包名完全相同，也互相看不到对方的 internal 成员。

---

## 构造器的可见性

构造器也可以设置可见性，用来控制谁能创建这个类的实例。

主构造器要写可见性，必须带上 constructor 关键字；次构造器则直接在 constructor 前加修饰符。

**实例**

```kotlin
// 主构造器设为 private：外部不能直接创建实例
class RunoobSingleton private constructor() {
    companion object {
        private val instance = RunoobSingleton()
        fun getInstance(): RunoobSingleton = instance
    }
}

// 主构造器设为 internal：只有同一模块内能创建
class RunoobConfig internal constructor(val host: String, val port: Int)

fun main() {
    val config = RunoobConfig("www.runoob.com", 80)
    println("${config.host}:${config.port}")

    // RunoobSingleton()   // 编译错误：主构造器是 private

    val single = RunoobSingleton.getInstance()
    println(single.javaClass.simpleName)
}
```

```text
www.runoob.com:80
RunoobSingleton
```

属性的 setter 也能单独设置可见性，常见的用法是「外部只读、内部可写」。

**实例**

```kotlin
class RunoobUser {
    var name: String = "runoob"
        private set      // setter 仅本类可见，外部只能读不能改

    fun rename(newName: String) {
        name = newName    // 本类内部仍然可以修改
    }
}

fun main() {
    val user = RunoobUser()
    println(user.name)
    user.rename("RUNOOB")
    println(user.name)
    // user.name = "菜鸟教程"   // 编译错误：setter 是 private
}
```

```text
runoob
RUNOOB
```

---

## 重写时的可见性规则

子类重写父类成员时，可见性只能放宽，不能收紧。

如果 override 时不写修饰符，重写成员会继承父类成员的可见性。

**实例**

```kotlin
open class RunoobBase {
    protected open fun runoobTip(): String = "来自基类的提示"
}

class RunoobChild : RunoobBase() {
    // 允许把 protected 放宽为 public
    public override fun runoobTip(): String = "来自子类的提示"
}

fun main() {
    println(RunoobChild().runoobTip())   // 现在是 public，类外可调用
}
```

```text
来自子类的提示
```

下面的写法会把可见性收紧，编译器直接报错。

**实例**

```kotlin
open class RunoobBase2 {
    open fun runoobInfo(): String = "info"
}

class RunoobChild2 : RunoobBase2() {
    // 编译错误：'runoobInfo' has a weaker access privilege than the overridden declaration
    // private override fun runoobInfo(): String = "info"
}
```

---

## 常见问题

下面整理几个初学者经常踩到的坑。

### private 和 internal 该选哪个

只在一个文件里用的辅助函数用 private；需要跨文件但不想暴露给外部使用者的用 internal。

拿不准时先写 private，等到确实需要扩大范围再改，这样最安全。

### 为什么 Java 代码调用不到 Kotlin 的 internal 方法

在 JVM 上，internal 成员的名字会被编译器加上模块名后缀，这个过程叫 name mangling。

所以 Java 里看不到原始名字，这不是权限问题，而是名字被改写了。

### public 函数能返回 internal 类型吗

不能，编译器会报 public function exposes its internal return type。

因为外部模块拿不到这个类型，等于给出了一个无法使用的 API。

### 局部变量能加可见性修饰符吗

不能，局部变量、函数参数和局部函数都不允许写可见性修饰符。

它们的可见范围本来就局限在所在的作用域内。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-visibility.html)，版权归原作者所有，仅供非商业学习使用。
