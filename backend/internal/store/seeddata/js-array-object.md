## 第4章 · 数组与对象

单个变量只够装一个值，真实数据总是成批出现。JS 用数组（Array）装有序的一串数据，用对象（Object）按名字存取数据，两者组合能表达任意复杂的数据结构——网页接口返回的 JSON，本质就是数组和对象的嵌套。

数组的基本操作：下标从 0 开始，length 看长度，push 从尾部添加。更强大的是一组接收回调函数的方法，它们用几行代码完成过去要写循环才能完成的数据加工：

```javascript
const fruits = ["苹果", "香蕉", "橘子"];

fruits.push("葡萄");          // 末尾添加
console.log(fruits.length);  // 4
console.log(fruits[0]);      // 苹果

// map：对每个元素加工一遍，返回新数组
const lengths = fruits.map((f) => f.length);
console.log(lengths);        // [2, 2, 2, 2]

// filter：按条件筛选，留下返回 true 的元素，返回新数组
const nums = [12, 7, 20, 3, 15];
console.log(nums.filter((n) => n > 10)); // [12, 20, 15]

// forEach：挨个处理，没有返回值
fruits.forEach((f, i) => console.log(i, f));
```

map 加工、filter 筛选、forEach 遍历，这三板斧覆盖了数组操作的绝大部分场景，务必亲手各写一遍。对象则是另一套思路：用键值对把一组相关信息聚在一起，键叫属性，属性可以是任何值，也可以是函数——属性值是函数时，我们叫它方法：

```javascript
const student = {
  name: "小明",
  age: 12,
  scores: [90, 85],
  introduce() {
    console.log(`我叫${this.name}，今年${this.age}岁`);
  },
};

console.log(student.name);     // 点号访问
console.log(student["age"]);   // 方括号访问，键名是变量时只能用它
student.grade = "六年级";       // 随时添加新属性

student.introduce();           // 我叫小明，今年12岁
console.log(Object.keys(student));   // ['name', 'age', 'scores', 'introduce', 'grade']
```

注意 introduce 方法里的 this：它指代调用这个方法的对象，所以 this.name 就是 student.name。这是普通函数作为方法时的行为，也是第 3 章说的"箭头函数没有自己 this"要防的场景——对象方法请用普通写法（如上），回调函数用箭头写法，通常就不会踩坑。

把数组和对象组合起来，就有了描述真实业务的能力，这是网页开发最常见的数据形态：

```javascript
// 对象套数组，数组里又是对象：一个班级的花名册
const classOne = {
  name: "一班",
  students: [
    { name: "小明", score: 90 },
    { name: "小红", score: 85 },
  ],
};

// 组合使用：筛选加加工一步到位
const names = classOne.students
  .filter((s) => s.score >= 88)
  .map((s) => s.name);
console.log(names);  // ['小明']
```

几条实用经验：

- 判断数组里有没有某个元素用 includes；找第一个满足条件的元素用 find；
- 展开运算符 `...` 可以快速复制数组或合并对象：`const b = [...a]`；
- 数组排序 sort 默认按字符串比较，排数字要传比较函数 `(a, b) => a - b`；
- 访问不存在的属性返回 undefined（不会报错），但访问 undefined 的属性就会报错，链式取值要小心；
- 对象方法简写 `introduce() {}` 等价于 `introduce: function() {}`，前者更常用。

再记三个查询类方法：find 返回第一个满足条件的元素本身，找不到返回 undefined；some 判断"是否至少有一个满足"，every 判断"是否全部满足"，都返回布尔值；reduce 则把数组归约成一个值，比如求和写 (acc, n) => acc + n，初学时用得少，但读别人的代码会经常遇到，先知道有这个东西即可。注意 map 和 filter 都返回新数组、不改原数组，这一点和 push 不同，要分清。

小结：数组管列表，map/filter/forEach 是核心三件套；对象管描述，属性加方法，this 指向调用者；两者嵌套就是 JSON 的世界。练习建议：写一个商品数组（名称加价格），用 filter 挑出 100 元以下的，再用 map 取出名称打印。

下一步：第 5 章学习 DOM 操作，让 JS 真正操控网页。
