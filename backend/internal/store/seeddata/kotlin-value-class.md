值类（value class）让开发者给基本类型套上一层有语义的类型外壳，同时几乎不付出运行时开销。

它解决的是"用 String 表示邮箱、用 Int 表示用户 ID 容易传错参数"这类问题，又不会像普通包装类那样每次使用都分配对象。

---

## 什么是值类

值类的核心思想是：源码层面它是一个独立的类型，编译后却尽量退化为它包裹的那个底层值。

先看一个没有值类时容易犯的错误。

**实例**

```kotlin
// 三个参数都是 String，编译器无法阻止调用者把顺序写反
fun transfer(fromAccount: String, toAccount: String, amount: Double) {
    println("从 $fromAccount 转账 $amount 到 $toAccount")
}

fun main() {
    val account = "6222021234567890"
    val password = "runoob-2026"
    // 参数顺序写反了，编译照样通过，运行时才暴露问题
    transfer(password, account, 100.0)
}
```

运行结果：

```text
从 runoob-2026 转账 100.0 到 6222021234567890
```

如果把账号和密码分别包装成两个不同的值类，编译器就能在编译期拦住这类错误。

---

## 从 inline class 到 value class

值类的概念最早以 `inline class` 的名字出现，Kotlin 1.3 起可以使用。

Kotlin 1.5 起官方统一改称 `value class`，并要求必须加上 `@JvmInline` 注解。

| 版本 | 写法 | 说明 |
| --- | --- | --- |
| Kotlin 1.3 起 | `inline class UserId(val value: Int)` | 使用 `inline` 修饰符，不需要注解 |
| Kotlin 1.5 起 | `@JvmInline value class UserId(val value: Int)` | 官方推荐写法，旧写法已弃用 |

> **注意：**Kotlin 2.2 下再写 `inline class` 会得到弃用警告，请一律使用 `@JvmInline value class`。

`@JvmInline` 来自默认导入的 `kotlin.jvm` 包，因此不需要额外 import。

---

## 定义并使用值类

值类用 `@JvmInline` 和 `value` 两个关键字声明。

主构造器必须有且仅有一个用 `val` 修饰的参数，这个参数称为底层属性（underlying property），是值类真正存储的数据。

**实例**

```kotlin
@JvmInline
value class UserId(val value: Int)

@JvmInline
value class Email(val address: String)

// 两个参数类型不同，调用时传反顺序会直接编译报错
fun sendMail(to: Email, userId: UserId) {
    println("向 ${to.address} 的用户 ${userId.value} 发送邮件")
}

fun main() {
    val email = Email("runoob@www.runoob.com")
    val id = UserId(1001)
    sendMail(email, id)

    // 值类自动生成 equals / hashCode / toString
    println(id == UserId(1001))
    println(UserId(1001) == UserId(1002))
    println(id)
}
```

运行结果：

```text
向 runoob@www.runoob.com 的用户 1001 发送邮件
true
false
UserId(value=1001)
```

注意最后一行输出：值类自动生成的 `toString()` 格式是"类名(属性名=值)"，和数据类一致。

---

## 在 init 块中校验取值

值类可以带 `init` 初始化块，Kotlin 1.4.30 起支持。

这适合在构造阶段就拦掉非法的底层值，让"类型正确"进一步变成"取值也正确"。

**实例**

```kotlin
@JvmInline
value class Percentage(val value: Int) {
    init {
        // 构造时校验，非法值根本创建不出来
        require(value in 0..100) { "百分比必须在 0 到 100 之间，当前为 $value" }
    }
}

fun main() {
    val progress = Percentage(80)
    println("进度：${progress.value}%")

    // 用 runCatching 捕获构造异常，方便展示错误信息
    val result = runCatching { Percentage(120) }
    println(result.exceptionOrNull()?.message)
}
```

运行结果：

```text
进度：80%
百分比必须在 0 到 100 之间，当前为 120
```

如果希望强制走校验逻辑，可以把主构造器设为私有，再通过伴生对象提供工厂函数。

**实例**

```kotlin
@JvmInline
value class Email private constructor(val address: String) {
    companion object {
        // 工厂函数：统一做清洗与校验，外部无法绕过
        fun of(raw: String): Email {
            val normalized = raw.trim().lowercase()
            require(normalized.contains("@")) { "邮箱格式不正确：$raw" }
            return Email(normalized)
        }
    }
}

fun main() {
    val email = Email.of("  RUNOOB@www.Runoob.com  ")
    println(email.address)

    val bad = runCatching { Email.of("runoob.com") }
    println(bad.exceptionOrNull()?.message)
}
```

运行结果：

```text
runoob@www.runoob.com
邮箱格式不正确：runoob.com
```

---

## 与数据类的区别

值类和数据类都用于包装数据，但设计目标完全不同。

数据类关注"这一组数据是什么"，值类关注"这一个值代表什么含义"。

| 对比项 | 值类 value class | 数据类 data class |
| --- | --- | --- |
| 属性数量 | 主构造器有且仅有 1 个 val 属性 | 主构造器至少 1 个属性，可多个 |
| 运行时表示 | 尽量退化为底层值，通常不分配对象 | 始终是一个普通对象 |
| 自动生成成员 | equals / hashCode / toString | equals / hashCode / toString / copy / componentN |
| 解构声明 | 不支持 | 支持，按属性顺序解构 |
| 继承 | 不能继承类，可以实现接口 | 不能是 open / abstract / sealed，可以实现接口 |
| 典型用途 | 类型安全的 ID、单位、金额、百分比 | DTO、函数返回值、多字段聚合 |

> **注意：**值类不能加 `data` 修饰符，也不能是 `open`、`abstract` 或 `sealed`。

---

## 值类的限制

值类的"零开销"来自编译器能直接使用底层值，因此语言层面必须限制它的形态。

| 限制 | 说明 |
| --- | --- |
| 主构造器只有一个 val 参数 | 多一个参数就无法确定底层值 |
| 底层属性只能是 val | 值类按值传递，不允许改底层数据 |
| 不能有带 backing field 的属性 | 只能写计算属性（自定义 getter，不存数据） |
| 不能是 inner 类 | 内部类需要持有外部类引用，与值语义冲突 |
| 不能继承其他类 | 但可以实现接口 |
| 必须是 final | 不能 open / abstract / sealed |
| JVM 平台必须加 @JvmInline | 其他后端（如 Kotlin/Native）不需要 |

可以带计算属性，只要它不保存额外状态。

**实例**

```kotlin
@JvmInline
value class Temperature(val celsius: Double) {
    // 计算属性：不占额外内存，getter 每次现算
    val fahrenheit: Double
        get() = celsius * 9 / 5 + 32
}

fun main() {
    val t = Temperature(25.0)
    println("摄氏 ${t.celsius} 度")
    println("华氏 ${t.fahrenheit} 度")
}
```

运行结果：

```text
摄氏 25.0 度
华氏 77.0 度
```

---

## 装箱与不装箱的时机

值类"没有额外开销"的前提，是编译器能用底层类型直接表示它。

![值类的装箱与不装箱时机：直接作为 UserId 类型或函数参数返回值时不装箱，运行时就是 Int；用作可空类型、泛型参数、接口或集合元素时装箱成对象](images/kotlin/kotlin-value-class/25-value-class-boxing.svg)

一旦值类需要被当成普通对象引用使用，编译器就会自动装箱，此时它和一个普通包装类没有区别。

| 使用方式 | 是否装箱 | 原因 |
| --- | --- | --- |
| 直接作为具体类型的变量、参数、返回值 | 不装箱 | 编译后直接使用底层类型 |
| 赋给 Any 或它实现的接口 | 装箱 | 需要对象头和虚方法表 |
| 可空类型 UserId? | 装箱 | 底层 Int 无法表示 null |
| 作为泛型实参，如 List<UserId> | 装箱 | 泛型类型参数只接受引用类型 |
| 存入 Array<UserId> | 装箱 | 数组元素本身就是引用 |
| 使用 === 做引用比较 | 编译报错 | 值类没有稳定的引用身份 |

下面用接口演示装箱：同一个值类，作为具体类型传递时不装箱，作为接口类型传递时装箱。

**实例**

```kotlin
interface Displayable {
    fun display(): String
}

@JvmInline
value class Meter(val value: Double) : Displayable {
    override fun display(): String = "$value m"
}

// 参数是具体类型 Meter，底层就是一个 double
fun half(m: Meter): Meter = Meter(m.value / 2)

// 参数是接口类型，传入的 Meter 会被装箱成对象
fun show(d: Displayable): String = d.display()

fun main() {
    val m = Meter(10.0)
    println(half(m).value)
    println(show(m))
    println(m.display())
}
```

运行结果：

```text
5.0
10.0 m
10.0 m
```

> **建议：**如果值类定义了大量使用，尽量让函数签名直接使用值类本身，而不是 `Any`、接口或泛型容器，这样才能真正省下装箱开销。

---

## 常见问题

值类支持解构声明吗？

不支持。值类只生成 `equals`、`hashCode` 和 `toString`，不会生成 `componentN`，因此不能写成 `val (v) = UserId(1)`。

值类可以作为 Map 的 key 吗？

可以。值类重写了 `equals` 和 `hashCode`，语义与数据类一致，底层相同的两个实例在 Map 中视为同一个 key。

值类能和数据类互相替代吗？

不能。需要多个字段、需要 `copy` 或解构时用数据类；只需要包装单个值并获得类型安全时用值类。

值类一定不分配对象吗？

不一定。只要出现可空、泛型、接口或 `Any` 这几类用法，编译器就会装箱，具体是否装箱可以用 `javap` 反编译字节码确认。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-value-class.html)，版权归原作者所有，仅供非商业学习使用。
