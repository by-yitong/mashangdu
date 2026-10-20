Kotlin 不只能编译成 JVM 字节码，还能编译成 JavaScript、WebAssembly 和原生机器码。

Kotlin Multiplatform（简称 KMP）就是在这套多后端能力之上，让同一份业务逻辑在多个平台上复用。

---

## Kotlin 的四个后端

所谓后端，指的是把 Kotlin 源码翻译成哪种目标代码的那一部分编译器。

![Kotlin 源码经 K2 编译器前端分叉到 Kotlin/JVM、Kotlin/JS、Kotlin/Wasm、Kotlin/Native 四个后端，各自产出 .jar/.class、.js、.wasm 和原生二进制](images/kotlin/kotlin-multiplatform/36-backends.svg)

目前一共有四个后端，它们共享同一套语言前端，所以语法和标准库用起来基本一致。

| 后端 | 产物 | 典型场景 | 备注 |
| --- | --- | --- | --- |
| Kotlin/JVM | JVM 字节码（.class / .jar） | 服务端、Android、桌面 | 可用全部 Java 生态与反射 |
| Kotlin/JS | JavaScript 模块 | 浏览器、Node.js | IR 后端，Kotlin 1.9 起为唯一后端 |
| Kotlin/Native | 原生可执行文件或框架 | iOS、macOS、Linux、嵌入式 | 闭世界编译，没有 JVM 反射 |
| Kotlin/Wasm | WebAssembly 模块 | 浏览器、WASI 运行时 | Beta 阶段，目标是 `wasmJs` 与 `wasmWasi` |

四个后端共用同一套语言规则，但标准库中与平台相关的部分不同。

例如文件读写、线程、时间这些 API，各平台的实现完全不一样，这也是多平台项目要分 source set 的原因。

---

## Kotlin/JVM

Kotlin/JVM 是最成熟、使用最广的后端，编译产物就是标准的 JVM 字节码。

它能直接调用 Java 库，也可以用反射、注解处理器、字节码框架这些 JVM 生态的工具。

默认目标是 JVM 1.8 字节码，可以通过 `jvmTarget` 调高，Kotlin 2.2.20 起支持到 JDK 25。

**实例**

```kotlin
// 文件路径：build.gradle.kts
plugins {
    kotlin("jvm") version "2.2.0"
}

kotlin {
    compilerOptions {
        // 生成的字节码版本，按项目实际运行环境调整
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
```

Android 本质上也是 Kotlin/JVM，只是换成了 Android 的编译链和运行时。

---

## Kotlin/JS

Kotlin/JS 把 Kotlin 编译成 JavaScript，产物可以直接在浏览器或 Node.js 里运行。

从 Kotlin 1.9 起，旧的 Legacy 后端被移除，IR 后端是唯一选择。

在 IR 后端下，Kotlin 的顶层声明默认不会被导出，必须显式加 `@JsExport` 才能从 JavaScript 调用。

**实例**

```kotlin
// 文件路径：src/jsMain/kotlin/Main.kt

// external 声明：告诉 Kotlin 这个 API 由 JavaScript 提供
// 编译器只做类型检查，不生成实现
external fun alert(message: String)

external class Console {
    fun log(message: String)
}

external val console: Console

// @JsExport：把函数导出给 JavaScript 调用
@JsExport
fun greetFromKotlin(name: String): String = "你好，$name"

@JsExport
fun showMessage(text: String) {
    console.log("RUNOOB 提示：$text")
    alert(text)
}
```

编译之后，JavaScript 侧就可以从模块里导入这些函数。

**实例**

```kotlin
// 文件路径：index.js
// Kotlin/JS 打包后会生成一个 ES 模块
import { greetFromKotlin } from './kotlin-app.mjs';

console.log(greetFromKotlin('RUNOOB'));   // 输出：你好，RUNOOB
```

运行输出结果为：

```text
你好，RUNOOB
```

> **提示：**`external` 声明只描述 JS 侧已有的 API，不产生任何代码。如果写了一个 external 函数但 JS 侧并不存在，编译能通过，运行时才会报错。Kotlin 2.x 更推荐用 `external` 声明和 `@JsModule`，尽量少用 `dynamic` 类型。

Gradle 里声明 Kotlin/JS 目标的方式如下，`browser()` 表示运行目标是浏览器。

**实例**

```kotlin
// 文件路径：build.gradle.kts
plugins {
    kotlin("multiplatform") version "2.2.0"
}

kotlin {
    js {                              // Kotlin/JS 目标（IR 是唯一后端）
        browser {                     // 浏览器环境
            binaries.executable()     // 生成可直接运行的产物
        }
    }
}
```

---

## Kotlin/Native

Kotlin/Native 把 Kotlin 直接编译成机器码，产物是原生可执行文件或动态库，不需要虚拟机。

它支持的平台包括 iOS、macOS、Linux、Windows，以及 Android NDK 和 wasm32。

### 闭世界编译模型

闭世界意味着编译器在编译期就能看到程序用到的全部代码。

正因为如此，Kotlin/Native 可以做彻底的死代码消除，二进制体积小、启动快，但代价是失去了动态能力。

| 能力 | Kotlin/JVM | Kotlin/Native |
| --- | --- | --- |
| 运行时加载类 | 支持 `Class.forName` | 不支持，编译期就要确定全部代码 |
| 反射 | 完整支持 kotlin-reflect | 只有有限支持，无法枚举任意成员 |
| 动态代理 | 支持 | 不支持 |
| 二进制体积 | 依赖 JVM 运行时 | 可以裁剪到很小 |
| 启动速度 | 需要 JVM 预热 | 接近直接启动 |

Kotlin/Native 的内存模型在 Kotlin 1.7.20 起换成了新的并发模型，对象不再需要冻结，跨线程共享的限制也随之取消。

旧的内存管理器在 Kotlin 1.9.20 起被移除。

### cinterop 与 C 库互操作

cinterop 工具能读取 C 头文件，自动生成对应的 Kotlin 绑定。

使用时需要提供一个 `.def` 文件描述头文件位置和生成的包名。

**实例**

```kotlin
// 文件路径：src/nativeInterop/cinterop/runoob.h
#ifndef RUNOOB_H
#define RUNOOB_H

// 返回库的版本号
int runoob_version(void);

// 把两个整数相加
int runoob_add(int a, int b);

#endif
```

对应的 `.def` 文件内容如下，只有三行。

```text
# 文件路径：src/nativeInterop/cinterop/runoob.def
headers = runoob.h
package = runoob
```

生成绑定后，Kotlin 代码就像调用普通函数一样调用 C 函数。

**实例**

```kotlin
// 文件路径：src/nativeMain/kotlin/main.kt
import runoob.runoob_add
import runoob.runoob_version

fun main() {
    println("C 库版本：${runoob_version()}")
    println("runoob_add(3, 4) = ${runoob_add(3, 4)}")
}
```

运行输出结果为：

```text
C 库版本：1
runoob_add(3, 4) = 7
```

### 与 Objective-C / Swift 互操作

在 Apple 平台上，Kotlin/Native 可以直接和 Objective-C 互相调用，Swift 则通过生成的 framework 使用 Kotlin 代码。

Kotlin 类会被导出为 Objective-C 类，suspend 函数会自动映射成带完成回调的方法。

**实例**

```kotlin
// 文件路径：src/iosMain/kotlin/Greeter.kt
class Greeter {
    fun greet(name: String): String = "你好，$name"

    // @Throws 让 Swift 侧看到受检异常
    @Throws(IllegalArgumentException::class)
    fun check(age: Int): Int {
        require(age > 0) { "年龄必须大于 0" }
        return age
    }
}
```

Swift 侧 import 生成的 framework 之后就能直接使用。

**实例**

```kotlin
// 文件路径：iosApp/GreeterView.swift
import shared                       // Kotlin/Native 生成的 framework

let greeter = Greeter()
print(greeter.greet(name: "RUNOOB"))
```

在 Xcode 控制台中的输出结果为：

```text
你好，RUNOOB
```

Kotlin 2.0 起还提供了实验性的 `@ObjCName` 注解，可以自定义暴露给 Objective-C / Swift 的名字，避免命名冲突。

---

## Kotlin/Wasm

Kotlin/Wasm 把 Kotlin 编译成 WebAssembly，目标是在浏览器里获得接近原生的执行速度。

它从 Kotlin 1.9.20 起进入 Beta，提供两个目标：`wasmJs` 面向浏览器，`wasmWasi` 面向 WASI 运行时。

和 Kotlin/JS 相比，Wasm 的优势在于性能更接近机器码，而且能利用 WasmGC 直接操作宿主对象。

**实例**

```kotlin
// 文件路径：build.gradle.kts
kotlin {
    wasmJs {                      // 浏览器方向的 Wasm 目标
        browser {
            binaries.executable()
        }
    }
}
```

> **注意：**Kotlin/Wasm 目前仍是 Beta，编译器和标准库 API 可能变化。生产项目如果只需要在浏览器跑 Kotlin，Kotlin/JS 更稳妥；追求性能且能接受实验性特性时再考虑 Wasm。

---

## expect 与 actual

多平台代码的核心机制是 `expect` 和 `actual`。

在共享代码里用 `expect` 声明「这里有这么一个东西」，各平台再用 `actual` 给出具体实现。

编译到某个平台时，编译器会用该平台的 actual 替换掉 expect。

**实例**

```kotlin
// 文件路径：src/commonMain/kotlin/Platform.kt
// expect：只声明不实现，各平台必须提供对应的 actual
expect fun platformName(): String

expect val isDesktop: Boolean

fun greeting(): String = "欢迎使用 Kotlin 多平台，当前平台：$platformName"
```

JVM 平台给出自己的实现。

**实例**

```kotlin
// 文件路径：src/jvmMain/kotlin/Platform.kt
actual fun platformName(): String = "Kotlin/JVM"

actual val isDesktop: Boolean = true
```

JavaScript 平台给出另一份实现。

**实例**

```kotlin
// 文件路径：src/jsMain/kotlin/Platform.kt
actual fun platformName(): String = "Kotlin/JS"

actual val isDesktop: Boolean = false
```

在 JVM 平台写一个入口把两者打印出来。

**实例**

```kotlin
// 文件路径：src/jvmMain/kotlin/Main.kt
fun main() {
    println(greeting())
    println("isDesktop = $isDesktop")
}
```

在 JVM 上运行时输出结果如下。

```text
欢迎使用 Kotlin 多平台，当前平台：Kotlin/JVM
isDesktop = true
```

> **提示：**`expect class` 与 `actual class` 也支持，但 Kotlin 2.0 起编译器会给出 Beta 状态的警告，可以用 `-Xexpect-actual-classes` 抑制。能用 expect 函数或接口解决的场景，优先不要用 expect 类。

---

## KMP 项目结构与 source set

KMP 项目把代码按平台划分到不同的 source set 里，共享的放在 common，平台专属的放在各自目录。

![KMP 项目 source set 层级结构：commonMain 下分 jvmMain、nativeMain、jsMain，nativeMain 下再分 iosArm64Main 与 linuxX64Main；expect 只能写在 commonMain，actual 写在各平台 source set](images/kotlin/kotlin-multiplatform/36-source-sets.svg)

典型的目录结构如下。

```text
runoob-multiplatform/
├── build.gradle.kts              # 根构建脚本，声明目标平台
├── settings.gradle.kts
├── gradle/
│   └── libs.versions.toml        # 版本目录，集中管理依赖版本
└── src/
    ├── commonMain/kotlin/        # 所有平台共享的代码
    │   └── Platform.kt
    ├── commonTest/kotlin/        # 共享测试
    ├── jvmMain/kotlin/           # 仅 JVM 平台
    ├── jsMain/kotlin/            # 仅 Kotlin/JS
    ├── nativeMain/kotlin/        # 所有 Kotlin/Native 目标共享
    └── iosMain/kotlin/           # 仅 iOS 目标
```

常见的 source set 及其作用如下表。

| source set | 作用 |
| --- | --- |
| `commonMain` | 所有目标共享的代码 |
| `commonTest` | 共享的测试代码 |
| `jvmMain` | 仅 JVM 目标可见 |
| `jsMain` | 仅 Kotlin/JS 目标可见 |
| `wasmJsMain` | 仅 Kotlin/Wasm 目标可见 |
| `nativeMain` | 所有 Kotlin/Native 目标共享 |
| `appleMain` | 所有 Apple 平台目标共享 |
| `iosMain` | 仅 iOS 目标可见 |

`nativeMain`、`appleMain`、`iosMain` 这些中间层由默认层级模板自动生成，Kotlin 1.9.20 起默认启用。

构建脚本里声明目标平台和依赖。

**实例**

```kotlin
// 文件路径：build.gradle.kts
plugins {
    kotlin("multiplatform") version "2.2.0"
}

kotlin {
    // 声明需要编译的目标平台
    jvm()                                        // 桌面 / 服务端
    js { browser(); binaries.executable() }       // 浏览器
    wasmJs { browser() }                         // WebAssembly（Beta）
    iosArm64()                                   // iPhone 真机
    iosSimulatorArm64()                          // Apple 芯片模拟器
    macosArm64()                                 // Apple 芯片 macOS

    sourceSets {
        // 所有平台共享的依赖
        commonMain.dependencies {
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
        }
        // 仅 JVM 平台的依赖
        jvmMain.dependencies {
            implementation("com.google.code.gson:gson:2.11.0")
        }
        // 共享测试
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
    }
}
```

多平台项目从 Kotlin 1.3 起进入稳定阶段，现在 Android、iOS、桌面、后端的共享逻辑都用它来组织。

> **提示：**不要把 UI 代码也塞进 commonMain。KMP 的定位是共享业务逻辑、网络、数据模型和存储，界面部分通常交给 Compose Multiplatform 或各平台自己的 UI 框架。

---

## 常见问题

下面几个问题在搭建多平台项目时经常遇到。

### commonMain 里为什么不能用 java.util

JVM 专有的类在 JS 和 Native 上不存在。要么换成 `kotlinx-datetime`、`kotlinx-io` 这类多平台库，要么用 expect/actual 隔离。

### Kotlin/Native 为什么不能用反射

闭世界编译模型下，编译器在编译期就丢弃了未被引用的代码，运行时没有完整的类元数据，所以无法像 JVM 那样枚举成员。

### @JsExport 加了但 JS 还是拿不到

确认使用的是 IR 后端，并且声明是 public 的顶层函数、类或对象成员。私有声明加注解也不会被导出。

### expect 和 actual 的签名必须完全一致吗

必须一致。函数名、参数类型、返回类型都要匹配，Kotlin 2.0 起的 K2 编译器对这一点检查更严格。

### Kotlin/JS 和 Kotlin/Wasm 怎么选

需要成熟稳定、生态丰富就选 Kotlin/JS；追求性能、能接受 Beta 状态就试 Kotlin/Wasm。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-multiplatform.html)，版权归原作者所有，仅供非商业学习使用。
