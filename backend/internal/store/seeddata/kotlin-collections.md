集合是日常开发中用得最多的数据结构，Kotlin 在 Java 集合框架之上重新设计了接口层次。

它把"只读"和"可变"拆成两套接口，让函数签名能明确表达"我不会修改这个集合"，同时保持了与 Java 集合的完全互操作。

---

## 集合层次结构

Kotlin 的集合接口都在 `kotlin.collections` 包中，该包默认导入，不需要写 import。

![Kotlin 集合接口层次：Iterable 到 Collection 再到 List 与 Set，Map 独立成一支，各自的只读与可变接口通过 toMutable 系列函数对照](images/kotlin/kotlin-collections/28-collections-hierarchy.svg)

List 和 Set 属于同一个继承链，Map 则是完全独立的一支，不继承 `Collection` 也不继承 `Iterable`。

| 只读接口 | 可变接口 | 特点 |
| --- | --- | --- |
| Iterable<T> | MutableIterable<T> | 集合层次根接口，支持 for 循环遍历 |
| Collection<T> | MutableCollection<T> | 在 Iterable 之上增加 size、isEmpty、contains |
| List<T> | MutableList<T> | 有序、元素可重复、支持下标访问 |
| Set<T> | MutableSet<T> | 元素唯一，重复添加会被忽略 |
| Map<K, V> | MutableMap<K, V> | 键值对集合，键唯一，独立于 Collection |

> **注意：**Map 不是 Collection。它既不能直接用于 for 循环，也没有 `size` 之外的 Collection 方法，遍历时需要访问 `keys`、`values` 或 `entries`。

---

## 只读接口与可变接口

只读接口只提供读取方法，没有 `add`、`remove`、`clear` 这些修改操作。

把集合声明成 `List` 类型，调用方就无法往里添加元素，这个约束由编译器强制保证。

**实例**

```kotlin
fun main() {
    val mutable = mutableListOf("Runoob", "RUNOOB")

    // 同一个对象，用只读接口引用它
    val readOnly: List<String> = mutable

    // readOnly.add("Kotlin")  // 编译错误：List 接口没有 add 方法

    // 通过可变引用依然可以修改
    mutable.add("Kotlin")

    // 只读引用看到的是同一个对象，因此也能看到变化
    println(readOnly)
}
```

运行结果：

```text
[Runoob, RUNOOB, Kotlin]
```

这说明只读接口约束的是"通过这个引用能做什么"，而不是"这个对象永远不能变"。

---

## 只读集合不是深不可变

只读集合有两条被忽略的边界，理解它们能避免线上事故。

第一，只读引用背后可能是可变集合，只要还持有另一个可变引用，内容就能被改动，上一节的例子已经演示过。

第二，只读约束只作用于集合本身，不会递归作用于元素，元素如果是可变对象，仍然可以被修改。

**实例**

```kotlin
fun main() {
    // 外层列表是只读的，但元素本身是 MutableList
    val users = listOf(mutableListOf("Runoob"))

    // users.add(...) 不行，但修改元素可以
    users[0].add("RUNOOB")

    println(users)
}
```

运行结果：

```text
[[Runoob, RUNOOB]]
```

> **建议：**如果确实需要不可变集合，可以使用 `kotlinx.collections.immutable` 库中的持久化集合，或者对外返回副本（如 `list.toList()`），不要依赖只读接口来保证线程安全。

---

## List：有序可重复

List 是最常用的集合，元素按插入顺序排列，允许重复，并支持按下标访问。

创建只读列表用 `listOf`，创建可变列表用 `mutableListOf` 或 `arrayListOf`。

**实例**

```kotlin
fun main() {
    val readOnly = listOf("Runoob", "RUNOOB", "Kotlin")
    val mutable = mutableListOf("Runoob", "RUNOOB")
    val arrayBacked = arrayListOf("Runoob", "RUNOOB")

    mutable.add("Kotlin")
    arrayBacked.add("Kotlin")

    println(readOnly)
    println(mutable)
    println(arrayBacked)

    // 下标访问与几个常用查询方法
    println(readOnly[0])
    println(readOnly.getOrNull(10))     // 越界返回 null，不抛异常
    println(readOnly.indexOf("Kotlin"))
    println(readOnly.contains("RUNOOB"))
}
```

运行结果：

```text
[Runoob, RUNOOB, Kotlin]
[Runoob, RUNOOB, Kotlin]
[Runoob, RUNOOB, Kotlin]
Runoob
null
2
true
```

`mutableListOf` 和 `arrayListOf` 在 JVM 上都返回 ArrayList，功能等价。

区别在于 `arrayListOf` 的返回类型是具体的 `ArrayList`，需要显式使用这个类型时选它即可。

---

## Set：元素唯一

Set 保证元素不重复，重复添加不会报错，只是被忽略。

`setOf` 和 `mutableSetOf` 在 JVM 上基于 LinkedHashSet，会保持插入顺序；`hashSetOf` 基于 HashSet，不保证遍历顺序。

**实例**

```kotlin
fun main() {
    // 重复的 "Runoob" 会被自动忽略
    val readOnly = setOf("Runoob", "RUNOOB", "Runoob")
    val mutable = mutableSetOf("Runoob", "RUNOOB")
    val hash = hashSetOf("Runoob", "RUNOOB")

    mutable.add("Kotlin")
    mutable.add("Runoob")   // 已存在，不会重复添加
    hash.add("Kotlin")

    println(readOnly)
    println(mutable)
    println(hash.sorted())  // HashSet 顺序不确定，排序后再输出
    println(readOnly.size)
    println("RUNOOB" in readOnly)
}
```

运行结果：

```text
[Runoob, RUNOOB]
[Runoob, RUNOOB, Kotlin]
[Kotlin, RUNOOB, Runoob]
2
true
```

> **注意：**依赖 Set 的遍历顺序是不安全的。需要稳定顺序时用 `setOf`、`mutableSetOf` 或 `linkedSetOf`，它们都保持插入顺序。

---

## Map：键值对集合

Map 存储键值对，键唯一，值可以重复。

取值时用方括号语法 `map[key]`，返回类型是 `V?`，键不存在时得到 null。

**实例**

```kotlin
fun main() {
    // to 是中缀函数，用来构造键值对
    val readOnly = mapOf("Runoob" to 1, "RUNOOB" to 2)
    val mutable = mutableMapOf("Runoob" to 1)
    val hash = hashMapOf("Runoob" to 1)

    mutable["RUNOOB"] = 2
    hash["RUNOOB"] = 2

    println(readOnly)
    println(mutable)
    println(readOnly["Runoob"])
    println(readOnly["Kotlin"])                 // 键不存在返回 null
    println(readOnly.getOrDefault("Kotlin", 0)) // 提供默认值
    println(readOnly.keys)
    println(readOnly.values)
}
```

运行结果：

```text
{Runoob=1, RUNOOB=2}
{Runoob=1, RUNOOB=2}
1
null
0
[Runoob, RUNOOB]
[1, 2]
```

需要遍历 Map 时，使用 `for ((key, value) in map)` 解构语法即可。

---

## 创建函数对比

创建函数名字相似，返回类型和底层实现却不同，选错会影响顺序和性能。

| 函数 | 返回类型 | JVM 底层实现 | 特点 |
| --- | --- | --- | --- |
| listOf | List | Arrays$ArrayList / SingletonList / EmptyList | 只读，有序可重复 |
| mutableListOf | MutableList | ArrayList | 可增删 |
| arrayListOf | ArrayList | java.util.ArrayList | 与 mutableListOf 等价，返回具体类型 |
| setOf | Set | LinkedHashSet | 只读，保持插入顺序 |
| mutableSetOf | MutableSet | LinkedHashSet | 可增删，保持插入顺序 |
| hashSetOf | HashSet | java.util.HashSet | 不保证遍历顺序 |
| mapOf | Map | LinkedHashMap | 只读，保持插入顺序 |
| mutableMapOf | MutableMap | LinkedHashMap | 可增删，保持插入顺序 |
| hashMapOf | HashMap | java.util.HashMap | 不保证遍历顺序 |

无参调用 `listOf()`、`setOf()`、`mapOf()` 会返回共享的空集合实例，因此创建空集合没有额外开销。

---

## 用 lambda 构造集合

`List(n) { }` 会创建一个长度为 n 的列表，lambda 的参数是下标。

需要按条件动态构建时，用 `buildList`、`buildSet`、`buildMap`，它们在 Kotlin 1.6 起稳定。

**实例**

```kotlin
fun main() {
    // it 是下标，生成 0 到 4 的平方
    val squares = List(5) { it * it }
    val zeros = MutableList(3) { 0 }
    println(squares)
    println(zeros)

    // buildList 内部可以写任意逻辑，最后返回只读列表
    val built = buildList {
        add("Runoob")
        add("RUNOOB")
        if (size > 1) add("Kotlin")
    }
    println(built)

    val map = buildMap {
        put("Runoob", 1)
        put("RUNOOB", 2)
    }
    println(map)
}
```

运行结果：

```text
[0, 1, 4, 9, 16]
[0, 0, 0]
[Runoob, RUNOOB, Kotlin]
{Runoob=1, RUNOOB=2}
```

---

## 集合之间的转换

只读集合和可变集合之间、不同集合类型之间，都通过 `toXxx` 系列函数转换。

这些函数都会创建新的集合对象，原集合不受影响。

**实例**

```kotlin
fun main() {
    val numbers = listOf(3, 1, 2, 1)

    val set: Set<Int> = numbers.toSet()            // 去重，保持首次出现顺序
    val sortedList: List<Int> = numbers.sorted()   // 排序，返回新列表
    val mutableCopy: MutableList<Int> = numbers.toMutableList()

    // 修改副本不影响原列表
    mutableCopy.add(99)

    println(numbers)
    println(set)
    println(sortedList)
    println(mutableCopy)

    // List<Pair> 转 Map，键重复时保留最后一个值
    val pairs = listOf("Runoob" to 1, "RUNOOB" to 2)
    val map: Map<String, Int> = pairs.toMap()
    println(map)

    // associate 用 lambda 自定义键和值
    val byLength = listOf("Runoob", "Kotlin").associate { it to it.length }
    println(byLength)
}
```

运行结果：

```text
[3, 1, 2, 1]
[3, 1, 2]
[1, 1, 2, 3]
[3, 1, 2, 1, 99]
{Runoob=1, RUNOOB=2}
{Runoob=6, Kotlin=6}
```

常用的转换函数还有 `toMutableSet`、`toMutableMap`、`toTypedArray`，用法与上面一致。

---

## 常见问题

`List` 和 `MutableList` 是什么关系？

两者都是接口，`MutableList` 继承自 `List`。同一个对象可以同时被两种类型的引用指向，能做什么由引用的静态类型决定。

为什么 `map[key]` 返回可空类型？

因为键可能不存在。这是空安全设计的一部分，编译器强制你处理"取不到值"的情况，可以用 Elvis 提供默认值。

`listOf` 创建的列表真的不能改吗？

不能通过 `List` 接口改，但底层实现可能是 `Arrays$ArrayList`，如果把它强制转换成 `MutableList`，添加元素会在运行时抛出 `UnsupportedOperationException`。

什么时候用 Set 而不是 List？

需要去重或频繁判断元素是否存在时用 Set，因为 Set 的 `contains` 平均是常数时间；需要保持顺序和允许重复时用 List。

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/kotlin-collections.html)，版权归原作者所有，仅供非商业学习使用。
