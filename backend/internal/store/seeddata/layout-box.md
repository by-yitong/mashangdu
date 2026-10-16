Box 是一个能够将里面的子项依次按照顺序堆叠的布局组件。

```kotlin
Box {
    Box(
        modifier = Modifier.size(150.dp).background(Color.Green)
    )
    Box(
        modifier = Modifier.size(80.dp).background(Color.Red)
    )
    Text(
        text = "世界"
    )
}
```

![](images/jetpack-compose/layout-box/demo.png)

> 本文来自 [你好 Compose](https://jetpackcompose.cn/docs/)，作者 compose-museum，采用 [CC BY-NC-SA 2.0](https://creativecommons.org/licenses/by-nc-sa/2.0/) 授权转载，禁止商用。
