## 第3章 · WHERE 排序与限制

上一章的 SELECT 总是返回全表，真实场景里我们只关心满足条件的那部分：80 分以上的学生、一班的同学、分数最高的三个人。干这三件事分别靠 WHERE 过滤、ORDER BY 排序、LIMIT 限制行数，它们是查询语句里出场率最高的三件套。

WHERE 写在 FROM 后面，接一个对每一行求值的条件，只有条件为真的行才会出现在结果里。比较运算符和逻辑运算符与大多数语言类似，但不等号是 `<>`：

```sql
-- WHERE 过滤行：支持 =、<>、>、<、>=、<=
SELECT * FROM students WHERE score >= 80;

-- AND / OR / NOT 组合条件；AND 优先级高于 OR，拿不准就加括号
SELECT * FROM students WHERE class = '一班' AND score >= 80;

-- BETWEEN 含两端；IN 匹配列表中的任意一个值
SELECT * FROM students WHERE score BETWEEN 80 AND 90;
SELECT * FROM students WHERE class IN ('一班', '三班');

-- LIKE 模糊匹配：% 匹配任意多个字符，_ 匹配一个字符
SELECT * FROM students WHERE name LIKE '小%';

-- NULL 的判断必须用 IS NULL / IS NOT NULL，写 = NULL 永远查不到
SELECT * FROM students WHERE score IS NULL;
```

两个高频错误在这里强调一遍：一是 `WHERE score = NULL` 永远返回空结果，因为 NULL 和任何值比较的结果都是"未知"，必须用 IS NULL；二是文本比较默认不区分大小写与否取决于具体数据库的配置，需要严格区分时先查所用数据库的文档（SQLite 默认区分，MySQL 常见配置不区分）。

WHERE 负责挑出哪些行，ORDER BY 决定这些行按什么顺序展示，LIMIT 控制最多返回几行。三者常常连用，构成一条完整的查询：

```sql
-- 按分数从高到低排序；DESC 降序，ASC 升序（默认，可省略）
SELECT name, score FROM students ORDER BY score DESC;

-- 多列排序：先按班级升序，同班内再按分数降序
SELECT name, class, score FROM students ORDER BY class ASC, score DESC;

-- 组合拳：一班里分数最高的前 2 个人
SELECT name, score FROM students
WHERE class = '一班'
ORDER BY score DESC
LIMIT 2;
```

最后这条"WHERE 加 ORDER BY 加 LIMIT"的组合值得单独品味：它是排行榜、首页推荐、分页列表这类功能的标准雏形，真实项目里你可能每天都要写它。注意书写顺序不能乱——WHERE 在前、ORDER BY 在后、LIMIT 收尾，数据库按这个固定顺序解析。

此外，这三个子句的执行顺序和书写顺序不同：先执行 WHERE（过滤行），再执行 ORDER BY（排序），最后 LIMIT（截断）。理解这一点，以后遇到"为什么别名在 WHERE 里用不了"之类的问题就有了答案——执行到 WHERE 时，SELECT 阶段定义的别名还不存在。

两个常用件补充给你：条件前加 NOT 可以取反，如 WHERE NOT (score >= 60) 等价于查不及格的人；LIKE 也支持 NOT LIKE。单字符通配符 _ 表示恰好一个字符，'小_' 匹配所有两个字符且以"小"开头的名字。条件一多容易出现优先级歧义，与其背诵 AND 高于 OR，不如在该加括号的地方都加上括号——查询的正确性永远比简洁重要。每写一个条件先单独跑一遍，确认结果对了再组合。把同一张表反复查：加一个条件看一次结果，条件之间是交集还是并集，眼睛看过的才是真的懂。

小结：WHERE 用比较、逻辑、BETWEEN、IN、LIKE 挑行，NULL 必须用 IS NULL 判断；ORDER BY 排序，DESC 降序 ASC 升序，支持多列；LIMIT 截取前几行。练习建议：查出"分数在 70 到 90 之间、按分数升序排列的前 5 名"。

下一步：第 4 章学习聚合函数与分组，开始做"全班的平均分"这样的统计。
