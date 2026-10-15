## 第6章 · 异步：Promise 与 async/await

有些事没法立刻完成：请求网络数据要几百毫秒，定时器要等几秒。JS 是单线程语言，如果傻等，页面就会卡死——按钮点不动、动画停摆。所以 JS 把耗时任务设计成异步的：发起后先干别的，任务完成时再回来执行回调。理解异步，是看懂现代 JS 代码的最后一块拼图。

异步最朴素的形态是回调函数。setTimeout 就是典型：它不会阻塞后面的代码，时间到了才执行传入的函数：

```javascript
console.log("第一步");

setTimeout(() => {
  console.log("第三步：两秒后才执行");
}, 2000);

console.log("第二步");   // 不会等待，立刻执行
// 输出顺序：第一步 -> 第二步 -> 第三步
```

回调用多了会遇到"回调地狱"：任务 B 依赖任务 A 的结果，任务 C 又依赖 B，代码就得一层套一层，缩进越来越深，难以阅读。为此社区发明了 Promise：它代表一个"未来才会有结果"的任务，内部状态从"等待"变为"成功"或"失败"，成功后调用 then，失败后调用 catch：

```javascript
// Promise 表示"未来才会有结果"的任务
// resolve 把任务标记为成功，reject 标记为失败
function waitASecond() {
  return new Promise((resolve) => {
    setTimeout(() => resolve("时间到！"), 1000);
  });
}

waitASecond().then((message) => {
  console.log(message);  // 1 秒后打印：时间到！
});
```

Promise 的厉害之处在链式调用：每个 then 都返回新的 Promise，可以把多个异步任务串成一条直线，错误统一交给结尾的 catch。而在 Promise 之后出现的 async/await，让链式调用进一步变成近乎同步的写法，是目前最主流的方案：

```javascript
// 在 async 函数里用 await 等待 Promise 的结果，写起来像同步代码
async function loadUser() {
  try {
    // fetch 是浏览器内置的请求函数，返回 Promise
    const response = await fetch("https://api.example.com/user");
    // 把响应体解析成 JSON 也是异步操作，同样要 await
    const data = await response.json();
    console.log(data);
  } catch (err) {
    // 网络失败等错误会被 try/catch 接住
    console.log("请求失败：", err);
  }
}

loadUser();
```

await 只能在 async 函数里用，它等的是 Promise：后面这行代码会等结果出来再执行，但不会卡住页面。try/catch 正好接住 await 过程中出现的失败，这是 async/await 最大的优点——异步代码的读法和错误处理方式，都与同步代码一致。

几条关键规则和常见误区：

- await 只能等待 Promise，普通值直接返回；async 函数的返回值一定被包成 Promise；
- 多个互不依赖的任务应该用 Promise.all 并发等待，而不是挨个 await 白白串行；
- 忘写 await 是高频 bug：Promise 对象本身没有结果，后面的代码拿到的是"任务"而不是"数据"；
- 每一层 await 都要 try/catch 或上层 catch 兜底，否则失败会变成未处理的 Promise 拒绝；
- 页面加载后自动请求数据再渲染，就是"fetch + await + 第 5 章 DOM 操作"三件套的标准流程。

这套机制的正式名字叫事件循环（event loop）：JS 主线程只有一个，耗时任务交给浏览器内部的其他线程处理，完成后的回调排进队列，等主线程空闲时按顺序执行。由此也能理解两个现象：setTimeout 的延迟并不精确，它只承诺"最早到点执行"；如果主线程正在跑一段很长的同步计算，回调就得继续排队，页面看起来就是卡顿。

小结：JS 单线程靠异步不卡页面，回调是起点，Promise 用 then/catch 串任务，async/await 用同步的写法处理异步。看懂了这一章，网络请求、定时轮询这些代码就都不再神秘。

下一步：把本章的 fetch 换成一个真实可用的接口试试（比如公共天气 API），用 console.log 打印返回的数据，然后结合第 5 章把它渲染到页面上——你已经具备写一个小型网页应用的全部知识了。
