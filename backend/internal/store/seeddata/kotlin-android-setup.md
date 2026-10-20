## 安装 Kotlin 插件

Android Studio 从 3.0（preview）版本开始将内置安装 Kotlin 插件。

打开 Settings ( Mac 为 Preferences) 面板，在右侧找到 Plugins 选项 (快捷键 Ctrl+, Mac 下为 command+)，搜索框输入 "Kotlin" 查找，点击 Search in repositories(仓库中搜索)，然后安装即可，安装完成之后需要重启 Android Studio。

![](images/kotlin/kotlin-android-setup/1495852874-4548-qiddj00bpde497.png)

![](images/kotlin/kotlin-android-setup/1495852999-3315-qqf4ub25vet500.png)

---

## 创建新工程

选择 Start a new Android Studio project 或者 File | New project，大多数选项均有默认值 ，只需要按几次"回车"键即可。

![](images/kotlin/kotlin-android-setup/1495853720-4994-0-create-new-project.png)

Android Studio 3.0 在当前对话框中提供启用 Kotlin 支持的选项，勾选后可以跳过 "配置 Kotlin 工程（Configuring Kotlin in the project）"的步骤。

选择 Android 版本:

![](images/kotlin/kotlin-android-setup/1495853670-8308-1-create-new-project.png)

选择需要创建的 Activity 样式:

![](images/kotlin/kotlin-android-setup/1495853838-1520-0-create-new-project.png)

命名该 Activity:

![](images/kotlin/kotlin-android-setup/1495853838-8955-1-create-new-project.png)

在 Android Studio 3.0 中，可以选择使用 Kotlin 创建 activity，因此也不需要"将Java 代码转换为 Kotlin（Converting Java code to Kotlin）"这一步骤。

早期版本中则会先使用 Java 创建 activity，然后再使用自动转换工具 进行转换。

---

## 将 Java 代码转换为 Kotlin

重新打开Android Studio，新建一个Android项目吧，添加一个默认的MainActivity

打开 MainActivity.java 文件，通过菜单栏依次调出 Code | Convert Java File to Kotlin File：

![](images/kotlin/kotlin-android-setup/1495854751-7389-convert-java-to-kotlin.png)

转换完成后即可看到使用 Kotlin 编写的 activity。

![](images/kotlin/kotlin-android-setup/1495854753-3864-converted-code.png)

### 工程中配置 Kotlin

在开始编辑此文件时，Android Studio 会提示当前工程还未配置 Kotlin，根据提示完成操作即可，或者可以在菜单栏中选择 Tools

![](images/kotlin/kotlin-android-setup/1495854757-6620-kotlin-not-configured.png)

选择配置时有如下对话框，选择已安装的最新版本即可。

![](images/kotlin/kotlin-android-setup/1495854752-7001-re-kotlin-in-project-details.png)

Kotlin 配置完成后，应用程序的 build.gradle 文件会更新。 你能看到新增了 apply plugin: 'kotlin-android' 及其依赖。

![](images/kotlin/kotlin-android-setup/1495854750-1825-sync-project-with-gradle.png)

同步工程，在提示框中点击"立即同步（Sync Now）"或者使用 Sync Project with Gradle Files命令。

![](images/kotlin/kotlin-android-setup/1495854764-6190-sync-project-with-gradle-2.png)

> 本文转载自 [菜鸟教程 runoob.com](https://www.runoob.com/kotlin/otlin-android-setup.html)，版权归原作者所有，仅供非商业学习使用。
