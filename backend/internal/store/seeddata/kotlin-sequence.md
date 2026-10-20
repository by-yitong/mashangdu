序列（Sequence）是一种惰性求值的集合视图，它把多个操作合并成一次遍历，避免生成大量中间集合。

集合的 filter、map 每调用一次就会生成一个新列表，数据量大时内存和时间都会被浪费；序列则让元素逐个流过整条操作链。

本章节讲清楚序列和集合的区别、如何创建序列，以及在什么场景下值得改用序列。

---

## 什么是序列

序列由接口 `Sequence<T>` 表示，它只承诺一件事：可以逐个产出元素。

与 List、Set 不同，序列本身不存储元素，它保存的是「如何计算下一个元素」的规则。

**实例**

```kotlin
fun main() {
    // 一个普通的列表
    val list = listOf("runoob", "RUNOOB", "kotlin")

    // asSequence() 把列表包装成序列，此时不会做任何计算
    val sequence = list.asSequence()

    // 只有调用末端操作时，元素才会真正被处理
    println(sequence.first())
    println(sequence.count())
}
```

```text
runoob
3
```

> **提示：**序列不是一种新的数据结构，它更像是给集合套上的一层「处理管道」，管道里的加工步骤要到真正取结果时才执行。

---

## 序列与集合的区别

集合操作是立即求值的，每个函数都会完整执行并返回一个新集合。

![集合的立即求值与序列的惰性求值对比：集合链每一步生成新集合，序列链元素逐个流过并在 first 处短路](images/kotlin/kotlin-sequence/30-sequence-vs-collection.svg)

序列操作是惰性求值的，中间操作只记录步骤，末端操作才触发计算。

| 对比项 | 集合（Iterable） | 序列（Sequence） |
| --- | --- | --- |
| 求值时机 | 立即求值，每个操作都执行 | 惰性求值，末端操作才执行 |
| 中间结果 | 每一步都生成一个新集合 | 不生成中间集合，元素逐个流过 |
| 遍历次数 | 每个操作各遍历一次 | 所有操作合并成一次遍历 |
| 能否无限长 | 不能，必须先把元素装进内存 | 可以，配合 take 截取有限部分 |
| 小数据量性能 | 更快，没有额外包装开销 | 略慢，多了迭代器和 lambda 开销 |
| 适用场景 | 元素不多，或需要多次遍历 | 元素很多，或有提前终止的操作 |

下面的例子把同一个链式操作分别作用在集合和序列上，用计数器记录 lambda 实际执行了多少次。

**实例**

```kotlin
fun main() {
    val data = (1..10).toList()

    var listSteps = 0
    // 集合：filter 先把 10 个元素全部走一遍，map 再把得到的 5 个偶数走一遍
    val listResult = data
        .filter { listSteps++; it % 2 == 0 }
        .map { listSteps++; it * it }
        .first { it > 20 }

    var seqSteps = 0
    // 序列：每个元素依次穿过 filter 和 map，找到第一个满足条件的元素就立刻停止
    val seqResult = data.asSequence()
        .filter { seqSteps++; it % 2 == 0 }
        .map { seqSteps++; it * it }
        .first { it > 20 }

    println("集合结果：$listResult，lambda 执行次数：$listSteps")
    println("序列结果：$seqResult，lambda 执行次数：$seqSteps")
}
```

```text
集合结果：36，lambda 执行次数：15
序列结果：36，lambda 执行次数：9
```

结果相同，但集合执行了 15 次 lambda，序列只执行了 9 次，因为序列在拿到 36 之后就不再处理后面的元素了。

---

## 创建序列

创建序列有四种常用方式，分别适合不同的数据来源。

| 方式 | 用途 | 示例 |
| --- | --- | --- |
| sequenceOf | 用已知的若干元素创建序列 | `sequenceOf("runoob", "RUNOOB")` |
| asSequence | 把已有的集合、数组转成序列 | `listOf(1, 2).asSequence()` |
| generateSequence | 由种子和「下一个值」的规则生成序列，可以无限长 | `generateSequence(1) { it * 2 }` |
| sequence { } | 用 yield 手动产出元素，适合复杂逻辑 | `sequence { yield(1) }` |

**实例**

```kotlin
fun main() {
    // 1. sequenceOf：元素已知时最直接
    println(sequenceOf("runoob", "RUNOOB", "kotlin").toList())

    // 2. generateSequence：种子 1，每次乘 2，这是一个无限序列
    val powers = generateSequence(1) { it * 2 }
    println(powers.take(5).toList())

    // 加上 takeWhile 就能在满足条件时停下来
    println(generateSequence(1) { it * 2 }.takeWhile { it <= 100 }.toList())

    // 3. sequence { }：用 yield 逐个产出，适合有状态的逻辑
    val fib = sequence {
        var a = 0
        var b = 1
        while (true) {          // 无限循环，靠外部 take 控制取多少
            yield(a)            // 产出一个值并暂停，等下次迭代再继续
            val next = a + b
            a = b
            b = next
        }
    }
    println(fib.take(8).toList())
}
```

```text
[runoob, RUNOOB, kotlin]
[1, 2, 4, 8, 16]
[1, 2, 4, 8, 16, 32, 64]
[0, 1, 1, 2, 3, 5, 8, 13]
```

> **注意：**`sequence { }` 的代码块是挂起函数，里面只能调用 `yield`、`yieldAll` 这类 SequenceScope 提供的挂起函数，不能直接调用别的 suspend 函数。这个构建器从 Kotlin 1.3 起提供。

用 `Iterator.asSequence()` 包装得到的序列只能遍历一次，第二次遍历会抛异常；需要防止误用时可以调用 `constrainOnce()`（Kotlin 1.3 起）把它显式标记为一次性。

---

## 中间操作与末端操作

序列上的函数分两类：中间操作返回新的序列，末端操作返回一个具体结果并触发计算。

中间操作只是把步骤记录下来，不会立即执行，这就是「惰性」的来源。

| 类别 | 常见函数 | 返回值 |
| --- | --- | --- |
| 中间操作 | filter、map、mapNotNull、flatMap、take、drop、distinct、sorted、onEach | 新的 Sequence |
| 末端操作 | toList、toSet、first、find、count、sum、any、all、forEach、joinToString | 具体值或集合 |

**实例**

```kotlin
fun main() {
    // 这条链只是被"描述"出来，还没有任何元素被处理
    val pipeline = sequenceOf(1, 2, 3, 4, 5, 6)
        .filter { println("filter $it"); it % 2 == 0 }
        .map { println("map $it"); it * 10 }

    println("--- 到这里还没有输出 ---")

    // toList() 是末端操作，此时元素才逐个流过 filter 和 map
    val result = pipeline.toList()
    println(result)
}
```

```text
--- 到这里还没有输出 ---
filter 1
filter 2
map 2
filter 3
filter 4
map 4
filter 5
filter 6
map 6
[20, 40, 60]
```

从输出顺序可以看出，序列是「一个元素走完整条链，再处理下一个元素」，而不是「先全部 filter，再全部 map」。

> **注意：**`sorted`、`sortedBy`、`groupBy` 这类需要看到全部元素才能给出结果的中间操作，会先把整个序列读进内存，因此在无限序列上不能直接使用。

---

## 性能对比示例

数据量大且有提前终止条件时，序列的优势最明显。

下面的例子在 500 万个元素上做同样的筛选，只取第一个满足条件的结果。

**实例**

```kotlin
import kotlin.system.measureTimeMillis

fun main() {
    val data = (1..5_000_000).toList()

    // 集合：filter 和 map 各自生成一个约 167 万元素的中间列表
    val listTime = measureTimeMillis {
        data.filter { it % 3 == 0 }
            .map { it * 2 }
            .first { it > 1_000 }
    }

    // 序列：找到第一个满足条件的元素后立即停止，几乎不分配额外内存
    val seqTime = measureTimeMillis {
        data.asSequence()
            .filter { it % 3 == 0 }
            .map { it * 2 }
            .first { it > 1_000 }
    }

    println("集合耗时：${listTime}ms")
    println("序列耗时：${seqTime}ms")
}
```

```text
集合耗时：96ms
序列耗时：2ms
```

> **提示：**上面的耗时是某次运行的示例值，实际数字会随机器性能波动，但两者的数量级差距是稳定的。

---

## 什么时候用序列

序列不是性能银弹，小数据量下它反而更慢，因为它为每个元素都引入了迭代器和 lambda 调用的开销。

| 场景 | 推荐 | 原因 |
| --- | --- | --- |
| 元素数量很小（几十个以内） | 集合 | 没有中间集合的负担，直接遍历更快 |
| 数据量大且链式操作多 | 序列 | 避免生成多个庞大的中间集合 |
| 链中带 first、find、take、any 等提前终止操作 | 序列 | 拿到结果就停，不必处理剩余元素 |
| 需要无限或未知长度的数据流 | 序列 | 集合无法装下无限数据 |
| 需要多次遍历同一份数据 | 集合 | 序列每次末端操作都会重新计算 |
| 需要随机访问、按索引取值 | 集合 | 序列只能顺序迭代，不支持下标 |

一个实用的判断方法是：如果这条链的末端操作是 `toList()` 而且元素数量不多，用集合就好；如果链的末端是 `first()`、`take()`、`find()` 或者数据量很大，改用序列通常更划算。

---

## 常见问题

下面汇总序列使用中的典型疑问。

| 问题 | 原因 | 解决办法 |
| --- | --- | --- |
| 写完序列操作却没有输出 | 只写了中间操作，没有调用末端操作 | 补上 toList、forEach、count 等末端操作 |
| 序列第二次遍历报错 | 序列由 Iterator 包装而来，只能遍历一次 | 重新调用 asSequence，或用 constrainOnce 显式声明 |
| sorted 之后卡住或内存暴涨 | 排序是有状态操作，需要读完整个序列 | 不要用在无限序列上，先 take 限定范围 |
| 小列表改用序列反而更慢 | 序列有额外的包装与调度开销 | 数据量小就继续用集合 |
| 在 sequence 块里调用普通挂起函数报错 | SequenceScope 只允许 yield 系列的挂起调用 | 把逻辑写成普通函数，再在块里 yield 结果 |

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-sequence.html)，版权归原作者所有，仅供非商业学习使用。
