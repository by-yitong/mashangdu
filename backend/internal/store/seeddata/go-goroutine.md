## 用 goroutine 同时做多件事

生活中你不会等衣服洗完才开始烧饭。程序也一样，同时推进多个任务的能力叫并发，goroutine（协程）就是 Go 提供的并发工具。它非常轻量，同时跑成百上千个都毫无压力。用法极其简单：在函数调用前面加一个 go 关键字。

```go
package main

import (
	"fmt"
	"time"
)

func say(name string) {
	for i := 1; i <= 3; i++ {
		fmt.Println(name, i)
	}
}

func main() {
	go say("A")
	go say("B")
	time.Sleep(time.Second)
}
```

运行这段代码，A 和 B 的输出会交错出现，说明两个任务确实在同时推进。理解这段代码，关键是下面三点：

- `go say("A")` 会立刻返回，主函数不会等它执行完；
- main 一旦退出，还没跑完的 goroutine 会被一并带走；
- 示例里用 time.Sleep 睡一秒，是为了给子任务留出执行时间。

真正开发中不会靠睡觉来等待，而是用 channel（通道）在 goroutine 之间传递数据、协调节奏，那是后面章节的内容。现在你只需要记住一句话：加一个 go 关键字，任务就跑上了另一条车道。
