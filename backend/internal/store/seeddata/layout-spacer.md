```kotlin
@Composable
fun Spacer(modifier: Modifier): @Composable Unit
```

`Spacer` 能够提供一个空白的布局，可以使用 `Modifier.width`, `Modifier.height` 和 `Modifier.size` 来填充

```kotlin
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width

Row {
    Box(Modifier.size(100.dp).background(Color.Red))
    Spacer(Modifier.width(20.dp))
    Box(Modifier.size(100.dp).background(Color.Magenta))
    Spacer(Modifier.weight(1f))
    Box(Modifier.size(100.dp).background(Color.Black))
}

```

![](images/jetpack-compose/layout-spacer/demo.png)

> 本文来自 [你好 Compose](https://jetpackcompose.cn/docs/)，作者 compose-museum，采用 [CC BY-NC-SA 2.0](https://creativecommons.org/licenses/by-nc-sa/2.0/) 授权转载，禁止商用。
