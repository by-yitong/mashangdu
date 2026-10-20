#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性爬取脚本：runoob.com Kotlin 教程 -> 课程种子数据。

抓取 https://www.runoob.com/kotlin/ 全部 43 章，转换为 markdown：
  - backend/internal/store/seeddata/kotlin-*.md        （43 个章节文件）
  - backend/internal/store/seeddata/courses.json       （追加 kotlin 课程条目，幂等）
  - backend/static/images/kotlin/<章slug>/<文件名>      （自托管图片）

用法（在仓库根目录执行）：python tools/runoob_to_seed.py

仅使用 stdlib。不修改任何 Go/React/Flutter 代码，不做 git 操作。
"""

import html as html_mod
import json
import os
import re
import sys
import time
import urllib.request
from html.parser import HTMLParser

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED_DIR = os.path.join(REPO_ROOT, "backend", "internal", "store", "seeddata")
COURSES_JSON = os.path.join(SEED_DIR, "courses.json")
IMG_ROOT = os.path.join(REPO_ROOT, "backend", "static", "images", "kotlin")
COURSE_SLUG = "kotlin"
BASE = "https://www.runoob.com"
ENTRY_URL = BASE + "/kotlin/kotlin-tutorial.html"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
SLEEP = 0.3
RETRIES = 3

# 冻结的权威章节清单（顺序、标题、md 文件名；第 6 章修正站方 typo URL，
# 站方真实 URL 为 /kotlin/otlin-android-setup.html）。
# 运行时仍会从入口页左栏导航重新提取并比对，不一致即中止。
EXPECTED_CHAPTERS = [
    ("Kotlin 教程", "/kotlin/kotlin-tutorial.html", "kotlin-tutorial"),
    ("Kotlin 简介", "/kotlin/kotlin-intro.html", "kotlin-intro"),
    ("Kotlin 环境搭建", "/kotlin/kotlin-environment.html", "kotlin-environment"),
    ("Kotlin IntelliJ IDEA 环境搭建", "/kotlin/kotlin-setup.html", "kotlin-setup"),
    ("Kotlin 使用命令行编译", "/kotlin/kotlin-command-line.html", "kotlin-command-line"),
    ("Kotlin Android 环境搭建", "/kotlin/otlin-android-setup.html", "kotlin-android-setup"),
    ("Kotlin 基础语法", "/kotlin/kotlin-basic-syntax.html", "kotlin-basic-syntax"),
    ("Kotlin 基本数据类型", "/kotlin/kotlin-basic-types.html", "kotlin-basic-types"),
    ("Kotlin 字符串与正则", "/kotlin/kotlin-string.html", "kotlin-string"),
    ("Kotlin 运算符与位运算", "/kotlin/kotlin-operators.html", "kotlin-operators"),
    ("Kotlin 条件控制", "/kotlin/kotlin-condition-control.html", "kotlin-condition-control"),
    ("Kotlin 循环控制", "/kotlin/kotlin-loop-control.html", "kotlin-loop-control"),
    ("Kotlin 函数", "/kotlin/kotlin-function.html", "kotlin-function"),
    ("Kotlin Lambda 高阶函数", "/kotlin/kotlin-lambda.html", "kotlin-lambda"),
    ("Kotlin 内联函数与 reified", "/kotlin/kotlin-inline-function.html", "kotlin-inline-function"),
    ("Kotlin 作用域函数", "/kotlin/kotlin-scope-functions.html", "kotlin-scope-functions"),
    ("Kotlin 类和对象", "/kotlin/kotlin-class-object.html", "kotlin-class-object"),
    ("Kotlin 继承", "/kotlin/kotlin-extend.html", "kotlin-extend"),
    ("Kotlin 接口", "/kotlin/kotlin-interface.html", "kotlin-interface"),
    ("Kotlin 可见性修饰符", "/kotlin/kotlin-visibility.html", "kotlin-visibility"),
    ("Kotlin 数据类与解构", "/kotlin/kotlin-data-class.html", "kotlin-data-class"),
    ("Kotlin 扩展", "/kotlin/kotlin-extensions.html", "kotlin-extensions"),
    ("Kotlin 数据类与密封类", "/kotlin/kotlin-sealed-class.html", "kotlin-sealed-class"),
    ("Kotlin 泛型", "/kotlin/kotlin-generics.html", "kotlin-generics"),
    ("Kotlin 枚举类", "/kotlin/kotlin-enum-classes.html", "kotlin-enum-classes"),
    ("Kotlin 对象表达式与对象声明", "/kotlin/kotlin-object-declarations.html", "kotlin-object-declarations"),
    ("kotlin 委托", "/kotlin/kotlin-delegated.html", "kotlin-delegated"),
    ("Kotlin 值类", "/kotlin/kotlin-value-class.html", "kotlin-value-class"),
    ("Kotlin 运算符重载", "/kotlin/kotlin-operator.html", "kotlin-operator"),
    ("Kotlin 空安全", "/kotlin/kotlin-null-safety.html", "kotlin-null-safety"),
    ("Kotlin 集合", "/kotlin/kotlin-collections.html", "kotlin-collections"),
    ("Kotlin 集合操作", "/kotlin/kotlin-collection-ops.html", "kotlin-collection-ops"),
    ("Kotlin 序列", "/kotlin/kotlin-sequence.html", "kotlin-sequence"),
    ("Kotlin 异常处理", "/kotlin/kotlin-exception.html", "kotlin-exception"),
    ("Kotlin 注解", "/kotlin/kotlin-annotation.html", "kotlin-annotation"),
    ("Kotlin 反射", "/kotlin/kotlin-reflection.html", "kotlin-reflection"),
    ("Kotlin 协程", "/kotlin/kotlin-coroutines.html", "kotlin-coroutines"),
    ("Kotlin Java 互操作", "/kotlin/kotlin-java-interop.html", "kotlin-java-interop"),
    ("Kotlin 多平台与 Kotlin/JS、Native", "/kotlin/kotlin-multiplatform.html", "kotlin-multiplatform"),
    ("Kotlin Gradle 构建", "/kotlin/kotlin-gradle.html", "kotlin-gradle"),
    ("Kotlin 测试", "/kotlin/kotlin-testing.html", "kotlin-testing"),
    ("Kotlin 编码规范与惯用法", "/kotlin/kotlin-style.html", "kotlin-style"),
    ("Kotlin 各版本新特性速查", "/kotlin/kotlin-new-features.html", "kotlin-new-features"),
]

COURSE_ENTRY = {
    "slug": COURSE_SLUG,
    "title": "Kotlin 教程",
    "summary": "Kotlin 从基础语法、面向对象到集合、协程与工程实践的中文入门教程。内容来自菜鸟教程 runoob.com，限于非商业学习目的转载，版权归原作者所有。",
    "language": "Kotlin",
    "color": "#0D9488",
    "sort_order": 8,
}

RUN_WORDS = ("点击运行", "运行实例", "在线实例", "尝试一下")
DROP_TAGS = {"script", "style", "ins", "iframe", "form", "nav"}
GRADLE_MARKERS = ("implementation ", "dependencies", "android {", "plugins {",
                  "buildscript", "apply plugin")


# ---------------------------------------------------------------- 取网页

def fetch(url):
    """GET 文本（UTF-8），失败重试 3 次（指数退避）。"""
    last_err = None
    for attempt in range(RETRIES):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            last_err = e
            if attempt < RETRIES - 1:
                time.sleep(2 ** attempt)
    raise RuntimeError("fetch failed after %d retries: %s (%s)" % (RETRIES, url, last_err))


def fetch_bytes(url):
    last_err = None
    for attempt in range(RETRIES):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.read()
        except Exception as e:  # noqa: BLE001
            last_err = e
            if attempt < RETRIES - 1:
                time.sleep(2 ** attempt)
    raise RuntimeError("download failed after %d retries: %s (%s)" % (RETRIES, url, last_err))


def extract_leftnav(html):
    """从入口页左栏提取 (title, href) 列表，DOM 顺序即章节顺序。"""
    m = re.search(r'<div class="design" id="leftcolumn">(.*?)</div>', html, re.S)
    if not m:
        raise RuntimeError("入口页未找到 leftcolumn 导航")
    links = []
    for attrs in re.findall(r'<a\b[^>]*target="_top"[^>]*>', m.group(1)):
        t = re.search(r'title="([^"]*)"', attrs)
        h = re.search(r'href="([^"]*)"', attrs)
        if t and h:
            links.append((html_mod.unescape(t.group(1)).strip(), h.group(1).strip()))
    return links


def extract_intro(html):
    """按 div 平衡截取 <div class="article-intro" id="content"> 完整片段。"""
    i = html.find('<div class="article-intro"')
    if i < 0:
        raise RuntimeError("未找到 article-intro 容器")
    depth = 0
    for m in re.finditer(r"<div\b|</div>", html[i:]):
        if m.group(0) == "</div>":
            depth -= 1
            if depth == 0:
                return html[i: i + m.end()]
        else:
            depth += 1
    raise RuntimeError("article-intro div 未闭合")


# ---------------------------------------------------------------- 转换

def normalize_inline(text):
    """行内文本清洗：\xa0 -> 空格，连续空白折叠为单空格。"""
    return re.sub(r"[ \t\r\n\xa0]+", " ", text)


def detect_code_lang(code):
    """代码围栏语言判定。

    契约：example_code 默认 kotlin；含 gradle 特征（implementation 、
    dependencies、android {、plugins { 等）-> groovy；裸 pre -> text。
    细化（交付报告注明）：首部注释路径 *.gradle.kts 本就是 Kotlin DSL ->
    kotlin；*.toml -> toml；<?xml 声明 -> xml。
    """
    head = "\n".join(code.splitlines()[:3])
    if ".gradle.kts" in head:
        return "kotlin"
    if ".toml" in head:
        return "toml"
    if code.lstrip()[:200].startswith("<?xml") or ".xml" in head:
        return "xml"
    low = code.lower()
    if any(k in low for k in GRADLE_MARKERS):
        return "groovy"
    return "kotlin"


INLINE_MARKS = {"b": "**", "strong": "**", "em": "*", "i": "*", "code": "`"}


class ChapterConverter(HTMLParser):
    """article-intro HTML -> markdown 块列表。

    代码块（example_code / 裸 pre）内：只收集纯文本（标签剥离、实体由
    convert_charrefs 自动反转义、<br> -> 换行），内容其余一字不改；
    标签清理只作用于代码块之外。
    """

    def __init__(self, chapter_slug):
        super().__init__(convert_charrefs=True)
        self.slug = chapter_slug
        self.blocks = []          # 完成的 markdown 块
        self.para = []            # 当前行内片段
        self.para_lines = []      # 段落内 <br> 断出的行
        self.skip_stack = []      # script/style/ins/iframe/form/nav
        self.code_buf = None      # 非 None = 代码块内
        self.code_kind = None     # "example" | "pre"
        self.code_div_depth = 0
        self.code_hlmain = False  # 旧版高亮：hl-code 内字面 \n 即换行，空白全保留
        self.marked_depth = 0     # <span class="marked"> 反引号包裹
        self.example_title = None
        self.capt_example_h = False
        self.imgs = []            # [(abs_url, filename)]
        self.list_depth = 0
        self.quote_depth = 0
        self.table_rows = None
        self.table_row = None
        self.table_cell = None
        self.in_cell = 0
        self.link_buf = None
        self.link_href = None

    # ---------- 段落工具 ----------
    def flush_line(self):
        line = "".join(self.para)
        # HTML 渲染语义：普通空白（含源码换行/\xa0）折叠为单空格
        line = re.sub(r"[ \t\r\n\xa0]+", " ", line).strip()
        self.para = []
        if line:
            self.para_lines.append(line)

    def flush_para(self):
        self.flush_line()
        indent = "    " * (self.list_depth - 1) if self.list_depth > 0 else ""
        for ln in self.para_lines:
            self.blocks.append(("> " + ln) if self.quote_depth else indent + ln)
        self.para_lines = []

    def emit_code(self):
        code = self.code_buf
        kind = self.code_kind
        hlmain = self.code_hlmain
        self.code_buf = None
        self.code_kind = None
        self.code_hlmain = False
        lang = detect_code_lang(code) if kind == "example" else "text"
        lines = code.split("\n")
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        if kind == "example" and not hlmain:
            # 新版高亮：<br> 产生换行后，HTML 源码换行被折叠成的行首
            # 普通空格是噪声（真正缩进来自 \xa0），剥掉行首普通空白。
            lines = [ln if ln.startswith("\xa0") else ln.lstrip(" \t")
                     for ln in lines]
        lines = [ln.rstrip() for ln in lines]
        code = "\n".join(lines)
        if self.example_title is not None:
            title = normalize_inline(self.example_title).strip()
            if title:
                self.blocks.append("**%s**" % title)
            self.example_title = None
        self.blocks.append("```%s\n%s\n```" % (lang, code))

    # ---------- 文本 ----------
    def handle_data(self, data):
        if self.skip_stack:
            return
        if self.code_buf is not None:
            if self.code_kind == "example" and not self.code_hlmain:
                # 新版高亮：HTML 源码中的换行/缩进是排版噪声（换行由 <br>、
                # 缩进由 \xa0 表达）。行首的纯排版空白直接丢弃，
                # 其余按 HTML 渲染语义折叠为单空格。
                if re.fullmatch(r"[ \t\r\n]*", data) and (
                        self.code_buf == "" or self.code_buf.endswith("\n")):
                    return
                data = re.sub(r"[ \t\r\n]+", " ", data)
            self.code_buf += data
        elif self.capt_example_h:
            self.example_title = (self.example_title or "") + data
        elif self.table_cell is not None:
            self.table_cell.append(data)
        elif self.link_buf is not None:
            self.link_buf.append(data)
        else:
            self.para.append(data)

    def handle_entityref(self, name):
        self.handle_data(html_mod.unescape("&%s;" % name))

    def handle_charref(self, name):
        self.handle_data(html_mod.unescape("&#%s;" % name))

    def _inline(self, mark):
        """行内标记（b/em/code...）写入当前活动缓冲。"""
        if self.link_buf is not None:
            self.link_buf.append(mark)
        elif self.table_cell is not None:
            self.table_cell.append(mark)
        else:
            self.para.append(mark)

    # ---------- 开始标签 ----------
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = a.get("class", "") or ""
        if self.skip_stack:
            if tag in DROP_TAGS:
                self.skip_stack.append(tag)
            return
        if self.code_buf is not None:
            if tag == "div":
                self.code_div_depth += 1
                if "hl-main" in cls.split():
                    self.code_hlmain = True
            elif tag == "br":
                self.code_buf += "\n"
            return

        if tag in DROP_TAGS:
            self.skip_stack.append(tag)
        elif tag == "div":
            if "example_code" in cls.split():
                self.code_buf = ""
                self.code_kind = "example"
                self.code_div_depth = 1
        elif tag in ("h2", "h3", "h4", "h5"):
            if "example" in cls.split():
                self.example_title = ""
                self.capt_example_h = True
        elif tag == "br":
            self.flush_line()
        elif tag == "hr":
            self.flush_para()
            self.blocks.append("---")
        elif tag == "pre":
            self.code_buf = ""
            self.code_kind = "pre"
            self.code_div_depth = 0
        elif tag in INLINE_MARKS:
            self._inline(INLINE_MARKS[tag])
        elif tag == "span":
            if "marked" in cls.split():
                self.marked_depth += 1
                self._inline("`")
        elif tag == "sup":
            self._inline("^")
        elif tag == "blockquote":
            self.flush_para()
            self.quote_depth += 1
        elif tag in ("ul", "ol"):
            self.flush_para()
            self.list_depth += 1
        elif tag == "li":
            self.flush_para()
            self.para.append("- ")
        elif tag == "a":
            self.link_href = a.get("href", "") or ""
            self.link_buf = []
        elif tag == "img":
            self.flush_line()
            src = a.get("src", "") or ""
            if src.startswith("//"):
                absurl = "https:" + src
            elif src.startswith("/"):
                absurl = BASE + src
            else:
                absurl = src
            if "wp-content/uploads" in src:
                fname = re.sub(r"[^A-Za-z0-9._-]", "_", absurl.rsplit("/", 1)[-1])
                self.imgs.append((absurl, fname))
                alt = normalize_inline(a.get("alt", "") or "").strip()
                self.blocks.append("![%s](images/%s/%s/%s)"
                                   % (alt, COURSE_SLUG, self.slug, fname))
            # 其余 img（广告/二维码/主题资源/外站 logo）整体删除
        elif tag == "table":
            self.flush_para()
            self.table_rows = []
        elif tag == "tr":
            self.table_row = []
        elif tag in ("td", "th"):
            self.table_cell = []
            self.in_cell += 1
        # h1 / p / example 容器 div：无需开始动作

    # ---------- 结束标签 ----------
    def handle_endtag(self, tag):
        if self.skip_stack:
            if tag == self.skip_stack[-1]:
                self.skip_stack.pop()
            return
        if self.code_buf is not None:
            if tag == "div":
                self.code_div_depth -= 1
                if self.code_div_depth <= 0 and self.code_kind == "example":
                    self.emit_code()
            elif tag == "pre" and self.code_kind == "pre":
                self.emit_code()
            return

        if tag in INLINE_MARKS:
            self._inline(INLINE_MARKS[tag])
        elif tag == "span":
            if self.marked_depth:
                self.marked_depth -= 1
                self._inline("`")
        elif tag == "sup":
            pass
        elif tag in ("h2", "h3", "h4", "h5"):
            if self.capt_example_h:
                self.capt_example_h = False
                return
            level = {"h2": "##", "h3": "###", "h4": "####", "h5": "#####"}[tag]
            self.flush_line()
            line = normalize_inline(" ".join(self.para_lines + ["".join(self.para)])).strip()
            self.para, self.para_lines = [], []
            if line:
                self.blocks.append(("> " if self.quote_depth else "") + level + " " + line)
        elif tag == "h1":
            # 删正文第一个 H1（标题进 courses.json；每章恰好 1 个）
            self.para, self.para_lines = [], []
        elif tag == "p":
            self.flush_para()
        elif tag == "blockquote":
            self.flush_para()
            self.quote_depth = max(0, self.quote_depth - 1)
        elif tag in ("ul", "ol"):
            self.flush_para()
            self.list_depth = max(0, self.list_depth - 1)
        elif tag == "li":
            self.flush_para()
        elif tag == "a":
            if self.link_buf is None:
                return
            text = normalize_inline("".join(self.link_buf)).strip()
            href = self.link_href or ""
            self.link_buf = self.link_href = None
            if any(w in text for w in RUN_WORDS):
                return  # 「点击运行/运行实例/在线实例/尝试一下」按钮删除
            if not text:
                return
            if href.startswith("//"):
                href = "https:" + href
            elif href.startswith("/"):
                href = BASE + href  # 站内 /kotlin/xx.html -> 绝对 URL
            if href.startswith(("http://", "https://", "mailto:")):
                self.para.append("[%s](%s)" % (text, href))
            else:
                self.para.append(text)
        elif tag == "table":
            rows = self.table_rows or []
            self.table_rows = None
            if rows:
                width = max(len(r) for r in rows)
                rows = [r + [""] * (width - len(r)) for r in rows]
                out = ["| " + " | ".join(rows[0]) + " |",
                       "| " + " | ".join(["---"] * width) + " |"]
                out += ["| " + " | ".join(r) + " |" for r in rows[1:]]
                self.blocks.append("\n".join(out))  # 单块，行间不留空行
        elif tag == "tr":
            if self.table_row is not None:
                self.table_rows.append(self.table_row)
                self.table_row = None
        elif tag in ("td", "th"):
            if self.in_cell:
                cell = normalize_inline("".join(self.table_cell)).strip()
                self.table_row.append(cell.replace("|", "\\|"))
                self.table_cell = None
                self.in_cell -= 1

    def handle_startendtag(self, tag, attrs):
        # <br /> / <img ... /> / <hr />
        self.handle_starttag(tag, attrs)
        if tag in ("br", "img", "hr"):
            if tag == "br" and self.code_buf is None:
                self.flush_line()

    def close(self):
        super().close()
        if self.code_buf is not None:
            self.emit_code()
        self.flush_para()


def convert_chapter(html, slug):
    intro = extract_intro(html)
    parser = ChapterConverter(slug)
    parser.feed(intro)
    parser.close()
    blocks = [b.rstrip() for b in parser.blocks if b.strip()]
    return blocks, parser.imgs


def assemble_markdown(blocks, chapter_url):
    text = "\n\n".join(blocks)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.rstrip("\n") + "\n"
    sig = ("> 本文转载自 [菜鸟教程 runoob.com](%s)，版权归原作者所有，"
           "仅供非商业学习使用。\n") % chapter_url
    return text + "\n" + sig


# ---------------------------------------------------------------- 图片 / courses.json

def download_images(imgs, slug, report):
    for absurl, fname in imgs:
        dest_dir = os.path.join(IMG_ROOT, slug)
        os.makedirs(dest_dir, exist_ok=True)
        dest = os.path.join(dest_dir, fname)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            continue  # 幂等：已有非空文件跳过
        try:
            with open(dest, "wb") as f:
                f.write(fetch_bytes(absurl))
        except Exception as e:  # noqa: BLE001
            report["failed_images"].append((absurl, str(e)))


def build_course_entry():
    course = dict(COURSE_ENTRY)
    course["chapters"] = [
        {"slug": slug, "title": title, "sort_order": i + 1, "file": slug + ".md"}
        for i, (title, _url, slug) in enumerate(EXPECTED_CHAPTERS)
    ]
    return course


def update_courses_json(course):
    """把 kotlin 课程条目追加到 courses 数组末尾（幂等：按 slug 原位替换）。

    文本级手术插入而非整体 json.dump 重写，
    以保持既有内容与格式（含原文件 \u003c 风格转义）逐字节不动。
    """
    text = open(COURSES_JSON, encoding="utf-8", newline="").read()
    json.loads(text)  # 现文件必须合法

    # 幂等：移除已存在的 kotlin 课程对象（大括号配对定位范围）
    m = re.search(r'\{\s*"slug": "kotlin",', text)
    if m:
        start = text.rfind("{", 0, m.start() + 1)
        depth, end = 0, None
        for idx in range(start, len(text)):
            if text[idx] == "{":
                depth += 1
            elif text[idx] == "}":
                depth -= 1
                if depth == 0:
                    end = idx + 1
                    break
        if end is None:
            raise RuntimeError("courses.json 中已有 kotlin 条目但无法定位其范围")
        if text[end: end + 2] == ",":
            text = text[:end] + text[end + 2:]
        else:
            pre = text[:start].rstrip()
            if pre.endswith(","):
                text = pre[:-1] + text[end:]
            else:
                text = text[:start] + text[end:]
        text = re.sub(r"\n{3,}", "\n\n", text)
        if '"slug": "kotlin"' in text:
            raise RuntimeError("移除旧 kotlin 条目失败")

    stripped = text.rstrip("\n")
    if not re.search(r"\n  \]\n}\s*$", stripped):
        raise RuntimeError("courses.json 结构异常：结尾不是 ]\\n} 结构")

    block = json.dumps(course, ensure_ascii=False, indent=2)
    indented = "\n".join(("    " + ln if ln else ln) for ln in block.split("\n"))
    last_obj_close = stripped.rfind("\n    }")
    if last_obj_close < 0:
        raise RuntimeError("未找到最后一个课程对象的结束位置")
    insert_at = last_obj_close + len("\n    }")
    new_text = stripped[:insert_at] + ",\n" + indented + stripped[insert_at:]
    json.loads(new_text)  # 写前校验合法
    with open(COURSES_JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_text + "\n")


# ---------------------------------------------------------------- 主流程

def main():
    entry = fetch(ENTRY_URL)
    nav = extract_leftnav(entry)
    expected = [(t, u) for t, u, _s in EXPECTED_CHAPTERS]
    if [(t, u) for t, u in nav] != expected:
        print("左栏导航与冻结清单不一致，中止。逐章差异：", file=sys.stderr)
        for i in range(max(len(nav), len(expected))):
            got = nav[i] if i < len(nav) else None
            want = expected[i] if i < len(expected) else None
            if got != want:
                print("  第%s章：导航=%s 期望=%s" % (i + 1, got, want), file=sys.stderr)
        sys.exit(2)

    report = {"chapters": [], "failed_images": []}
    for i, (title, href, slug) in enumerate(EXPECTED_CHAPTERS):
        url = BASE + href
        html = fetch(url)
        blocks, imgs = convert_chapter(html, slug)
        md = assemble_markdown(blocks, url)
        md_path = os.path.join(SEED_DIR, slug + ".md")
        with open(md_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(md)
        download_images(imgs, slug, report)
        # 图片下载失败 -> md 中该图改为占位引用块
        for absurl, _err in report["failed_images"]:
            fname = re.sub(r"[^A-Za-z0-9._-]", "_", absurl.rsplit("/", 1)[-1])
            needle = "](images/%s/%s/%s)" % (COURSE_SLUG, slug, fname)
            if needle in md:
                md = re.sub(r"!\[[^\]]*\]" + re.escape(needle),
                            "> [图片下载失败：%s]" % absurl, md)
                with open(md_path, "w", encoding="utf-8", newline="\n") as f:
                    f.write(md)
        report["chapters"].append(
            {"slug": slug, "bytes": os.path.getsize(md_path), "imgs": len(imgs)})
        print("[%2d/43] %-28s %7d bytes  imgs:%d" % (i + 1, slug, report["chapters"][-1]["bytes"], len(imgs)))
        time.sleep(SLEEP)

    update_courses_json(build_course_entry())
    print("courses.json 已更新：kotlin 课程 %d 章追加完成" % len(EXPECTED_CHAPTERS))
    if report["failed_images"]:
        print("图片下载失败 %d 张：" % len(report["failed_images"]))
        for u, e in report["failed_images"]:
            print("  %s  (%s)" % (u, e))


if __name__ == "__main__":
    main()
