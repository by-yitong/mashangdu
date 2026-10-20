协程是一种可以挂起和恢复的轻量级线程，用来解决异步任务写法复杂、回调嵌套过深的问题。

用协程写出来的异步代码和同步代码结构几乎一样，但执行时不会阻塞线程。

---

## 什么是协程

传统的异步编程依赖回调，几个任务一嵌套就形成了「回调地狱」，错误处理也很分散。

另一种做法是开线程，但线程由操作系统调度，创建成本高，数量一多切换开销就上来了。

协程走的是第三条路：它运行在线程之上，由编译器生成的代码负责挂起和恢复，一个线程可以同时跑成千上万个协程。

关键在于「挂起」不等于「阻塞」：协程遇到耗时操作时会让出线程，线程去执行别的任务，等结果就绪后再把协程恢复回来。

所以协程特别适合网络请求、文件读写、数据库访问这类等待时间远大于计算时间的场景。

协程在 Kotlin 1.3 起成为稳定特性，API 由官方库 `kotlinx-coroutines` 提供。

---

## 第一个协程

最常用的两个构建器是 `runBlocking` 和 `launch`。

`runBlocking` 会阻塞当前线程直到内部所有协程结束，通常只在 `main` 函数和测试里使用。

`launch` 启动一个不阻塞当前线程的协程，返回一个 `Job` 对象。

**实例**

```kotlin
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {          // 阻塞主线程，直到内部协程全部完成
    println("开始，线程：${Thread.currentThread().name}")

    launch {                       // 启动协程，不阻塞后面的代码
        delay(100)                 // 挂起 100 毫秒，线程此时可以去干别的
        println("协程 A 完成")
    }

    launch {
        delay(50)
        println("协程 B 完成")
    }

    println("main 协程继续执行")
}
```

实例执行输出结果为：

```text
开始，线程：main
main 协程继续执行
协程 B 完成
协程 A 完成
```

可以看到 `main 协程继续执行` 先打印出来，说明 `launch` 没有阻塞。

B 只等 50 毫秒，A 等 100 毫秒，所以 B 先完成。

> **提示：**`runBlocking` 会真的阻塞线程，写在服务端业务代码里会拖慢整个线程池，所以它只适合作为入口或测试的「桥」。业务代码里应该用 `launch`、`async` 或 `coroutineScope`。

---

## suspend 函数

`suspend` 关键字标记一个可以挂起的函数，它只能在协程或另一个 suspend 函数里调用。

![协程挂起与恢复时序图：主线程 launch 协程，调用挂起函数后线程被释放，IO 线程发起网络请求，返回后恢复协程，主线程继续执行](images/kotlin/kotlin-coroutines/34-coroutine-sequence.svg)

编译器会给 suspend 函数加上一个额外的参数用来传递续体，所以它能记住挂起时的位置。

**实例**

```kotlin
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

// suspend 函数：模拟一次网络请求
suspend fun fetchSite(): String {
    delay(100)                     // 挂起，不占用线程
    return "www.runoob.com"
}

suspend fun printSite() {
    println("开始获取")
    val site = fetchSite()         // 在 suspend 函数里调用 suspend 函数
    println("站点：$site")
}

fun main() = runBlocking {
    printSite()
}
```

实例执行输出结果为：

```text
开始获取
站点：www.runoob.com
```

如果把 `fetchSite()` 直接写到普通函数里，编译器会报错，提示只能在协程中调用。

这也是为什么很多框架的接口都声明成 suspend 函数，让调用方自动进入协程上下文。

---

## 结构化并发与 coroutineScope

结构化并发是指父协程会等待所有子协程结束后才结束，子协程失败也会影响父协程。

这样做的好处是不会出现「协程泄漏」：谁启动的协程，谁就负责等它结束。

`coroutineScope` 会创建一个子作用域，挂起直到内部所有子协程都完成。

**实例**

```kotlin
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

suspend fun loadHomePage() = coroutineScope {
    launch {
        delay(200)
        println("模块 A 加载完成")
    }
    launch {
        delay(100)
        println("模块 B 加载完成")
    }
    println("等待所有子协程……")
}   // 这里会挂起，直到两个子协程都结束

fun main() = runBlocking {
    loadHomePage()
    println("首页全部就绪")
}
```

实例执行输出结果为：

```text
等待所有子协程……
模块 B 加载完成
模块 A 加载完成
首页全部就绪
```

如果希望某个子协程失败时不影响兄弟协程，可以用 `supervisorScope`。

| 构建器 | 返回值 | 异常行为 | 典型场景 |
| --- | --- | --- | --- |
| `runBlocking` | lambda 的返回值 | 异常向外抛出 | main 函数、测试入口 |
| `launch` | Job | 异常向上传播，取消父协程 | 不需要结果的并行任务 |
| `async` | Deferred<T> | 异常延迟到 await 时抛出 | 需要结果的并行任务 |
| `coroutineScope` | lambda 的返回值 | 任一子协程失败则整体失败 | 挂起函数内部分并发 |
| `supervisorScope` | lambda 的返回值 | 子协程失败互不影响 | 一个失败不影响其他 |

---

## 调度器 Dispatchers

调度器决定协程在哪个线程或线程池上执行，用 `withContext` 可以临时切换。

常用调度器有四种，选择依据是任务类型：CPU 密集还是阻塞式 IO。

| 调度器 | 线程池 | 适用场景 |
| --- | --- | --- |
| `Dispatchers.Default` | CPU 核心数（至少 2） | 排序、解析、加解密等 CPU 密集任务 |
| `Dispatchers.IO` | 按需扩容，默认上限 64 | 文件读写、网络请求、数据库访问 |
| `Dispatchers.Main` | 主线程 | Android 更新 UI、桌面 Swing/JavaFX |
| `Dispatchers.Unconfined` | 不限定，恢复时用调用方线程 | 极少使用，一般只在测试里出现 |

**实例**

```kotlin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

fun main() = runBlocking {
    println("主线程：${Thread.currentThread().name}")

    withContext(Dispatchers.Default) {
        println("Default 在主线程吗：${Thread.currentThread().name == "main"}")
    }

    withContext(Dispatchers.IO) {
        println("IO 在主线程吗：${Thread.currentThread().name == "main"}")
    }

    println("结束时仍在：${Thread.currentThread().name}")
}
```

实例执行输出结果为：

```text
主线程：main
Default 在主线程吗：false
IO 在主线程吗：false
结束时仍在：main
```

> **提示：**`Dispatchers.Main` 需要额外的平台依赖。Android 上是 `kotlinx-coroutines-android`，桌面 Swing 是 `kotlinx-coroutines-swing`，否则运行时会抛出「Module with the Main dispatcher had failed to initialize」。

---

## 取消与超时

协程的取消是协作式的：调用 `cancel()` 只是发出取消请求，协程要在挂起点才会真正退出。

`kotlinx.coroutines` 里的 `delay`、`yield` 等挂起函数都会检查取消状态。

**实例**

```kotlin
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull

fun main() = runBlocking {
    // 取消一个长时间运行的协程
    val job = launch {
        repeat(5) { i ->
            delay(200)                 // 挂起点会检查是否已被取消
            println("第 $i 次下载……")
        }
    }
    delay(450)                         // 让它先跑一会儿
    println("取消任务")
    job.cancel()                       // 发出取消请求
    job.join()                         // 等待取消真正完成
    println("任务已停止，isCancelled = ${job.isCancelled}")

    // 超时控制
    val result = withTimeoutOrNull(300) {
        delay(1000)                    // 超过 300 毫秒就放弃
        "下载完成"
    }
    println("超时结果：$result")
}
```

实例执行输出结果为：

```text
第 0 次下载……
第 1 次下载……
取消任务
任务已停止，isCancelled = true
超时结果：null
```

`withTimeout` 在超时时抛出 `TimeoutCancellationException`，而 `withTimeoutOrNull` 返回 `null`。

如果协程正在做纯计算，没有挂起点，取消不会生效，这时要主动调用 `ensureActive()` 或检查 `isActive`。

**实例**

```kotlin
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val job = launch {
        var sum = 0L
        for (i in 1..1_000_000_000) {
            sum += i
            if (i % 10_000_000 == 0) {
                ensureActive()         // 主动检查取消状态
                println("已计算到 $i")
            }
        }
    }
    job.cancel()                       // 立刻取消
    job.join()
    println("已取消：${job.isCancelled}")
}
```

实例执行输出结果为：

```text
已取消：true
```

---

## async 与 await 并发

`launch` 不返回结果，需要并发求值时用 `async`，它返回 `Deferred<T>`。

调用 `await()` 会挂起直到结果就绪，两个 `async` 之间是真正并行的。

**实例**

```kotlin
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlin.system.measureTimeMillis

// 模拟一个耗时模块
suspend fun loadModule(name: String, cost: Long): String {
    delay(cost)
    return "$name 加载完成"
}

fun main() = runBlocking {
    val time = measureTimeMillis {
        val a = async { loadModule("模块 A", 300) }   // 立即开始执行
        val b = async { loadModule("模块 B", 300) }   // 立即开始执行
        println(a.await())                            // 等 A
        println(b.await())                            // 等 B
    }
    // 串行执行需要 600 毫秒左右，并行明显更快
    println("是否并行执行：${time < 600}")
}
```

实例执行输出结果为：

```text
模块 A 加载完成
模块 B 加载完成
是否并行执行：true
```

> **注意：**`async` 只有在协程作用域内才有意义。如果写成 `coroutineScope { async { ... } }` 之外的全局作用域，会失去结构化并发，异常也没人处理。

---

## Flow 简介

Flow 是协程版的流，用来处理「按顺序产生多个值」的异步数据流。

它和序列很像，都是惰性的，区别是 Flow 的每个环节都可以是 suspend 函数。

Flow 从 kotlinx.coroutines 1.4 起稳定，构建器是 `flow { }`，用 `emit` 发射元素。

**实例**

```kotlin
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking

// 冷流：每个收集者都会触发一次完整的执行
fun numberFlow() = flow {
    for (i in 1..5) {
        emit(i)                       // 逐个发出元素
    }
}

fun main() = runBlocking {
    // map 和 filter 是中间操作，不会立即执行
    val result = numberFlow()
        .map { it * 10 }              // 每个元素乘以 10
        .filter { it > 20 }           // 只保留大于 20 的
        .toList()                     // 末端操作，触发整个流

    println(result)

    // collect 逐个消费元素
    numberFlow().collect { value ->
        println("收到：$value")
    }
}
```

实例执行输出结果为：

```text
[30, 40, 50]
收到：1
收到：2
收到：3
收到：4
收到：5
```

Flow 还有几个常用能力：`flowOn` 改变上游的调度器，`catch` 捕获上游异常，`onEach` 在每次发射时做副作用。

**实例**

```kotlin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking

fun riskyFlow() = flow {
    emit("第一项")
    throw IllegalStateException("数据源断开")
}.catch { e ->
    emit("捕获到异常：${e.message}")     // 在流内部兜底
}

fun main() = runBlocking {
    // flowOn 让发射逻辑跑在 IO 线程，收集仍在主线程
    val list = riskyFlow()
        .flowOn(Dispatchers.IO)
        .toList()
    println(list)
}
```

实例执行输出结果为：

```text
[第一项, 捕获到异常：数据源断开]
```

---

## 异常处理

协程里的异常处理和普通代码类似，可以直接用 `try/catch` 包住 suspend 调用。

`coroutineScope` 会把子协程的异常向上抛，交给外层的 `catch` 处理。

**实例**

```kotlin
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

suspend fun loadData(): String {
    delay(100)
    throw IllegalStateException("服务器返回 500")
}

fun main() = runBlocking {
    // 方式一：在协程内部 try/catch
    launch {
        try {
            loadData()
        } catch (e: Exception) {
            println("内部捕获：${e.message}")
        }
    }

    // 方式二：coroutineScope 把异常抛给调用者
    try {
        coroutineScope {
            loadData()
        }
    } catch (e: Exception) {
        println("外层捕获：${e.message}")
    }
}
```

实例执行输出结果为：

```text
内部捕获：服务器返回 500
外层捕获：服务器返回 500
```

根协程（`launch` 直接启动且没有被 catch）的异常可以用 `CoroutineExceptionHandler` 统一处理。

**实例**

```kotlin
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    // 处理器只对根协程生效，且必须在作用域上声明
    val handler = CoroutineExceptionHandler { _, e ->
        println("全局处理：${e.message}")
    }

    val job = launch(handler) {
        throw RuntimeException("任务失败")
    }
    job.join()
    println("主流程继续")
}
```

实例执行输出结果为：

```text
全局处理：任务失败
主流程继续
```

> **注意：**不要吞掉 `CancellationException`。捕获 `Exception` 时要先判断是不是取消异常，否则会把正常的取消当成错误处理。

---

## 依赖引入

协程不在 Kotlin 标准库里，需要单独引入 `kotlinx-coroutines-core`。

版本要和 Kotlin 编译器配套，Kotlin 2.2 推荐使用 1.10.x。

**实例**

```kotlin
// 文件路径：build.gradle.kts
plugins {
    kotlin("jvm") version "2.2.0"
}

dependencies {
    // 核心库，所有平台都要
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")

    // Android 上使用 Dispatchers.Main 时需要
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    // 协程测试工具 runTest / TestDispatcher
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}
```

用 Maven 时，JVM 平台要选带 `-jvm` 后缀的构件。

**实例**

```xml
<!-- 文件路径：pom.xml -->
<dependency>
    <groupId>org.jetbrains.kotlinx</groupId>
    <artifactId>kotlinx-coroutines-core-jvm</artifactId>
    <version>1.10.2</version>
</dependency>
```

---

## 常见问题

下面几个问题在初学协程时出现频率最高。

### Suspend function should be called only from a coroutine

在普通函数里调用了 suspend 函数。把调用方也改成 suspend，或者用 `runBlocking`、`launch` 包一层。

### 为什么 cancel 之后协程还在跑

取消是协作式的，协程没有停在挂起点就不会退出。在循环里加 `ensureActive()` 或 `yield()`。

### runBlocking 和 coroutineScope 有什么区别

`runBlocking` 阻塞线程，用于最外层入口；`coroutineScope` 只挂起协程、不阻塞线程，用于挂起函数内部。

### launch 里的异常为什么没打印

如果异常发生在非根协程里，会被向上传播并取消父协程。要么在内部 try/catch，要么给根协程加 `CoroutineExceptionHandler`。

### Flow 和 Sequence 怎么选

纯计算、同步的场景用 Sequence；涉及挂起操作（网络、IO）的场景用 Flow。

### Dispatchers.IO 会不会线程爆炸

不会。它默认上限是 64 个线程，可以用系统属性 `kotlinx.coroutines.io.parallelism` 调整。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-coroutines.html)，版权归原作者所有，仅供非商业学习使用。
