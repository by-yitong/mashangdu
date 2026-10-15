## 第5章 · 多表连接 JOIN

真实项目里的数据不会挤在一张表里：客户表只管客户信息，订单表只管订单，两张表靠"编号"互相引用——订单里存着下单客户的 id。这种设计避免了重复存储客户姓名几百遍。而查询时把分开的数据重新拼起来，靠的就是 JOIN（连接）。先建两张演示表：

```sql
-- 客户表
CREATE TABLE customers (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

-- 订单表：customer_id 指向 customers.id，叫外键
CREATE TABLE orders (
    id          INTEGER PRIMARY KEY,
    customer_id INTEGER,
    amount      INTEGER
);

INSERT INTO customers VALUES (1, '小明'), (2, '小红'), (3, '小刚');
INSERT INTO orders VALUES
    (101, 1, 250),
    (102, 1, 80),
    (103, 2, 300);
-- 注意：小刚（id=3）没有下过单
```

最常用的是 INNER JOIN（内连接）：把两张表按连接条件一行对一行拼起来，只保留两边都能匹配上的组合。连接条件写在 ON 后面，通常就是"外表的外键等于主表的主键"：

```sql
-- INNER JOIN：每笔订单显示客户姓名；小刚没有订单，不会出现
SELECT customers.name, orders.id, orders.amount
FROM orders
JOIN customers ON orders.customer_id = customers.id;

-- 结果：小明 101 250 / 小明 102 80 / 小红 103 300
```

给表起别名能让连接查询短很多，尤其表名长或涉及多张表时。写法是在 FROM 或 JOIN 后面表名跟一个别名，之后都用别名指代：

```sql
-- 用别名简写：o 代表 orders，c 代表 customers
SELECT c.name, o.id, o.amount
FROM orders AS o
JOIN customers AS c ON o.customer_id = c.id;
```

内连接的"只留匹配"有时不符合需要：想知道每个客户下没下过单（包括小刚），就要用 LEFT JOIN（左连接）。它保留左表全部行，右表匹配不上的位置填 NULL——"没有"在 SQL 里的标准表达方式就是 NULL，正好接上第 3 章学的 IS NULL：

```sql
-- LEFT JOIN：左表（customers）全保留，没下单的客户订单列是 NULL
SELECT c.name, o.id, o.amount
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id;

-- 结果包含：小刚 NULL NULL

-- 顺着这个思路一步到位：找出还没下过单的客户
SELECT c.name
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
WHERE o.id IS NULL;
```

"LEFT JOIN 加 IS NULL 找差异"是 SQL 的经典套路，面试和实际工作都常出现，值得记住。连接和第 4 章的分组组合起来就是报表的雏形——每个客户的累计消费：

```sql
-- JOIN 配合 GROUP BY：每个客户的订单数和累计金额
SELECT c.name, COUNT(o.id) AS 订单数, SUM(o.amount) AS 累计金额
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
GROUP BY c.name;
-- SUM 忽略 NULL，所以小刚的累计金额是 NULL 而不是 0；介意的话用 IFNULL(SUM(o.amount), 0)
```

表多于两张时，继续往后追加 JOIN 即可，比如学生表、选课表、课程表三表相连，每多一张表就多一个 JOIN 加 ON。思考方式不变：想清楚每一步"拿哪张表、按哪个键对哪个键"。

还有一种特殊形态叫自连接：表和它自己连接。典型场景是员工表里有一列"经理编号"也指向本表，查询"员工和他的经理姓名"时，就把同一张表当成两张表来连接，用别名区分"员工视角"和"经理视角"。听起来绕，本质仍是同一套 ON 匹配逻辑，以后碰到层级关系的数据（组织架构、分类目录）时会用上。

小结：JOIN 按 ON 条件拼表，INNER JOIN 只要匹配的，LEFT JOIN 保左表全量、缺口填 NULL，"LEFT JOIN 加 IS NULL"找没有匹配的行，别名让长查询变短，JOIN 加 GROUP BY 是统计报表的标配。练习建议：给本章加一张 products 表和订单明细，查出每个客户买过哪些商品。

下一步：恭喜完成 SQL 入门全部课程。可以找一份真实数据集（如电影、图书数据）导入 SQLite，把五章所学的查询从头练一遍，SQL 的功力全靠在真实数据上摸爬滚打。
