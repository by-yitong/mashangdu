## 第3章 · 函数与箭头函数

函数是 JS 世界的积木：网页上每一个交互动作，背后都是某个函数被调用。本章学会函数的三种写法、参数默认值，以及现代 JS 代码里无处不在的箭头函数。

最基础的写法是函数声明：function 关键字加函数名，参数写在括号里，return 把结果交还给调用方。函数声明后会提升到作用域顶部，先调用后声明也能运行；第二种是函数表达式，把函数当值存进变量：

```javascript
// 函数声明
function add(a, b) {
  return a + b;
}

// 函数表达式：函数是"值"，可以存进变量
const multiply = function (a, b) {
  return a * b;
};

console.log(add(2, 3));      // 5
console.log(multiply(2, 3)); // 6
```

箭头函数（=>）是 ES6 引入的简写，如今已成为主流写法，尤其在回调函数里几乎一统天下。它的规则是：去掉 function 关键字，参数后加箭头；函数体只有一句 return 时，可以省略大括号和 return，写出一行函数：

```javascript
// 箭头函数是 function 的简写
const square = (x) => {
  return x * x;
};

// 只有一句 return 时，大括号和 return 都可省略
const square2 = (x) => x * x;

// 没有参数时必须写空括号
const sayHi = () => console.log("Hi");

// 参数可以设默认值，不传时使用
const greet = (name = "朋友") => `你好，${name}`;

console.log(square(4));     // 16
console.log(square2(4));    // 16
console.log(greet());       // 你好，朋友
console.log(greet("小明")); // 你好，小明
```

箭头函数和普通 function 有一个重要区别：箭头函数没有自己的 this，它在哪定义就继承哪里的 this。这一章你只需记住这个结论，等学到对象方法和 DOM 事件时会真正体会到它的好处——回调里不用再写 `const that = this` 这样的补救代码。

函数作为值传递是 JS 最核心的用法之一，把函数传给另一个函数，让后者在合适时机调用它，这样的参数叫回调函数：

```javascript
// setTimeout：等 2000 毫秒后调用传入的函数
setTimeout(() => {
  console.log("两秒过去了");
}, 2000);

// 数组的 forEach 也接收回调：对每个元素执行一次
["苹果", "香蕉"].forEach((fruit) => console.log(fruit));
```

写函数时的几条实用建议：

- 函数名用动词开头：getUser、formatDate、sendRequest，一看名字就知道做什么；
- 一个函数尽量只做一件事，超过三四十行就考虑拆分；
- 需要提前退出时直接多写几个 return，比层层嵌套 if 清晰；
- 参数设默认值能大幅减少调用方的判断代码；
- 没有写 return 的函数，返回值是 undefined。

函数体内声明的变量是局部的，函数外部看不见，这正是函数能安全组合的原因——各自的临时变量互不干扰。另一个实用模式叫提前返回：先检查不合法的情况立刻 return，比如 if (!name) return; 主逻辑不再套在层层 if 里，缩进保持很浅。回调写多了你会发现，箭头函数一行式的写法配合提前返回，能让一段逻辑一眼读完。练习里写的 bmi 函数，试着用提前返回处理身高为 0 的情况。

小结：三种写法里，日常优先箭头函数；一句 return 可简写，this 由定义处决定；函数是值，可以被传来传去，这是后面学数组方法和异步的基石。练习建议：写一个箭头函数 bmi(weight, height)，返回身体质量指数（体重除以身高的平方），保留一位小数。

下一步：第 4 章学习数组和对象，JS 里组织数据的两大主角。
