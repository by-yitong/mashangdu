Cargo 的设计使得开发者可以通过新的子命令来对 Cargo 进行扩展，而无需修改 Cargo 本身。如果 `$PATH` 中有类似 `cargo-something` 的二进制文件，就可以通过 `cargo something` 来像 Cargo 子命令一样运行它。像这样的自定义命令也可以运行 `cargo --list` 来展示出来。能够通过 `cargo install` 向 Cargo 安装扩展并可以如内建 Cargo 工具那样运行他们是 Cargo 设计上的一个非常方便的优点！

## 总结

通过 Cargo 和 [crates.io](https://crates.io/) 来分享代码是使得 Rust 生态环境可以用于许多不同的任务的重要组成部分。Rust 的标准库是小而稳定的，不过 crate 易于分享和使用，并采用一个不同语言自身的时间线来提供改进。不要羞于在 [crates.io](https://crates.io/) 上共享对你有用的代码；因为它很有可能对别人也很有用！

---

> 本文来自 [《Rust 程序设计语言》中文版](https://github.com/KaiserY/trpl-zh-cn)（Steve Klabnik、Carol Nichols 著，Rust 中文社区翻译），依据 MIT 许可转载；英文原版：[The Rust Programming Language](https://doc.rust-lang.org/stable/book/)。
