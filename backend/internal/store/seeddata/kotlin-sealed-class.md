密封类用来表示一个受限的类层次：某个值的所有可能类型在编译期就完全确定。

正因为子类是已知的有限集合，when 表达式才能在没有 else 的情况下通过穷尽性检查。

它常用于状态机、接口返回结果、事件类型这类「只有这几种情况」的建模。

---

## 密封类的定义

用 sealed 修饰的类就是密封类，它本身是抽象的，不能直接实例化。

密封类的构造器默认是 protected，只有它的子类能够继承。

**实例**

```kotlin
// 文件：RunoobResult.kt
sealed class RunoobResult

// 子类与密封类写在同一个文件中
data class Success(val data: String) : RunoobResult()
data class Failure(val message: String) : RunoobResult()
object Loading : RunoobResult()

fun main() {
    val result: RunoobResult = Success("www.runoob.com")
    println(result)

    // RunoobResult()   // 编译错误：密封类不能直接实例化
}
```

```text
Success(data=www.runoob.com)
```

子类可以是普通类、数据类或 object，形态没有限制。

这也意味着每个子类可以携带完全不同的数据，这是密封类比枚举更灵活的地方。

---

## 子类的位置

密封类最容易被记错的规则，就是子类必须放在哪里。

Kotlin 1.0 要求所有子类必须嵌套写在密封类内部，这个限制早已取消。

Kotlin 1.1 起（KEEP-29）子类只需与密封类在同一个文件中即可，不必内嵌。

Kotlin 1.5 起进一步放宽到同一模块、同一包下的任意文件。

**实例**

```kotlin
// 文件：RunoobResult.kt

// 推荐写法：子类与密封类在同一个文件，平级声明，不必嵌套
sealed class RunoobResult

class Success(val data: String) : RunoobResult()
class Failure(val message: String) : RunoobResult()

// 下面这种「必须内嵌」的写法是 Kotlin 1.0 的旧限制，现在不再需要
sealed class OldStyleResult {
    class Success(val data: String) : OldStyleResult()
    class Failure(val message: String) : OldStyleResult()
}

fun main() {
    val a: RunoobResult = Success("runoob")
    val b: OldStyleResult = OldStyleResult.Success("RUNOOB")
    println(a.javaClass.simpleName)
    println(b.javaClass.simpleName)
}
```

```text
Success
Success
```

> **注意：**不要把「子类必须内嵌在密封类中」当成现在的规则。Kotlin 1.1 起只需同一文件，Kotlin 1.5 起同模块同包内的任意文件都可以。子类嵌套写仍然合法，但那是风格选择，不是语法要求。

---

## 密封接口（Kotlin 1.4 起）

Kotlin 1.4 起（KT-44016），接口也可以用 sealed 修饰。

密封接口与密封类的规则基本一致：直接子类必须在同一个文件中声明。

**实例**

```kotlin
// 文件：RunoobEvent.kt
// Kotlin 1.4 起，接口也可以声明为 sealed
sealed interface RunoobEvent

data class Click(val x: Int, val y: Int) : RunoobEvent
data class Scroll(val delta: Int) : RunoobEvent
data object Refresh : RunoobEvent   // data object 需要 Kotlin 1.9 起

fun handle(event: RunoobEvent): String = when (event) {
    is Click -> "点击坐标：(${event.x}, ${event.y})"
    is Scroll -> "滚动：${event.delta}"
    Refresh -> "刷新"
}

fun main() {
    println(handle(Click(10, 20)))
    println(handle(Scroll(-5)))
    println(handle(Refresh))
}
```

```text
点击坐标：(10, 20)
滚动：-5
刷新
```

密封接口比密封类多一个优势：一个类可以实现多个密封接口。

**实例**

```kotlin
sealed interface RunoobClickable
sealed interface RunoobHoverable

// 一个类可以同时实现多个密封接口
class RunoobButton : RunoobClickable, RunoobHoverable

fun main() {
    val button = RunoobButton()
    println(button is RunoobClickable)
    println(button is RunoobHoverable)
}
```

```text
true
true
```

如果只是需要一个封闭的类层次，不涉及状态继承，优先用密封接口。

---

## 与 when 的穷尽性配合

密封类最有价值的用法，就是让 when 分支的遗漏在编译期就暴露出来。

![密封类层次与 when 穷尽性示意图：sealed class RunoobResult 的三个子类 Success、Failure、Loading 分别对应 when 的一个分支，覆盖全部子类时不需要 else](images/kotlin/kotlin-sealed-class/19-sealed-when.svg)

当 when 作为表达式使用时，只要覆盖了全部子类，就不需要写 else。

**实例**

```kotlin
sealed class RunoobState {
    object Idle : RunoobState()
    object Running : RunoobState()
    data class Error(val code: Int) : RunoobState()
}

// 作为表达式：必须覆盖所有分支，漏掉任何一个都编译不通过
fun label(state: RunoobState): String = when (state) {
    RunoobState.Idle -> "空闲"
    RunoobState.Running -> "运行中"
    is RunoobState.Error -> "错误码 ${state.code}"
}

fun main() {
    println(label(RunoobState.Idle))
    println(label(RunoobState.Running))
    println(label(RunoobState.Error(404)))
}
```

```text
空闲
运行中
错误码 404
```

将来给密封类新增一个子类时，所有没处理它的 when 都会立刻报错，编译器帮你找出全部需要修改的地方。

Kotlin 1.6 起，对密封类型主语的 when 语句如果分支不穷尽会给出警告；Kotlin 1.7 起这变成了错误。

也就是说，无论 when 是表达式还是语句，都不该漏掉分支。

---

## 密封类与枚举的对比

两者都能配合穷尽性检查，但适用场景有明显区别。

| 对比项 | sealed class / sealed interface | enum class |
| --- | --- | --- |
| 实例数量 | 每个子类可以有任意多个实例 | 每个常量在全局只有一个实例 |
| 携带数据 | 不同子类可以携带完全不同的属性 | 所有常量共享同一组属性 |
| 子类形态 | class、data class、object 都可以 | 只能是枚举常量本身 |
| 可变状态 | 可以有，每个实例互不影响 | 常量是单例，不适合存可变状态 |
| when 穷尽性 | 支持 | 支持 |
| 典型场景 | 状态机、请求结果、事件类型 | 星期、颜色、固定选项 |

一句话概括：枚举表达「固定的几个值」，密封类表达「固定的几种情况」。

**实例**

```kotlin
// 枚举：所有常量共享同一组属性，无法表达「每个分支携带不同数据」
enum class RunoobStatus(val code: Int) {
    OK(200), NOT_FOUND(404), TIMEOUT(0)
}

// 密封类：每个子类可以带自己的数据
sealed class RunoobResponse {
    data class Ok(val body: String) : RunoobResponse()
    data class NotFound(val path: String) : RunoobResponse()
    data object Timeout : RunoobResponse()
}

fun describe(response: RunoobResponse): String = when (response) {
    is RunoobResponse.Ok -> "返回内容：${response.body}"
    is RunoobResponse.NotFound -> "找不到路径：${response.path}"
    RunoobResponse.Timeout -> "请求超时"
}

fun main() {
    println(RunoobStatus.OK.code)
    println(describe(RunoobResponse.Ok("RUNOOB")))
    println(describe(RunoobResponse.NotFound("/runoob")))
    println(describe(RunoobResponse.Timeout))
}
```

```text
200
返回内容：RUNOOB
找不到路径：/runoob
请求超时
```

---

## 常见问题

下面整理几个使用密封类时容易遇到的问题。

### 密封类能直接被实例化吗

不能，密封类本身是抽象的，必须通过它的子类创建对象。

object 形式的子类可以直接当实例使用。

### 密封类的子类还能再有子类吗

可以，密封类继承密封类也是允许的，直接子类仍然要满足位置要求。

间接子类只要自己的直接父类符合规则，就可以放在其他文件里。

### 什么时候该用密封接口而不是密封类

不涉及共享状态和继承实现，只是要一个封闭的标签集合时，用密封接口更轻。

需要给子类提供公共实现或公共属性时，用密封类更合适。

### 为什么 when 里不需要 else

因为密封类的子类集合在编译期是已知的，编译器能判断分支是否已经覆盖全部情况。

如果手动加了 else，反而会掩盖将来新增子类时的遗漏。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-sealed-class.html)，版权归原作者所有，仅供非商业学习使用。
