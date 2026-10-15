## 第9章 · 错误处理

程序跑起来总会遇到意外：文件不存在、网络断了、用户输入的不是数字。Go 处理这些问题的方式非常朴素：错误就是一个普通的值（error 类型），函数把错误作为最后一个返回值交还给调用方，调用方老老实实检查它。没有异常抛出、没有隐藏的控制流，错误出现在哪里，就在哪里处理：

```go
package main

import (
	"errors"
	"fmt"
	"strconv"
)

func main() {
	// 约定：最后一个返回值是 error，值为 nil 表示没有出错
	// Atoi 尝试把字符串转成数字，"abc" 显然转不了
	n, err := strconv.Atoi("abc")
	if err != nil {
		fmt.Println("转换失败：", err)
	} else {
		fmt.Println("转换成功：", n)
	}

	// 用 errors.New 创建一个错误，fmt.Errorf 还能格式化
	err2 := errors.New("自定义的错误信息")
	err3 := fmt.Errorf("用户 %s 的年龄 %d 不合法", "小明", -1)
	fmt.Println(err2)
	fmt.Println(err3)
}
```

`if err != nil` 是 Go 代码里出现频率最高的语句，几乎每个函数调用后都跟着它。很多人第一眼觉得啰嗦，但它换来两个好处：出错的调用点一目了然，以及任何函数都不可能"偷偷"失败而不留痕迹。

标准错误满足不了需求时，可以自定义错误类型。error 本质是个接口，只有一个 Error 方法返回字符串，所以任何类型实现它就是一个合法的 error：

```go
// 自定义错误类型：可以携带更多上下文信息
type ValidationError struct {
	Field string // 哪个字段出了问题
}

func (v *ValidationError) Error() string {
	return "字段校验失败：" + v.Field
}

func checkAge(age int) error {
	if age < 0 {
		return &ValidationError{Field: "age"}
	}
	return nil
}

// 调用示例：
// err := checkAge(-1)
// if err != nil {
// 	fmt.Println(err) // 字段校验失败：age
// }
```

错误处理还有几条实践建议：

- 错误要么处理（打日志、返回、重试），要么原样返回，不要既不处理又吞掉；
- 需要在错误上补充上下文时，用 `fmt.Errorf("加载配置失败: %w", err)`，%w 会保留原始错误；
- 判断错误是不是某个特定值或类型，用标准库的 errors.Is 和 errors.As，不要直接比较字符串；
- panic 只留给"程序已经无法继续"的严重问题（比如数组越界），普通业务错误一律用 error。

对比其他语言：Java、Python 用 try/catch 捕获异常，错误会顺着调用栈"飞"上去；Go 选择让错误显式地一层层返回。前者代码短，后者流程清清楚楚。既然选择了 Go，就把 `if err != nil` 当成日常，它不是累赘，而是这份代码靠得住的原因。

标准库里还有一类"哨兵错误"：包预先定义好一个现成的错误值，函数返回它表示特定情况，最典型的是 io.EOF——读取文件或输入时遇到结尾就返回它，调用方用 errors.Is(err, io.EOF) 判断是否读完了。遇到这类约定时先查包文档，看它承诺返回哪些错误值，比猜测可靠得多。记住一条原则：错误是函数契约的一部分，文档承诺了什么就按什么处理，调用方的每个分支都要有着落。

小结：error 是普通值，函数用最后一个返回值报错，调用方用 if 检查；自定义错误只需实现 Error 方法；包装错误用 %w，判断错误用 errors.Is。建议给第 7 章的 Book 结构体写一个 SetPrice 方法，价格小于 0 时返回自定义错误。

下一步：第 10 章是实战，把前九章所学组装成一个能真正使用的命令行待办工具。
