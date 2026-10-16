所有权（系统）是 Rust 最为与众不同的特性，它让 Rust 无需垃圾回收（garbage collector）即可保障内存安全。因此，理解 Rust 中所有权如何工作是十分重要的。本章，我们将讲到所有权以及相关功能：借用、slice 以及 Rust 如何在内存中布局数据。

---

> 本文来自 [《Rust 程序设计语言》中文版](https://github.com/KaiserY/trpl-zh-cn)（Steve Klabnik、Carol Nichols 著，Rust 中文社区翻译），依据 MIT 许可转载；英文原版：[The Rust Programming Language](https://doc.rust-lang.org/stable/book/)。
