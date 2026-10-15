## 第8章 · 接口

假设你要写一个"让所有会发声的东西开口"的函数：狗要汪汪，机器人要自我介绍。狗和机器人是完全不同的类型，怎么用同一个函数处理？答案是接口（interface）：它只声明"能做什么"（有哪些方法），不关心"是谁在做"。任何类型只要实现了接口要求的全部方法，就自动满足这个接口——不需要写 implements，也不需要声明继承关系。这种"隐式实现"是 Go 最优雅的设计之一：

```go
package main

import "fmt"

// 接口只声明"能做什么"：会 Speak，返回一句话
type Speaker interface {
	Speak() string
}

type Dog struct{}
type Robot struct{}

// Dog 实现了 Speak 方法，就自动满足 Speaker 接口
func (d Dog) Speak() string { return "汪汪" }

// Robot 同理，两个类型互不相干，却都"是" Speaker
func (r Robot) Speak() string { return "你好，我是机器人" }

// makeSpeak 只认接口，任何 Speaker 都能传进来
func makeSpeak(s Speaker) {
	fmt.Println(s.Speak())
}

func main() {
	makeSpeak(Dog{})    // 汪汪
	makeSpeak(Robot{}) // 你好，我是机器人
}
```

接口的价值在于解耦：makeSpeak 的代码写一次，以后新增一种会发声的类型（猫、闹钟），不用改 makeSpeak 一行代码，直接就能用。标准库里到处是这种设计，最常见的是 fmt.Stringer 接口——给类型实现 String 方法后，用 fmt 打印时会自动调用它输出你自定义的格式：

```go
// 假设已有 type User struct { Name string; Age int }

// fmt.Stringer 接口长这样：
// type Stringer interface { String() string }

// 给 User 实现 String，打印时会自动使用
func (u User) String() string {
	return fmt.Sprintf("%s（%d 岁）", u.Name, u.Age)
}

// fmt.Println(User{Name: "小明", Age: 12})
// 输出：小明（12 岁），而不是 {小明 12}
```

关于接口，有几条经验值得记住：

- 接口的方法集合越小越好，只包含调用方真正需要的方法；一个方法、甚至零个方法的接口在 Go 里很常见；
- 实现在使用方还是类型方都可以，Go 不强制，通常跟着类型走；
- 空接口 `interface{}`（新写法是 `any`）不要求任何方法，任何类型都满足它，常用来表示"任意类型"，比如打印函数的参数；
- 判断接口背后装的具体类型，用类型断言或 type switch：`switch v := x.(type)`；
- 接口是"编译期约定 + 运行期装箱"，过度抽象反而让代码难读，新手常见的错误就是为只有一个实现的类型强行定义接口。

一个类比：接口像电器插头标准。你不用关心插座后面接的是火电还是水电，只要插头形状对（方法实现了），电器就能工作。写程序时先定义好接口，各部分就能独立开发、互相替换。

接口还能组合：把已有接口用逗号并列写进新接口，就得到能力更大的接口，标准库的 io.ReadWriter 就是 Reader 与 Writer 的组合，这种"小接口拼大接口"的思路让能力描述非常精确。另外，当你手里只有一个接口值、想知道它背后具体装的是什么类型时，用类型断言 t, ok := x.(Dog) 或 type switch，逐个询问"你是不是某种类型"，再分别处理。记住一条经验：先有多个实现、出现重复代码，才值得抽出接口，不要为了模式而模式。

小结：接口声明行为，类型隐式实现，函数面向接口编程而不面向具体类型。试着定义一个 Shape 接口（含 Area 方法），让 Circle 和 Rectangle 分别实现，再写一个函数算多个图形面积之和。

下一步：第 9 章学习 Go 的错误处理，看看 error 如何贯穿整个语言。
