空安全（null safety）是 Kotlin 最核心的语言特性，它在类型系统层面把"可能为 null"和"一定不为 null"区分开。

只要编译器判断某个值可能为 null，就必须显式处理，否则代码无法通过编译，大量空指针异常因此被提前到编译期发现。

---

## 可空类型与非空类型

Kotlin 的类型默认都不可为 null，只有加上问号 `?` 才表示可空。

非空类型可以放心调用成员，可空类型必须先做判空处理，编译器不会替你假设它不为 null。

**实例**

```kotlin
fun main() {
    val name: String = "Runoob"           // 非空，永远不可能是 null
    var site: String? = "www.runoob.com"  // 可空，可以赋值为 null

    // 非空类型直接访问成员，编译器保证安全
    println(name.length)

    // 可空类型必须用安全调用，直接写 site.length 会编译报错
    println(site?.length)

    site = null
    println(site?.length)
}
```

运行结果：

```text
6
14
null
```

> **注意：**可空类型和非空类型在运行时是同一个 JVM 类型，区别只存在于编译期的类型标记。这也意味着绕过编译器（比如 Java 互操作或反射）依然可能产生 null。

---

## 安全调用 ?.

安全调用 `?.` 表示"如果接收者不为 null 才调用，否则整个表达式返回 null"。

![拿到可空值 val name: String? 后的五种处理：?. 安全调用、?: Elvis、!! 非空断言（危险）、as? 安全转换、?.let 块](images/kotlin/kotlin-null-safety/27-null-safety-flow.svg)

它可以链式书写，链条上任何一环为 null，后续调用都会跳过，最终结果是 null。

**实例**

```kotlin
data class Address(val city: String, val zip: String?)
data class User(val name: String, val address: Address?)

fun main() {
    val user = User("Runoob", Address("北京", null))
    val noAddress = User("RUNOOB", null)

    println(user.address?.city)      // address 非空，输出城市
    println(noAddress.address?.city) // address 为 null，输出 null
    println(user.address?.zip?.length) // zip 为 null，输出 null
}
```

运行结果：

```text
北京
null
null
```

安全调用同样可以用于函数调用，例如 `site?.trim()`，接收者为 null 时不会执行函数，直接返回 null。

---

## Elvis 运算符 ?:

Elvis 运算符 `?:` 表示"左边为 null 时取右边的值"，用来提供兜底方案。

它右侧是惰性求值的，只有左边确实为 null 时才会计算，因此可以安全地写 `throw` 或 `return`。

**实例**

```kotlin
// 为 null 或解析失败时抛出异常，右侧只在左侧为 null 时求值
fun parsePort(text: String?): Int {
    return text?.toIntOrNull() ?: throw IllegalArgumentException("端口不合法：$text")
}

fun main() {
    val nickname: String? = null
    val display = nickname ?: "游客"
    println(display)

    println(parsePort("8080"))
    println(runCatching { parsePort("abc") }.exceptionOrNull()?.message)
}
```

运行结果：

```text
游客
8080
端口不合法：abc
```

Elvis 右侧也可以直接写 `return`，用于函数提前退出。

**实例**

```kotlin
fun welcome(name: String?): String {
    // name 为 null 时函数直接返回，后面的代码不会执行
    val safeName = name ?: return "名字不能为空"
    return "欢迎 $safeName"
}

fun main() {
    println(welcome("Runoob"))
    println(welcome(null))
}
```

运行结果：

```text
欢迎 Runoob
名字不能为空
```

---

## 非空断言 !!

双感叹号 `!!` 是"我确定它不为 null"的断言。

一旦实际值为 null，程序会立即抛出 `NullPointerException`，因此它只是把编译期的检查推迟到了运行时。

**实例**

```kotlin
fun main() {
    val value: String? = "RUNOOB"
    // 确定非空时可以直接用，此处输出 6
    println(value!!.length)

    val empty: String? = null
    // 实际为 null，断言失败抛出 NullPointerException
    val result = runCatching { empty!!.length }
    println(result.exceptionOrNull()?.javaClass?.name)
}
```

运行结果：

```text
6
java.lang.NullPointerException
```

| 写法 | 行为 | 使用建议 |
| --- | --- | --- |
| a?.b | a 为 null 时返回 null | 最常用，链式访问首选 |
| a ?: b | a 为 null 时取 b | 提供默认值、提前返回或抛异常 |
| a!!.b | a 为 null 时抛 NPE | 只在逻辑上绝对不可能为 null 时使用 |
| a as? T | 转换失败时返回 null | 类型不确定的安全转换 |

> **建议：**能用 `?.` 和 `?:` 解决的问题就不要用 `!!`。`!!` 应该只出现在确实已经完成判空、但编译器无法感知的场景。

---

## 安全调用与 let

`?.` 只能返回 null 或调用结果，如果需要对非空值做一段操作，惯用法是配合 `let`。

`a?.let { }` 表示 a 非空时执行 lambda，参数 `it` 就是智能转换后的非空值。

**实例**

```kotlin
fun main() {
    val email: String? = "runoob@www.runoob.com"
    val missing: String? = null

    // 非空才执行，it 已经是 String 而不是 String?
    email?.let { println("发送邮件到 $it") }
    missing?.let { println("发送邮件到 $it") }

    // 等价的 if 判空写法，Kotlin 会自动智能转换
    if (email != null) {
        println("长度：${email.length}")
    }
}
```

运行结果：

```text
发送邮件到 runoob@www.runoob.com
长度：21
```

智能转换（smart cast）是 Kotlin 的另一项能力：一旦在分支里完成判空，编译器就把它当作非空类型，无需再写 `!!`。

---

## 安全转换 as?

强制转换 `as` 在类型不匹配时会抛 `ClassCastException`。

安全转换 `as?` 则在失败时返回 null，适合处理类型不确定的输入。

**实例**

```kotlin
fun describe(value: Any): String {
    // 转换失败返回 null，不会抛异常
    val text = value as? String
    val number = value as? Int
    return "String=$text, Int=$number"
}

fun main() {
    println(describe("RUNOOB"))
    println(describe(42))
    println(describe(3.14))
}
```

运行结果：

```text
String=RUNOOB, Int=null
String=null, Int=42
String=null, Int=null
```

与之配套的还有 `is` 判断，判断成功后同样会触发智能转换。

**实例**

```kotlin
fun lengthOf(value: Any): Int {
    // is 判断之后，value 在本分支内被智能转换为 String
    return if (value is String) value.length else -1
}

fun main() {
    println(lengthOf("Runoob"))
    println(lengthOf(100))
}
```

运行结果：

```text
6
-1
```

---

## 平台类型与 Java 互操作

Kotlin 调用没有空安全注解的 Java 方法时，返回类型会变成平台类型，写作 `String!`。

平台类型的意思是"编译器不知道它是否可能为 null"，因此既允许赋给非空类型，也允许赋给可空类型。

先看 Java 侧的代码。

**实例**

```kotlin
// 文件路径：Site.java
public class Site {
    // 没有 @Nullable / @NotNull 注解，Kotlin 无法判断返回值是否可空
    public static String getName() {
        return null;
    }
}
```

Kotlin 侧把返回值赋给非空类型时不会报错，但运行时会触发空检查。

**实例**

```kotlin
fun main() {
    val result = runCatching {
        // Site.getName() 是平台类型 String!，编译通过
        val name: String = Site.getName()
        name.length
    }
    println("捕获到异常：${result.exceptionOrNull()?.javaClass?.name}")
    println("异常信息：${result.exceptionOrNull()?.message}")
}
```

运行结果：

```text
捕获到异常：java.lang.NullPointerException
异常信息：getName(...) must not be null
```

> **风险提示：**平台类型是空安全体系的漏洞所在。处理 Java 返回值时，除非有 `@NotNull` 注解或明确的文档保证，否则一律当作可空类型处理。

推荐的写法是显式声明为可空类型，再用 Elvis 或安全调用兜底。

**实例**

```kotlin
fun main() {
    // 主动声明为 String?，把判断权交回给编译器
    val name: String? = Site.getName()
    println("站点名称：${name ?: "未命名"}")

    // 也可以交给安全调用与 Elvis 处理
    println("名称长度：${name?.length ?: 0}")
}
```

运行结果：

```text
站点名称：未命名
名称长度：0
```

---

## lateinit 延迟初始化

有时属性无法在构造阶段确定值，比如由框架注入或在 `onCreate` 中赋值，这时可以用 `lateinit`。

它告诉编译器"我保证在第一次访问前完成赋值"，如果访问时还没赋值，会抛出 `UninitializedPropertyAccessException`。

**实例**

```kotlin
class UserService {
    // lateinit 只能修饰 var，不能修饰基本类型，也不能是可空类型
    lateinit var siteName: String

    fun init(name: String) {
        siteName = name
    }

    fun printInfo() {
        // 用 ::属性名.isInitialized 判断是否已初始化
        if (::siteName.isInitialized) {
            println("站点：$siteName")
        } else {
            println("站点尚未初始化")
        }
    }
}

fun main() {
    val service = UserService()
    service.printInfo()
    service.init("www.runoob.com")
    service.printInfo()
}
```

运行结果：

```text
站点尚未初始化
站点：www.runoob.com
```

`lateinit` 常和 `by lazy` 一起比较，两者解决的是不同问题。

| 对比项 | lateinit var | by lazy |
| --- | --- | --- |
| 适用变量 | var | val |
| 适用类型 | 非空引用类型，不支持 Int 等基本类型 | 任意类型 |
| 初始化方式 | 手动赋值 | 首次访问时自动计算 |
| 线程安全 | 不保证 | 默认 LazyThreadSafetyMode.SYNCHRONIZED |
| 检查是否初始化 | 支持 ::prop.isInitialized | 不支持 |
| 典型场景 | 依赖注入、框架生命周期回调 | 昂贵的初始化、只读配置 |

---

## 集合与泛型的可空性

集合本身是否可空，和集合元素是否可空，是两个独立的维度，可以自由组合。

`List<String>` 表示非空列表装非空元素，`List<String?>` 表示非空列表装可空元素，`List<String>?` 表示可空列表装非空元素。

**实例**

```kotlin
fun main() {
    val names: List<String> = listOf("Runoob", "RUNOOB")
    val maybeNames: List<String>? = null
    val namesWithNull: List<String?> = listOf("Runoob", null, "RUNOOB")

    println(names.size)
    println(maybeNames?.size)
    println(namesWithNull.size)
    println(namesWithNull[1])          // 元素是 String?，输出 null

    // Map 取值返回可空类型，键不存在时就是 null
    val scores = mapOf("Runoob" to 90)
    println(scores["RUNOOB"])
    println(scores["RUNOOB"] ?: 0)

    // filterNotNull 过滤掉 null 元素，返回 List<String>
    val cleaned: List<String> = namesWithNull.filterNotNull()
    println(cleaned)
}
```

运行结果：

```text
2
null
3
null
null
0
[Runoob, RUNOOB]
```

常见的"取不到就返回 null"的 API 还有 `getOrNull`、`firstOrNull`、`lastOrNull`、`singleOrNull`，它们比抛异常的版本更适合空安全风格。

---

## 常见问题

用了空安全，Kotlin 程序就不会再有 NullPointerException 了吗？

不是。平台类型、`!!`、`lateinit` 未初始化、反射和泛型擦除这几条路径依然可能产生 NPE，只是它们都属于可以主动避免的少数情况。

什么时候该用 `!!`，什么时候该用 `?:`？

逻辑上可能为 null 时用 `?:` 给默认值或抛业务异常；只有在已经通过其他方式保证非空、但编译器无法推断时才用 `!!`。

可空类型能用 `==` 和 null 比较吗？

可以，`x == null` 是合法的，也是最直观的判空写法。`equals` 的翻译规则专门处理了 null 的情况。

`lateinit` 为什么不能修饰基本类型？

因为基本类型在 JVM 上有默认值（如 Int 默认 0），无法区分"未初始化"和"值为 0"，所以只能用引用类型。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-null-safety.html)，版权归原作者所有，仅供非商业学习使用。
