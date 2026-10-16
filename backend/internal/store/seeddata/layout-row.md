```kotlin
@Composable
inline fun Row(
    modifier: Modifier? = Modifier,
    horizontalArrangement: Arrangement.Horizontal? = Arrangement.Start,
    verticalAlignment: Alignment.Vertical? = Alignment.Top,
    content: (@Composable @ExtensionFunctionType RowScope.() -> Unit)?
): Unit
```

Row 组件能够将里面的子项按照从左到右的方向水平排列。和 Column 组件一起配合，我们可以构建出很丰富的界面。

我们来试试制作一个简单的帖子界面。

```kotlin
 Surface(
    shape = RoundedCornerShape(8.dp),
    modifier = Modifier
        .padding(horizontal = 12.dp) // 设置 Surface 的外边距
        .fillMaxWidth(),
    elevation = 10.dp
) {
    Column(
        modifier = Modifier.padding(12.dp) // 里面内容的外边距
    ) {
        Text(
            text = "Jetpack Compose 是什么？",
            style = MaterialTheme.typography.h6
        )
        Spacer(Modifier.padding(vertical = 5.dp))
        Text(
            text = "Jetpack Compose 是用于构建原生 Android 界面的新工具包。它可简化并加快 Android 上的界面开发，使用更少的代码、强大的工具和直观的 Kotlin API，快速让应用生动而精彩。"
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            IconButton(
                onClick = { /*TODO*/ }
            ) {
                Icon(Icons.Filled.Favorite, null)
            }
            IconButton(
                onClick = { /*TODO*/ },
            ) {
                Icon(painterResource(id = R.drawable.chat), null)
            }
            IconButton(
                onClick = { /*TODO*/ },
            ) {
                Icon(Icons.Filled.Share, null)
            }
        }
    }
}
```

![](images/jetpack-compose/layout-row/demo.png)


Row 组件中的 horizontalArrangement 参数帮助我们合理地分配了按钮的水平位置，可以看到，喜欢按钮和分享按钮被分配在了左右两边，事实上，Arrangment 就是来帮助我们快速安排好子项的位置，除了 Center（居中）, Start（水平靠左）, End（水平靠右） 这些常见的位置，还有一些在特定场景下可能用到的位置分布，例如 Space Between, Space Evenly 等等。

![](images/jetpack-compose/layout-row/demo2.png)

> 本文来自 [你好 Compose](https://jetpackcompose.cn/docs/)，作者 compose-museum，采用 [CC BY-NC-SA 2.0](https://creativecommons.org/licenses/by-nc-sa/2.0/) 授权转载，禁止商用。
