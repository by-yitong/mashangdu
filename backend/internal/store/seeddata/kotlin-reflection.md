反射是指在运行时检查类、函数、属性等程序结构，并且可以动态调用它们的能力。

Kotlin 提供了一套自己的反射 API，通过 `kotlin-reflect` 库使用，比 Java 反射更简洁，还能保留可空性、属性等 Kotlin 特有的信息。

---

## 什么是反射

正常情况下，我们写的代码在编译期就确定了要调用哪个函数、访问哪个属性。

反射打破了这一点：程序在运行时才知道自己要操作的对象是谁。

举例来说，配置文件里写了一个方法名 `save`，程序读进来之后通过反射找到并调用它，代码里不需要写死 `obj.save()`。

常见的使用场景有依赖注入框架、序列化库、测试工具、脚本引擎等。

业务代码里很少需要直接写反射，但理解它能帮你读懂这些框架的内部行为。

### 使用代价

反射很强大，代价也不小，不要为了「看起来灵活」而滥用。

| 代价 | 说明 |
| --- | --- |
| 运行库体积 | `kotlin-reflect` 会给程序增加约 2.5 MB 的依赖 |
| 运行性能 | 反射调用比直接调用慢，按名字查找的开销尤其明显 |
| 类型安全 | 方法名写成字符串，拼错要等到运行时才报错 |
| 代码混淆 | R8、ProGuard 可能重命名或删除被反射访问的成员，导致运行失败 |
| 可维护性 | IDE 无法跳转和重构，也会破坏类的封装 |

> **提示：**能用普通代码表达的逻辑就不要用反射。只有当「调用方在编译期确实不知道要操作谁」时，反射才是合理选择。

---

## KClass 与 ::class

Kotlin 用 `KClass` 表示一个类的运行时信息，通过 `::class` 获取。

KClass 是 Kotlin 自己的类型，它能告诉你类的简单名、限定名，也能知道属性是否可空。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.KClass

// 定义一个示例类
class Runoob(val name: String, var age: Int)

fun main() {
    // 类名 ::class 得到 KClass 对象
    val kClass: KClass<Runoob> = Runoob::class
    println("简单名: ${kClass.simpleName}")
    println("限定名: ${kClass.qualifiedName}")

    // 通过实例也能拿到 KClass，类型和上面完全一样
    val site = Runoob("RUNOOB", 10)
    println("实例的类: ${site::class.simpleName}")
    println("是同一个对象: ${site::class == Runoob::class}")
}
```

实例执行输出结果为：

```text
简单名: Runoob
限定名: com.runoob.Runoob
实例的类: Runoob
是同一个对象: true
```

注意 `KClass` 是泛型类型，`KClass<Runoob>` 表示它描述的是 Runoob 这个类。

泛型参数写在尖括号里，KClass 本身也带类型参数，这样调用方就能拿到具体类型。

### ::class.java 与 Class.kotlin

JVM 平台上，Kotlin 的 KClass 和 Java 的 `Class` 可以互相转换。

调用 `::class.java` 拿到 Java 的 Class 对象，再用 `Class.kotlin` 转回来。

**实例**

```kotlin
package com.runoob

class Runoob(val name: String)

fun main() {
    // KClass -> Class
    val javaClass: Class<Runoob> = Runoob::class.java
    println("Java 类名: ${javaClass.name}")

    // Class -> KClass
    val back = javaClass.kotlin
    println("转回 KClass: ${back.simpleName}")
}
```

实例执行输出结果为：

```text
Java 类名: com.runoob.Runoob
转回 KClass: Runoob
```

KClass 的 `simpleName`、`qualifiedName`、`java` 由标准库直接支持，不需要额外依赖。

枚举成员、调用函数、创建实例等更强的功能，则需要引入 kotlin-reflect。

---

## KFunction 与函数引用

把函数当作值来传递时，得到的是函数引用，它的类型是 `KFunction` 的子类型。

例如两个参数的函数，引用类型是 `KFunction2<P1, P2, R>`，泛型参数依次是参数类型和返回类型。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.KFunction2

// 顶层函数
fun add(a: Int, b: Int): Int = a + b

class Calculator {
    fun multiply(a: Int, b: Int): Int = a * b
}

fun main() {
    // 顶层函数的引用，类型是 KFunction2<Int, Int, Int>
    val f: KFunction2<Int, Int, Int> = ::add
    println("函数名: ${f.name}")
    println("参数个数: ${f.parameters.size}")

    // 直接调用是编译期绑定的，不经过反射，性能接近普通函数调用
    println("直接调用: ${f(3, 4)}")

    // call 才是真正的反射调用，参数按位置依次传入
    println("call 调用: ${f.call(3, 4)}")

    // 成员函数引用要先有实例
    val calc = Calculator()
    val m = calc::multiply
    println("成员函数名: ${m.name}")
    println("call 调用: ${m.call(5, 6)}")
}
```

实例执行输出结果为：

```text
函数名: add
参数个数: 2
直接调用: 7
call 调用: 7
成员函数名: multiply
call 调用: 30
```

> **提示：**函数引用 `::add` 本身不是「重反射」。`f(3, 4)` 会被编译器优化成直接调用；只有 `f.call(3, 4)` 才走反射路径。所以能用 `invoke` 就不要用 `call`。

如果不想记参数顺序，可以用 `callBy` 按参数名传值，参数对象从 `parameters` 里取。

**实例**

```kotlin
package com.runoob

fun add(a: Int, b: Int): Int = a + b

fun main() {
    val f = ::add
    // 用参数名传值，顺序可以打乱
    val args = mapOf(f.parameters[1] to 4, f.parameters[0] to 3)
    println("callBy: ${f.callBy(args)}")
}
```

实例执行输出结果为：

```text
callBy: 7
```

函数引用的类型是 `KFunction`，而普通 lambda 是 `FunctionN` 类型，两者不能直接互相赋值。

---

## KProperty 与属性引用

用 `类名::属性名` 可以得到属性引用，类型是 `KProperty1<T, R>`。

其中 T 是接收者类型，R 是属性类型；如果属性是 `var`，类型会变成 `KMutableProperty1`，可以写值。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.KMutableProperty1
import kotlin.reflect.KProperty1

class User(val name: String, var age: Int)

fun main() {
    val user = User("RUNOOB", 10)

    // val 属性得到 KProperty1，只能读
    val nameProp: KProperty1<User, String> = User::name
    println("属性名: ${nameProp.name}")
    println("读取 name: ${nameProp.get(user)}")

    // var 属性得到 KMutableProperty1，可以读也可以写
    val ageProp: KMutableProperty1<User, Int> = User::age
    println("读取 age: ${ageProp.get(user)}")
    ageProp.set(user, 20)
    println("写入后 age: ${user.age}")
}
```

实例执行输出结果为：

```text
属性名: name
读取 name: RUNOOB
读取 age: 10
写入后 age: 20
```

顶层属性或对象属性的接收者不是某个实例，得到的是 `KProperty0<R>`，调用 `get()` 时不需要传接收者。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.KProperty0

// 顶层属性
val siteName: String = "www.runoob.com"

object Config {
    val version: String = "Kotlin 2.2"
}

fun main() {
    val p1: KProperty0<String> = ::siteName
    println("${p1.name} = ${p1.get()}")

    val p2: KProperty0<String> = Config::version
    println("${p2.name} = ${p2.get()}")
}
```

实例执行输出结果为：

```text
siteName = www.runoob.com
version = Kotlin 2.2
```

---

## 通过反射调用函数与读写属性

实际使用反射时，我们通常先遍历出所有成员，再按名字查找目标。

下面这个例子把对象的属性和函数都列了出来，并按名字找到 `greet` 调用。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.KProperty1
import kotlin.reflect.full.declaredMemberFunctions
import kotlin.reflect.full.memberProperties

class Runoob(val name: String, var age: Int) {
    fun greet(): String = "欢迎来到 $name"
}

fun main() {
    val site = Runoob("RUNOOB", 10)
    val kClass = site::class

    // memberProperties 包含父类属性，Any 本身没有属性，所以就是这两个
    println("成员属性：")
    for (prop in kClass.memberProperties.sortedBy { it.name }) {
        // memberProperties 的元素类型带 out 投影，直接调用 get 会被禁止，需要先转成具体类型
        @Suppress("UNCHECKED_CAST")
        val p = prop as KProperty1<Runoob, *>
        println("  ${p.name} = ${p.get(site)}")
    }

    // declaredMemberFunctions 只包含本类声明的函数
    println("本类声明的函数：")
    for (func in kClass.declaredMemberFunctions.sortedBy { it.name }) {
        println("  ${func.name}")
    }

    // 按名字找到函数并调用
    val greet = kClass.declaredMemberFunctions.first { it.name == "greet" }
    println("调用 greet(): ${greet.call(site)}")
}
```

实例执行输出结果为：

```text
成员属性：
  age = 10
  name = RUNOOB
本类声明的函数：
  greet
调用 greet(): 欢迎来到 RUNOOB
```

`memberProperties` 返回集合的顺序不保证稳定，所以例子里加了 `sortedBy`。

如果只想看类自己声明的成员，用 `declaredMemberProperties` 和 `declaredMemberFunctions`，它们不会带上父类的成员。

> **注意：**`memberProperties`、`memberFunctions`、`call` 这些 API 都在 kotlin-reflect 里，没有引入依赖会抛出 `KotlinReflectionNotSupportedError`。

---

## createInstance 创建实例

`KClass.createInstance()` 可以调用无参构造器创建一个实例，Kotlin 1.1 起提供。

它要求类必须有一个无参构造器，或者所有参数都有默认值，否则会抛异常。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.full.createInstance

class Runoob {
    val siteName: String = "RUNOOB"
    override fun toString(): String = "Runoob 实例"
}

fun main() {
    val instance = Runoob::class.createInstance()
    println(instance)
    println(instance.siteName)
}
```

实例执行输出结果为：

```text
Runoob 实例
RUNOOB
```

如果类需要参数，就用 `primaryConstructor` 拿到构造器，再调用 `call`。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.full.primaryConstructor

class Site(val name: String, val url: String)

fun main() {
    // 拿到主构造器，再按顺序传参调用
    val ctor = Site::class.primaryConstructor!!
    val site = ctor.call("RUNOOB", "www.runoob.com")
    println("${site.name} -> ${site.url}")
}
```

实例执行输出结果为：

```text
RUNOOB -> www.runoob.com
```

---

## kotlin-reflect 依赖

完整反射功能需要单独引入 `kotlin-reflect`，它不在标准库中。

用 Gradle 的 Kotlin DSL 时，可以用 `kotlin("reflect")` 让插件自动匹配版本。

**实例**

```kotlin
// 文件路径：build.gradle.kts
plugins {
    kotlin("jvm") version "2.2.0"
}

dependencies {
    // kotlin("reflect") 会自动使用与 Kotlin 插件一致的版本
    implementation(kotlin("reflect"))

    // 也可以写死坐标，注意版本要和 Kotlin 编译器保持一致
    // implementation("org.jetbrains.kotlin:kotlin-reflect:2.2.0")
}
```

用 Maven 时，坐标是 `org.jetbrains.kotlin:kotlin-reflect`。

**实例**

```xml
<!-- 文件路径：pom.xml -->
<dependency>
    <groupId>org.jetbrains.kotlin</groupId>
    <artifactId>kotlin-reflect</artifactId>
    <version>2.2.0</version>
</dependency>
```

> **提示：**kotlin-reflect 的版本必须和编译时使用的 Kotlin 版本一致，否则可能在运行时抛出版本不匹配的异常。在线工具 play.kotlinlang.org 已经内置了这个库，可以直接运行上面的例子。

---

## 反射 vs Java 反射

Kotlin 反射建立在 Java 反射之上，但对外暴露的 API 更贴合 Kotlin 的语义。

| 对比项 | Kotlin 反射 | Java 反射 |
| --- | --- | --- |
| 入口 | `obj::class` 得到 KClass | `obj.javaClass` 得到 Class |
| 额外依赖 | 完整功能需要 kotlin-reflect | JDK 自带 |
| 函数调用 | `KFunction.call(...)` | `Method.invoke(...)` |
| 属性支持 | 属性是一等公民，`KProperty` 可直接读写 | 只能分别找 getter 和 setter |
| 可空性 | `KType.isMarkedNullable` 能读到 | 看不到，只能靠注解 |
| 类型安全 | `KProperty1<T, R>` 带泛型 | 统一返回 Object，需要强转 |

Java 反射要靠字符串加载类，例如 `Class.forName("com.runoob.Runoob")`，编译期完全无法检查。

Kotlin 也保留了这条路，但推荐优先用 `::class`，这样至少类名是编译期检查过的。

**实例**

```kotlin
package com.runoob

import java.lang.reflect.Method

class Runoob(val name: String) {
    fun greet(): String = "欢迎来到 $name"
}

fun main() {
    // Java 风格：用字符串加载类，写错要到运行时才发现
    val clazz = Class.forName("com.runoob.Runoob")
    val ctor = clazz.getConstructor(String::class.java)
    val instance = ctor.newInstance("RUNOOB")

    // 按方法名和参数类型查找
    val method: Method = clazz.getMethod("greet")
    println(method.invoke(instance))
}
```

实例执行输出结果为：

```text
欢迎来到 RUNOOB
```

Kotlin 反射还有一个 Java 反射做不到的能力：判断一个类型是不是可空。

**实例**

```kotlin
package com.runoob

import kotlin.reflect.full.memberProperties

class Profile(val name: String, val nickname: String?)

fun main() {
    for (prop in Profile::class.memberProperties.sortedBy { it.name }) {
        val type = prop.returnType
        println("${prop.name}: ${type}，可空 = ${type.isMarkedNullable}")
    }
}
```

实例执行输出结果为：

```text
name: kotlin.String，可空 = false
nickname: kotlin.String?，可空 = true
```

---

## 常见问题

下面几个问题在初学反射时出现频率最高。

### KotlinReflectionNotSupportedError

说明运行时没有 kotlin-reflect。在 `build.gradle.kts` 里加上 `implementation(kotlin("reflect"))` 即可。

### ::class 和 ::class.java 有什么区别

`::class` 得到 Kotlin 的 KClass，能读取可空性等 Kotlin 语义；`::class.java` 得到 Java 的 Class，主要用于调用 Java 生态的 API。

### 函数引用和反射调用哪个快

函数引用直接 invoke 是编译期绑定的，性能和普通函数调用接近；`call` 和按名字查找才走反射，性能开销明显。

### createInstance 报 no argument constructor 错误

目标类没有无参构造器。给参数加上默认值，或者改用 `primaryConstructor` 加 `call` 传参。

### 反射修改了 private 属性会怎样

JVM 上可以通过 `isAccessible = true` 绕过访问检查，但这会破坏封装，也会让代码在开启模块系统或混淆后失效，生产代码里不建议这么做。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-reflection.html)，版权归原作者所有，仅供非商业学习使用。
