## 第5章 · DOM 操作入门

前面学的 JS 还只是"计算"，这一章开始它真正的主场：操控网页。浏览器把整个页面解析成一棵对象树，叫 DOM（Document Object Model，文档对象模型）：每个标签是一个节点对象，JS 通过修改这些对象，就能实时改变页面的内容和外观——不需要重新加载页面。网页能做到"点了按钮立刻变化"，靠的就是 DOM 操作。

第一步是"找到"元素。document 是浏览器提供的入口对象，querySelector 用 CSS 选择器语法查找元素，用法和你写样式选择器一模一样：

```html
<!DOCTYPE html>
<html>
  <body>
    <h1 id="title">标题</h1>
    <p class="intro">这是一段介绍。</p>
    <button id="btn">点我</button>

    <script>
      // querySelector 用 CSS 选择器找元素：# 表示 id，. 表示 class
      const title = document.querySelector("#title");
      const intro = document.querySelector(".intro");
      const btn = document.querySelector("#btn");

      // 修改内容和样式
      title.textContent = "DOM 操作真简单";
      intro.style.color = "steelblue";
    </script>
  </body>
</html>
```

把这段代码保存成 HTML 文件打开：标题文字变了，介绍文字变成了蓝色。textContent 负责改文本，style 负责改样式，这几个属性是最常用的修改手段。

找到元素之后，更重要的本领是"响应"用户操作：给元素挂上事件监听器，指定某个事件发生时执行哪个函数。最常见的事件是 click，语法是 addEventListener(事件名, 处理函数)：

```javascript
// 接上文的 script，继续写在同一个 script 标签里
let count = 0;

btn.addEventListener("click", () => {
  count++;  // 每点一次加 1
  btn.textContent = `点了 ${count} 次`;
});
```

运行后每点一次按钮，按钮上的数字就加一。这两行是网页交互的标准范式：选择元素、监听事件、修改页面——99% 的前端交互都由这个循环构成。

常用的事件和属性先记住这一批，够写大多数交互效果：

- click：点击；input：输入框内容变化；submit：表单提交；keydown：键盘按下；
- textContent：读写纯文本内容；
- value：读写输入框的值（`input.value`）；
- style.xxx：改内联样式，如 `el.style.fontSize = "20px"`；
- classList.add / remove / toggle：增删类名，配合 CSS 切换外观是最优雅的改样式方式；
- document.createElement 加 appendChild：动态创建并插入新元素。

再示范一个读写输入框的完整小交互，输入名字、点按钮、打招呼：

```javascript
// HTML 里加一行：<input id="nameInput" placeholder="输入名字" />
// 以及一个按钮：<button id="helloBtn">打招呼</button>
const nameInput = document.querySelector("#nameInput");
const helloBtn = document.querySelector("#helloBtn");

helloBtn.addEventListener("click", () => {
  title.textContent = `你好，${nameInput.value}！`;  // 读取输入框的值
  nameInput.value = "";  // 清空输入框
});
```

要找的元素常常不止一个，querySelectorAll 用同样的选择器语法返回所有匹配的集合，配合 forEach 逐个处理，比如给页面里所有 class 含 item 的元素统一改颜色。还有一个新手必踩的坑：script 标签如果写在 body 顶部，执行时下面的元素还不存在，querySelector 会返回 null，接着读写属性就报错。解决办法很简单：像本章示例那样把 script 放在 body 末尾，或者给标签加上 defer 属性，让浏览器解析完 HTML 再执行脚本。以后看到 Cannot read properties of null 这样的报错，先检查是不是元素没找到。本章的两个示例页面建议亲手各写一遍，DOM 的手感只能靠敲出来。动手时故意把 id 写错一次，看看报错长什么样，以后遇到了就不慌。

小结：DOM 是页面的对象化表示，querySelector 负责找，textContent/style/classList 负责改，addEventListener 负责听。"找元素、挂事件、改页面"这个三步范式，建议用计数按钮和打招呼两个例子反复练熟。

下一步：第 6 章学习 JS 的异步编程——网络请求、定时任务背后的运行机制。
