## 第10章 · 写一个命令行待办工具

学了九章语法，这一章我们做一件完整的事：写一个命令行待办（TODO）工具。它从键盘读取命令，支持添加任务、列出任务、标记完成和退出。麻雀虽小，五脏俱全：结构体、切片、循环、分支、字符串处理、错误处理全都用上了。

先做设计。每个待办事项有"内容"和"是否完成"两个属性，正好用一个结构体表示；所有事项放在一个切片里，程序运行期间在内存中维护。支持的命令如下：

- `add 事项内容`：添加一条待办，内容里可以带空格；
- `list`：列出全部待办，完成的打 [x]，未完成的打 [ ]；
- `done 编号`：把对应编号的任务标记为完成，编号从 1 开始；
- `quit`：退出程序。

```go
// 每个待办事项用一个小结构体表示
type Task struct {
	Done  bool   // 是否完成
	Title string // 事项内容
}

// 所有任务放进一个切片，程序运行期间在内存里维护
tasks := []Task{}
```

下面是完整程序。核心是一个大循环：每轮打印提示符、读一行输入、按空格拆出命令和参数，再用 switch 分发处理。把下面的代码保存为 main.go，执行 go run main.go 即可开始使用：

```go
package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Task 表示一条待办事项
type Task struct {
	Done  bool
	Title string
}

func main() {
	tasks := []Task{}
	scanner := bufio.NewScanner(os.Stdin)

	fmt.Println("待办工具启动！命令：add 标题 / list / done 编号 / quit")
	for {
		fmt.Print("> ")
		if !scanner.Scan() {
			break // 输入结束（Ctrl+D）时退出
		}
		// SplitN 按第一个空格切开：前半是命令，后半是完整标题
		parts := strings.SplitN(strings.TrimSpace(scanner.Text()), " ", 2)

		switch parts[0] {
		case "add":
			if len(parts) < 2 || parts[1] == "" {
				fmt.Println("用法：add 标题")
				continue
			}
			tasks = append(tasks, Task{Title: parts[1]})
			fmt.Println("已添加：", parts[1])
		case "list":
			if len(tasks) == 0 {
				fmt.Println("还没有任务，用 add 添加一个吧")
			}
			for i, t := range tasks {
				mark := "[ ]"
				if t.Done {
					mark = "[x]"
				}
				fmt.Printf("%d. %s %s\n", i+1, mark, t.Title)
			}
		case "done":
			if len(parts) < 2 {
				fmt.Println("用法：done 编号")
				continue
			}
			// Atoi 转换用户输入，非法输入直接提示，不猜测
			n, err := strconv.Atoi(parts[1])
			if err != nil || n < 1 || n > len(tasks) {
				fmt.Println("编号无效")
				continue
			}
			tasks[n-1].Done = true
			fmt.Println("已完成：", tasks[n-1].Title)
		case "quit":
			fmt.Println("再见！")
			return
		default:
			fmt.Println("未知命令，可用：add / list / done / quit")
		}
	}
}
```

运行起来大概是这样的：

- 输入 `add 买牛奶`，输出"已添加： 买牛奶"；
- 输入 `add 写作业` 再输入 `list`，看到两条带编号的任务；
- 输入 `done 1` 后再 `list`，第一条变成 [x]；
- 输入 `done 99`，程序提示"编号无效"而不是崩溃——这就是第 9 章讲的错误检查在起作用。

逐行读取输入靠的是 bufio.NewScanner(os.Stdin)：它给标准输入套了一层缓冲，每调用一次 Scan 就读入一行。读到的内容先经 TrimSpace 去掉首尾空白，再用 SplitN 按第一个空格切成两段，第二段原样保留，所以"add 买 牛奶"这种带空格的标题不会被切碎。这个"读一行、解析、分发处理"的循环，是所有交互式命令行程序的通用骨架，以后写数据库客户端、交互式菜单时还会反复遇到同样的形状。

这个工具有两处值得你继续打磨：一是任务只存在内存里，程序一关就没了，可以用第 7 章之后学到的 os.WriteFile 把切片保存成文件，启动时再读回来；二是命令解析还很简陋，可以试着支持 delete 编号（删除任务）和 clear（清空已完成）。改坏了就对照本章代码重敲，动手调试本身就是最好的练习。

小结：从读输入到分发命令，从结构体到切片，这个 60 行左右的小程序把整门课串了起来。写出它，Go 入门就算真正毕业了。

下一步：可以继续深入学习 Go 的包管理、标准库 http 包，尝试写一个 Web 服务器，或者开始学习下一门语言。
