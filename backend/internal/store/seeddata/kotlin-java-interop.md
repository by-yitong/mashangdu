Kotlin 从设计之初就把「和 Java 无缝互操作」当作核心目标，两者编译后都运行在 JVM 上，可以直接互相调用。

本章节介绍两个方向调用时的规则、平台类型带来的空安全风险，以及让 Java 调用更友好的几个注解。

---

## Kotlin 调用 Java

Kotlin 可以直接使用任何 Java 类，不需要额外的包装。

Kotlin 还对 Java 的 getter 和 setter 做了语法糖：`person.getName()` 可以直接写成 `person.name`。

先看一个普通的 Java 类。

**实例**

```kotlin
// 文件路径：Person.java
public class Person {
    private String name;          // 私有字段
    private int age;

    public Person(String name, int age) {
        this.name = name;
        this.age = age;
    }

    // Java 的 getter / setter
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public int getAge() { return age; }
    public void setAge(int age) { this.age = age; }

    // 静态方法
    public static String welcome(String site) {
        return "欢迎来到 " + site;
    }
}
```

在 Kotlin 中调用这个类时，getter 和 setter 可以省略写法。

**实例**

```kotlin
// 文件路径：Main.kt
fun main() {
    val person = Person("RUNOOB", 10)

    // 调用 Java getter 时可以直接用属性语法
    println(person.name)              // 等价于 person.getName()
    println(person.age)               // 等价于 person.getAge()

    // 调用 Java setter 也可以直接用属性赋值
    person.age = 20                   // 等价于 person.setAge(20)
    println("修改后：${person.age}")

    // 静态方法按 Java 的写法调用
    println(Person.welcome("www.runoob.com"))
}
```

实例执行输出结果为：

```text
RUNOOB
10
修改后：20
欢迎来到 www.runoob.com
```

Java 的静态成员在 Kotlin 里也是静态调用，写法完全一致。

Java 的受检异常 Kotlin 不强制捕获，Kotlin 把异常都当作非受检异常处理。

---

## Java 调用 Kotlin

反过来，Java 调用 Kotlin 时需要注意 Kotlin 特有结构在 JVM 上的呈现方式。

顶层函数会放进一个名为「文件名 + Kt」的类，伴生对象成员要通过 `Companion` 访问。

**实例**

```kotlin
// 文件路径：Runoob.kt
class Runoob {
    companion object {
        // 没有 @JvmStatic，Java 必须写 Runoob.Companion.currentVersion()
        fun currentVersion(): String = "Kotlin 2.2"

        // 加了 @JvmStatic，Java 可以直接写 Runoob.staticVersion()
        @JvmStatic
        fun staticVersion(): String = "Kotlin 2.2"

        // const val 会生成静态常量字段
        const val SITE: String = "www.runoob.com"
    }
}

// 顶层函数会生成 RunoobKt 类（文件名 + Kt）
fun topLevelHello(): String = "来自顶层函数的问候"
```

对应的 Java 调用代码如下。

**实例**

```kotlin
// 文件路径：Main.java
public class Main {
    public static void main(String[] args) {
        System.out.println(Runoob.Companion.currentVersion()); // 伴生对象要经过 Companion
        System.out.println(Runoob.staticVersion());            // @JvmStatic 变成静态方法
        System.out.println(Runoob.SITE);                       // const val 是静态字段
        System.out.println(RunoobKt.topLevelHello());          // 顶层函数在 RunoobKt 中
    }
}
```

运行输出结果为：

```text
Kotlin 2.2
Kotlin 2.2
www.runoob.com
来自顶层函数的问候
```

Kotlin 的 `object` 单例在 JVM 上有一个静态字段 `INSTANCE`，Java 要写成 `Runoob.INSTANCE.foo()`。

如果想改掉「文件名 + Kt」这个类名，可以用文件级注解 `@file:JvmName`。

**实例**

```kotlin
// 文件路径：Utils.kt
@file:JvmName("RunoobUtils")        // 文件注解必须写在 package 之前

package com.runoob

fun version(): String = "Kotlin 2.2"
```

这样 Java 里就可以写 `RunoobUtils.version()`，而不是 `UtilsKt.version()`。

---

## 平台类型与空安全风险

Java 的类型系统没有可空性信息，Kotlin 把这种「可能是空也可能不是空」的类型叫做平台类型，写作 `String!`。

平台类型可以被赋给非空类型，也可以被赋给可空类型，编译器不做检查，风险就藏在这里。

**实例**

```kotlin
// 文件路径：MessageService.java
public class MessageService {
    // 没有标注 @Nullable / @NotNull，返回值是平台类型 String!
    public String getMessage() {
        return null;              // 运行时可能返回 null
    }
}
```

如果 Kotlin 直接把它当作非空类型使用，编译能通过，运行时会抛空指针。

**实例**

```kotlin
// 文件路径：Main.kt
fun main() {
    val service = MessageService()

    // 声明为可空类型，强制自己做判空，这是推荐写法
    val message: String? = service.message
    println("内容：$message")
    println("长度：${message?.length ?: 0}")
}
```

实例执行输出结果为：

```text
内容：null
长度：0
```

> **注意：**如果把上面写成 `val message: String = service.message`，编译器不会报错，但运行到 `message.length` 时会抛 `NullPointerException`。所以调用没有空标注的 Java 代码时，主动把返回值声明成可空类型更安全。

如果 Java 侧使用了 JSR-305 的 `@Nullable` 或 `@NotNull`，或者 Android 的 `androidx.annotation` 系列注解，Kotlin 会识别它们并生成真正的可空类型。

| Java 侧写法 | Kotlin 看到的类型 | 空安全 |
| --- | --- | --- |
| 无注解的 `String` | `String!`（平台类型） | 不检查，风险最高 |
| `@Nullable String` | `String?` | 编译器强制判空 |
| `@NotNull String` | `String` | 当作非空处理 |

---

## 常用互操作注解

Kotlin 提供了一组 `@Jvm` 开头的注解，用来控制生成的 JVM 字节码，让 Java 调用更自然。

| 注解 | 作用 | 可用位置 |
| --- | --- | --- |
| `@JvmStatic` | 在伴生对象或 object 中生成真正的静态成员 | 函数、属性 |
| `@JvmField` | 属性直接暴露为字段，不再生成 getter/setter | 有 backing field 的属性 |
| `@JvmOverloads` | 为带默认值的参数生成多个重载 | 函数、构造器 |
| `@JvmName` | 修改生成的 JVM 名字 | 函数、访问器、文件 |
| `@Throws` | 在字节码中声明受检异常 | 函数、构造器、属性访问器 |

下面这个例子把几个常用注解放在一起演示。

**实例**

```kotlin
// 文件路径：Config.kt
import java.io.IOException

class Config {
    // @JvmField：Java 直接访问字段 config.timeout
    @JvmField
    val timeout: Int = 3000

    // 普通 val：Java 要通过 getPort() 访问
    val port: Int = 8080
}

class Formatter {
    // @JvmOverloads：为默认参数生成 1 个、2 个、3 个参数的重载
    @JvmOverloads
    fun format(text: String, prefix: String = "[RUNOOB] ", upper: Boolean = false): String {
        val result = prefix + text
        return if (upper) result.uppercase() else result
    }

    // @Throws：让 Java 看到受检异常，调用时必须 try/catch
    @Throws(IOException::class)
    fun readConfig(path: String): String {
        if (path.isEmpty()) throw IOException("路径不能为空")
        return "读取成功：$path"
    }
}

// @JvmName：修改生成的 JVM 方法名
@JvmName("greetFromKotlin")
fun greet(name: String): String = "你好，$name"
```

Java 侧的调用效果如下。

**实例**

```kotlin
// 文件路径：Main.java
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        Config config = new Config();
        System.out.println(config.timeout);      // @JvmField：直接访问字段
        System.out.println(config.getPort());    // 普通属性：走 getter

        Formatter formatter = new Formatter();
        System.out.println(formatter.format("hello"));                     // 1 个参数
        System.out.println(formatter.format("hello", "kotlin "));          // 2 个参数
        System.out.println(formatter.format("hello", "kotlin ", true));    // 3 个参数
        System.out.println(formatter.readConfig("runoob.conf"));
        System.out.println(ConfigKt.greetFromKotlin("RUNOOB"));            // @JvmName 后的名字
    }
}
```

运行输出结果为：

```text
3000
8080
[RUNOOB] hello
kotlin hello
KOTLIN HELLO
读取成功：runoob.conf
你好，RUNOOB
```

> **提示：**`@JvmField` 的使用有条件：属性必须有 backing field，不能是 `private`，也不能是 `open`、`override` 或 `const`。

---

## 属性与 getter/setter 的映射规则

Kotlin 的属性在 JVM 上并不直接存在，编译器会为它生成私有字段和访问器。

![Kotlin 与 Java 的双向映射：属性映射为 getter 和 setter，默认参数需要 JvmOverloads，顶层函数生成 FileKt 静态方法，companion object 成员需要 JvmStatic 才是静态方法](images/kotlin/kotlin-java-interop/35-java-interop.svg)

记住这张映射表，就能推断出 Java 侧该用什么写法。

| Kotlin 声明 | 生成的 JVM 成员 | Java 访问方式 |
| --- | --- | --- |
| `val name: String` | 私有字段 + `getName()` | `obj.getName()` |
| `var name: String` | 私有字段 + `getName()` / `setName()` | `obj.setName("x")` |
| `val isOpen: Boolean` | `isOpen()` | `obj.isOpen()` |
| `var isOpen: Boolean` | `isOpen()` / `setOpen()` | `obj.setOpen(true)` |
| `@JvmField val name: String` | 公有字段 `name` | `obj.name` |
| 伴生对象里的 `@JvmStatic fun foo()` | 静态方法 `foo()` | `Runoob.foo()` |
| `object Runoob` | 单例 + 静态字段 `INSTANCE` | `Runoob.INSTANCE.foo()` |

布尔属性以 `is` 开头时，getter 不会再加 `get` 前缀，直接就是属性名本身。

如果只是想改访问器的名字，而不是把整个属性变成字段，可以用 `@get:JvmName` 和 `@set:JvmName`。

**实例**

```kotlin
// 文件路径：Site.kt
class Site {
    // 只改 getter 的名字，Java 侧用 getSiteUrl()
    @get:JvmName("getSiteUrl")
    val url: String = "www.runoob.com"

    // 布尔属性，Java 侧是 isActive()
    val isActive: Boolean = true
}
```

---

## 默认参数与 Java 重载

Java 没有默认参数的概念，Kotlin 函数带默认值时，Java 必须把参数全部传齐。

编译器会为默认参数生成一个带 `$default` 后缀的合成方法，但 Java 直接调用它很别扭。

**实例**

```kotlin
// 文件路径：Greeter.kt
class Greeter {
    // 没有 @JvmOverloads：Java 只能写 greeter.greet("RUNOOB", "你好，")
    fun greet(name: String, prefix: String = "你好，"): String = "$prefix$name"

    // 有 @JvmOverloads：Java 可以只传 name
    @JvmOverloads
    fun greetShort(name: String, prefix: String = "你好，"): String = "$prefix$name"
}
```

加注解后，Java 侧可以按不同参数个数调用，就像普通的重载方法一样。

**实例**

```kotlin
// 文件路径：Main.java
public class Main {
    public static void main(String[] args) {
        Greeter greeter = new Greeter();
        System.out.println(greeter.greet("RUNOOB", "你好，"));
        System.out.println(greeter.greetShort("RUNOOB"));
        System.out.println(greeter.greetShort("RUNOOB", "欢迎，"));
    }
}
```

运行输出结果为：

```text
你好，RUNOOB
你好，RUNOOB
欢迎，RUNOOB
```

> **注意：**`@JvmOverloads` 会为每一个默认参数生成一个重载，参数很多时会显著增加方法数量。参数超过三四个时，考虑改成 Builder 模式或配置对象。

---

## SAM 转换

SAM 转换是指把 lambda 直接当作只有一个抽象方法的接口实现。

Java 的函数式接口在 Kotlin 里天然支持这种写法，例如 `Runnable`、`Comparator`、`Callable`。

**实例**

```kotlin
// 文件路径：Task.java
public interface Task {
    void run(String name);        // 只有一个抽象方法
}
```

Kotlin 侧可以直接用 lambda 实现这个接口。

**实例**

```kotlin
// 文件路径：Main.kt

fun execute(task: Task) {
    task.run("RUNOOB")
}

// Kotlin 1.4 起可以用 fun interface 声明函数式接口
fun interface Printer {
    fun print(text: String)
}

fun main() {
    // Java 接口在 Kotlin 中直接传 lambda
    execute { name -> println("执行任务：$name") }

    // Kotlin 自己的 fun interface 同样支持 SAM 转换
    val printer = Printer { text -> println(text) }
    printer.print("www.runoob.com")
}
```

实例执行输出结果为：

```text
执行任务：RUNOOB
www.runoob.com
```

Kotlin 1.4 之前，只有 Java 接口支持 SAM 转换，Kotlin 接口必须写成对象表达式。

反方向的场景要注意：Java 调用 Kotlin 的 `() -> Unit` 参数时，看到的是 `Function0<Unit>`，需要显式实现。

**实例**

```kotlin
// 文件路径：Runner.kt
// Java 调用时只能传 Function0<Unit>，不太友好
fun runKotlinStyle(action: () -> Unit) {
    action()
}
```

**实例**

```kotlin
// 文件路径：Main.java
import kotlin.Unit;
import kotlin.jvm.functions.Function0;

public class Main {
    public static void main(String[] args) {
        // Java 必须显式实现 Function0，还要 return Unit.INSTANCE
        RunnerKt.runKotlinStyle(new Function0<Unit>() {
            @Override
            public Unit invoke() {
                System.out.println("来自 Java 的调用");
                return Unit.INSTANCE;
            }
        });
    }
}
```

运行输出结果为：

```text
来自 Java 的调用
```

> **提示：**如果某个 API 主要给 Java 调用，把参数类型声明成 Java 的函数式接口（例如 `Runnable`）或 Kotlin 的 `fun interface`，Java 侧就能直接写 lambda，体验好很多。

---

## 版本说明

互操作相关的注解大多从 Kotlin 1.0 就已经存在，少数特性是后来补充的。

| 特性 | 起始版本 | 说明 |
| --- | --- | --- |
| `@JvmStatic` / `@JvmField` / `@JvmOverloads` | Kotlin 1.0 起 | 基础的 JVM 互操作注解 |
| `@JvmName` / `@Throws` | Kotlin 1.0 起 | 改名与受检异常声明 |
| `fun interface` 与 SAM 转换 | Kotlin 1.4 起 | Kotlin 接口也能用 lambda 实现 |
| `@JvmRecord` | Kotlin 1.5 起 | 生成 Java 的 record 类型 |
| `-jvm-default` 选项 | Kotlin 2.2 起稳定 | 控制接口默认方法如何生成 JVM 默认方法 |

---

## 常见问题

下面几个问题在实际项目中经常遇到。

### Java 侧找不到 Kotlin 的函数

先确认是不是顶层函数，它在「文件名 + Kt」类里；如果函数带默认参数，Java 还要把参数传齐，或者给函数加 `@JvmOverloads`。

### 为什么 Java 访问 Kotlin 属性要加 get

Kotlin 的 `val name` 会生成 `getName()`。想直接访问字段就加 `@JvmField`，想改名字就用 `@get:JvmName`。

### 伴生对象成员为什么不能直接调用

伴生对象是一个名为 `Companion` 的静态实例，Java 要通过它访问；加 `@JvmStatic` 后才会生成真正的静态方法。

### Kotlin 调用 Java 时受检异常去哪了

Kotlin 没有受检异常，Java 抛出的受检异常在 Kotlin 里和其他异常一样，需要自己 try/catch，编译器不强制。

### 平台类型能不能完全避免

不能。只要调用的 Java 代码没有空标注，就会产生平台类型。做法是尽量把返回值显式声明成可空类型，或者推动 Java 侧补上注解。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-java-interop.html)，版权归原作者所有，仅供非商业学习使用。
