## 第4章 · 聚合与分组

前面的查询都是"一行对一行"，这一章升级到"多行算一个数"：全班平均分、总人数、最高分。做这类统计的是聚合函数——它们接收一组值，返回一个汇总结果。SQL 一共五个常用聚合函数，记全很容易：

```sql
-- 五个聚合函数：对多行求一个结果
SELECT COUNT(*) FROM students;            -- 行数（学生人数）
SELECT AVG(score) FROM students;          -- 平均分
SELECT SUM(score) FROM students;          -- 总分
SELECT MAX(score), MIN(score) FROM students;  -- 最高分和最低分
```

COUNT 是其中最特别的：`COUNT(*)` 数行数，`COUNT(列名)` 数这一列非空的行数，两者在有 NULL 时结果不同，按需选择。另外 AVG、SUM、MIN、MAX 会自动忽略 NULL，"有人没参加考试"时平均分只会统计考了的人，这个默认行为通常正是想要的。

一个数字还不够，更常见的需求是"按班级分别统计"。GROUP BY 就是分组开关：它把行按指定列的值分堆，聚合函数对每一堆各算一个结果：

```sql
-- 按班级分组：每个班一行统计结果
SELECT class, COUNT(*) AS 人数, AVG(score) AS 平均分
FROM students
GROUP BY class;

-- 分组前可以先过滤：只统计分数及格的学生的班级情况
SELECT class, COUNT(*) AS 人数
FROM students
WHERE score >= 60
GROUP BY class;
```

规则只有一条但要刻在脑子里：SELECT 里出现的列，要么写在 GROUP BY 后面，要么包进聚合函数里，不能单独出现。道理很简单——分组后一个班的分数有很多个，单独放 score 进 SELECT 数据库不知道该显示哪一个；而 class 是分组依据，每个组内只有一种取值，所以可以放。

分组之后还想筛选"组"怎么办？比如"只要平均分超过 80 的班级"。这时不能用 WHERE，因为 WHERE 在分组之前执行，那时还没有"平均分"这个概念。SQL 为此准备了 HAVING，它专门过滤分组结果：

```sql
-- HAVING 过滤分组结果：只保留平均分大于 80 的班级
SELECT class, AVG(score) AS 平均分
FROM students
GROUP BY class
HAVING AVG(score) > 80;
```

WHERE 和 HAVING 的分工可以这样记：WHERE 过滤"行"，写在 GROUP BY 前；HAVING 过滤"组"，写在 GROUP BY 后。两者也可以同时出现，一次查询里各司其职。整条查询的执行顺序至此完整了：FROM 取表 -> WHERE 过滤行 -> GROUP BY 分组 -> HAVING 过滤组 -> SELECT 投影 -> ORDER BY 排序 -> LIMIT 截断。把这条链记住，以后读任何复杂查询都有章可循。

两个常用组合补充给你：COUNT(DISTINCT class) 可以统计去重后的班级数量；AVG 的结果小数位很长时，用 ROUND(AVG(score), 1) 保留一位小数，报表会清爽很多。另外聚合函数会自动忽略 NULL，所以"平均分"统计的是有分数的人；若想把没分数的当 0 分计入平均，得先把空值替换成 0 再聚合，具体函数查所用数据库的文档（SQLite 里是 IFNULL）。聚合数字对不对，最好拿一两条手算的记录抽查验证，这是数据工作的基本素养。先 COUNT 再 GROUP BY，分步验证是写分组查询的稳妥路径。本章查询都不改动数据，放心大胆地反复试。

小结：五个聚合函数负责汇总，GROUP BY 负责分组，HAVING 负责筛组，SELECT 列要么进 GROUP BY 要么进聚合函数。练习建议：统计每个班的人数和最高分，并只保留人数大于 1 的班级。

下一步：第 5 章学习 JOIN，让分散在多张表里的数据重新汇合——SQL 最精华的部分。
