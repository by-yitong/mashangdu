## 第4章 · 流程控制：if、for 与 switch

程序之所以能解决复杂的问题，是因为它会在不同情况下走不同的路。流程控制就是"选路"的语法：if 负责条件分支，for 负责重复执行，switch 负责多路选择。掌握这三样，你就能把"如果……就……""重复做……直到……"这类日常逻辑翻译成代码。这一章我们逐个认识它们。

Go 的 if 写起来很干脆：条件不需要括号包住，但大括号一个都不能省，而且左大括号必须和 if 写在同一行，这是 Go 的强制风格。它还有一个独特用法：在条件前放一条初始化语句，用分号隔开，这样声明的变量只在这个 if 块里可用，出了块就"消失"，作用域非常干净：

```go
package main

import "fmt"

func main() {
	age := 20

	if age >= 18 {
		fmt.Println("成年人")
	} else if age >= 12 {
		fmt.Println("青少年")
	} else {
		fmt.Println("儿童")
	}

	// if 支持初始化语句：n 只在这个 if/else 结构里可用
	if n := age * 2; n > 30 {
		fmt.Println("两倍年龄超过 30，当前是", n)
	}
}
```

Go 只有 for 一种循环关键字，但它的形态很灵活，常见写法有三种。第一种是经典三段式：初始化；条件；后置语句，分号隔开。第二种只保留条件，等价于其他语言的 while。第三种配合 range 遍历切片、映射等集合，这是 Go 里最常用的遍历方式：

```go
package main

import "fmt"

func main() {
	// 三段式：从 1 加到 100
	sum := 0
	for i := 1; i <= 100; i++ {
		sum += i
	}
	fmt.Println("1 到 100 的和是", sum)

	// 只留条件：相当于其他语言的 while
	count := 3
	for count > 0 {
		fmt.Println("倒计时", count)
		count--
	}

	// range 遍历切片：i 是下标，v 是值；不需要下标时可以写 for _, v
	languages := []string{"Go", "Python", "JavaScript"}
	for i, v := range languages {
		fmt.Println(i, v)
	}
}
```

需要提前跳出循环时用 break，跳过本轮继续下一轮时用 continue，这一点和其他语言一致。想死循环就在 for 后面什么都不写：`for { ... }`，配合 break 使用。

当同一个变量要和很多个值逐一比较时，一长串 else if 会很难读，switch 更合适：

- 每个 case 自带 break 语义，匹配到一个就结束，不会像 C 语言那样往下"穿透"，不用手写 break；
- 一个 case 可以写多个值，用逗号隔开，命中任意一个即成立；
- 都不匹配时走 default 分支，default 放在开头结尾都可以；
- switch 后面也可以不写表达式，把 true 隐式比较用在每个 case 上，用来替代复杂的 if else 链。

```go
day := "周六"

switch day {
case "周六", "周日":
	fmt.Println("休息日")
case "周一":
	fmt.Println("一周的开始")
default:
	fmt.Println("工作日")
}
```

写条件判断时再送一个提高可读性的技巧：让正常流程保持在最浅的缩进里，出错或不符合前置条件的情况提前用 return 或 continue 挡回去，这种写法叫卫语句，Go 标准库大量使用——函数开头先处理非法输入，剩下的就是清爽的主逻辑。另外 for 的初始化语句里声明的变量同样只在循环内可见，善用这些作用域规则，变量名就不容易互相污染。把本章示例改出五六个变体亲自跑跑，比多读一遍更有效。

小结：if 处理二选一的判断，for 承担所有循环任务，switch 把多路分支排得清清楚楚。三者几乎是所有程序逻辑的骨架，建议把本章代码逐个敲一遍，然后修改条件和数据，观察输出的变化，比单纯看书记得牢。

下一步：第 5 章我们学习函数，把重复的逻辑打包成可以反复调用的积木。
