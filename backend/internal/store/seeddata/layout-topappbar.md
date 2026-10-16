```kotlin
@Composable
fun TopAppBar(
    title: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    navigationIcon: @Composable (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    backgroundColor: Color = MaterialTheme.colors.primarySurface,
    contentColor: Color = contentColorFor(backgroundColor),
    elevation: Dp = AppBarDefaults.TopAppBarElevation
)
```

`Jetpack Compose` 为我们准备了基于 `Material Design` 风格设计的 `TopAppBar` 组件。

接下来让我们看看怎么使用吧！

```kotlin
@Composable
fun ScaffoldDemo(){
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text("主页")
                },
                navigationIcon = {
                    IconButton(
                        onClick = { }
                    ) {
                        Icon(Icons.Filled.ArrowBack, null)
                    }
                }
            )
        },
    ) {

    }
}
```

![](images/jetpack-compose/layout-topappbar/demo.png)

还可以设置 `TopAppBar` 中的 `actions` 参数

```kotlin
@Composable
fun ScaffoldDemo(){
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text("主页")
                },
                navigationIcon = {
                    IconButton(
                        onClick = { } //do something
                    ) {
                        Icon(Icons.Filled.ArrowBack, null)
                    }
                },
                actions = {
                    IconButton(
                        onClick = { } //do something
                    ) {
                        Icon(Icons.Filled.Search, null)
                    }
                    IconButton(
                        onClick = { } //do something
                    ) {
                        Icon(Icons.Filled.MoreVert, null)
                    }
                }
            )
        },
    ) {

    }
}
```

它会将里面的内容以 `Row` 的方式来排列

![](images/jetpack-compose/layout-topappbar/demo2.png)

> 本文来自 [你好 Compose](https://jetpackcompose.cn/docs/)，作者 compose-museum，采用 [CC BY-NC-SA 2.0](https://creativecommons.org/licenses/by-nc-sa/2.0/) 授权转载，禁止商用。
