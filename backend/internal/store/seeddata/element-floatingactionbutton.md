```kotlin
@OptIn(markerClass = [ExperimentalMaterialApi])
@Composable
fun FloatingActionButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    shape: Shape = MaterialTheme.shapes.small.copy(CornerSize(percent = 50)),
    backgroundColor: Color = MaterialTheme.colors.secondary,
    contentColor: Color = contentColorFor(backgroundColor),
    elevation: FloatingActionButtonElevation = FloatingActionButtonDefaults.elevation(),
    content: () -> Unit
): @OptIn(markerClass = [ExperimentalMaterialApi]) @Composable Unit
```

## 1. 概述

[Material Design floating action button](https://material.io/components/buttons-floating-action-button)

一个 `FloatActionButton`（FAB）代表一个屏幕的主要行为。

![](images/jetpack-compose/element-floatingactionbutton/demo.png)

`FAB` 通常和一个 `Icon` 一起使用

```kotlin
import androidx.compose.material.FloatingActionButton
import androidx.compose.material.Icon

FloatingActionButton(onClick = { /*do something*/ }) {
    Icon(Icons.Filled.Favorite, contentDescription = "Localized description")
}
```

除了普通的 FAB 之外，Compose 也提供了带有文字扩展的 FAB， `ExtendedFloatingActionButton`

```kotlin
ExtendedFloatingActionButton(
  icon = { Icon(Icons.Filled.Favorite, contentDescription = null) },
  text = { Text("添加到我喜欢的") },
  onClick = { /*do something*/ }
)
```

![](images/jetpack-compose/element-floatingactionbutton/demo2.png)

> 本文来自 [你好 Compose](https://jetpackcompose.cn/docs/)，作者 compose-museum，采用 [CC BY-NC-SA 2.0](https://creativecommons.org/licenses/by-nc-sa/2.0/) 授权转载，禁止商用。
