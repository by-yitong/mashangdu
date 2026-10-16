#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""抓取《Rust 程序设计语言》中文版整本书,转换为 code-tutorials 后端 seed 数据。

用法:
    python tools/mdbook_trpl_to_seed.py
    python tools/mdbook_trpl_to_seed.py --root D:/path/to/code-tutorials

来源仓库: https://github.com/KaiserY/trpl-zh-cn (master 分支, MIT LICENSE,
          Copyright 2017-2018 Rust 中文社区)
    - 导航: src/SUMMARY.md (mdBook 目录, 104 个条目, 以它为准)
    - 正文: src/<slug>.md
    - 图片: src/img/** (26 个文件: SVG 图解 / PNG / ferris 螃蟹图标; 原格式下载, 不做转换)

输出:
    1. backend/internal/store/seeddata/{slug}.md     104 个章节文件(UTF-8 无 BOM, LF)
    2. backend/static/images/trpl-zh-cn/**           被引用图片(含 ferris/ 子目录)
    3. backend/internal/store/seeddata/courses.json  追加第 6 门课 trpl-zh-cn(既有 5 门不动)

转换契约(详见任务卡):
    1) 删开头翻译记账块(含 commit 行的连续 > 引用行, 最多 5 行)
    2) 删正文第一个 #/## 标题(标题进 courses.json)
    3) <img> 转 markdown 图片, src 重写为 images/trpl-zh-cn/...
    4) 章内互链(相对路径 .html)脱链为纯文本; 外链 http(s) 保留
    5) <br> 转换行; 其余白名单 HTML 标签删除并计数
    6) 安全断言: {{# / 首行--- / === \" / --8<-- / !!! / ??? 应命中 0
    7) 末尾追加统一署名块

特性: 仅标准库; 请求带 User-Agent, 失败重试 2 次; 幂等(重跑输出 byte 级一致);
      防覆盖护栏: 目标 md 已存在但缺少本脚本署名 -> 报错停止。
"""

import argparse
import json
import posixpath
import re
import sys
import time
import urllib.request
from pathlib import Path

RAW_BASE = "https://raw.githubusercontent.com/KaiserY/trpl-zh-cn/master/src/"
REPO_RAW_BASE = "https://raw.githubusercontent.com/KaiserY/trpl-zh-cn/master/"
COURSE_SLUG = "trpl-zh-cn"
COURSE_TITLE = "Rust 程序设计语言（中文版）"
COURSE_SUMMARY = (
    "Rust 官方教程《The Rust Programming Language》中文译本：从安装与猜数游戏，"
    "到所有权、结构体、枚举、模块、集合、错误处理、泛型与生命周期、测试、智能指针、"
    "无畏并发、模式匹配、宏，最终完成多线程 web server 项目，含附录。"
    "Steve Klabnik、Carol Nichols 著，Rust 中文社区翻译，MIT 授权转载。"
)
COURSE_LANGUAGE = "Rust"
COURSE_COLOR = "#CE422B"
COURSE_SORT = 6
EXPECTED_ENTRIES = 104
UA = ("Mozilla/5.0 (code-tutorials seed crawler; source=kaiserY/trpl-zh-cn; "
      "+https://github.com/KaiserY/trpl-zh-cn)")

SIGNATURE = (
    "> 本文来自 [《Rust 程序设计语言》中文版](https://github.com/KaiserY/trpl-zh-cn)"
    "（Steve Klabnik、Carol Nichols 著，Rust 中文社区翻译），依据 MIT 许可转载；"
    "英文原版：[The Rust Programming Language](https://doc.rust-lang.org/stable/book/)。"
)

# ---------------------------------------------------------------- 正则

SUMMARY_ENTRY_RE = re.compile(r"^\s*(?:-\s*)?\[([^\]]+)\]\(([^)\s]+\.md)\)\s*$")
COMMIT_LINE_RE = re.compile(r"^>\s*commit\s+[0-9a-f]{40}\s*$", re.IGNORECASE)
HEADING_RE = re.compile(r"^#{1,2}\s")
IMG_TAG_RE = re.compile(r"<img\b[^>]*>", re.IGNORECASE)
ATTR_RE = re.compile(r"([a-zA-Z_][\w-]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)')")
BR_TAG_RE = re.compile(r"<br\s*/?>", re.IGNORECASE)
# 白名单 HTML 标签(避免误伤正文里裸写的 Rust 泛型如 <T> / <Box<T>>)
HTML_TAG_RE = re.compile(
    r"</?(?:span|div|table|thead|tbody|tfoot|tr|td|th|code|pre|em|strong|b|i|u|"
    r"sup|sub|kbd|center|small|font|a|p|ul|ol|li|h[1-6]|details|summary|figure|"
    r"figcaption|blockquote|hr)\b[^<>]*>", re.IGNORECASE)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
INLINE_LINK_RE = re.compile(r"(?<!!)\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
REF_USE_RE = re.compile(r"(?<!!)\[([^\]]+)\]\[([^\]]*)\]")
REF_DEF_RE = re.compile(r"^\s{0,3}\[([^\]]+)\]:\s*(\S+)(?:\s+\"[^\"]*\")?\s*$")
# 定义拆成两行: "[id]:" 换行后跟 URL (CommonMark 允许)
REF_DEF_SPLIT_RE = re.compile(r"^\s{0,3}\[([^\]]+)\]:\s*$")
# mdBook include 指令(任务卡侦察遗漏: ch02-00 实际存在, 需抓取 listings 内联)
INCLUDE_RE = re.compile(r"^\s*\{\{#(rustdoc_include|include)\s+([^}\s]+)\}\}\s*$")
ANCHOR_RE = re.compile(r"//\s*ANCHOR:\s*(\S+)")
ANCHOR_END_RE = re.compile(r"//\s*ANCHOR_END:\s*(\S+)")

EXTERNAL_PREFIXES = ("http://", "https://", "mailto:", "//")


def is_external(url: str) -> bool:
    return url.startswith(EXTERNAL_PREFIXES)


def fence_toggle(line: str) -> bool:
    s = line.lstrip()
    return s.startswith("```") or s.startswith("~~~")


# ---------------------------------------------------------------- 网络

def fetch(url: str, binary: bool = False, retries: int = 2):
    last_err = None
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = resp.read()
            return data if binary else data.decode("utf-8")
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            if attempt < retries:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("fetch 失败(%d 次尝试): %s: %s" % (retries + 1, url, last_err))


# ---------------------------------------------------------------- 统计

class Stats:
    def __init__(self):
        self.chapters = 0
        self.inline_links_removed = 0
        self.reflinks_removed = 0
        self.refdefs_removed = 0
        self.html_tags_removed = 0
        self.html_comments_removed = 0
        self.img_converted = 0
        self.includes_resolved = 0
        self.refdefs_merged = 0
        self.images: list = []
        self.images_downloaded = 0
        self.images_unchanged = 0
        self.warnings: list = []

    def warn(self, slug: str, msg: str):
        self.warnings.append("[%s] %s" % (slug, msg))

    def add_image(self, src: str):
        if src not in self.images:
            self.images.append(src)
        self.img_converted += 1

    def report(self):
        lines = [
            "==== 转换统计 ====",
            "章节文件       : %d (期望 %d)" % (self.chapters, EXPECTED_ENTRIES),
            "图片引用转换   : %d 处, 去重后 %d 个文件 (下载 %d, 已一致跳过 %d)" % (
                self.img_converted, len(self.images),
                self.images_downloaded, self.images_unchanged),
            "互链替换       : 行内 %d 处, 引用式 %d 处, 删除定义行 %d 行(含合并拆行定义 %d 处)" % (
                self.inline_links_removed, self.reflinks_removed,
                self.refdefs_removed, self.refdefs_merged),
            "include 内联   : %d 处 {{#include}}/{{#rustdoc_include}}" % self.includes_resolved,
            "HTML 标签删除  : %d 个标签, %d 个注释" % (
                self.html_tags_removed, self.html_comments_removed),
            "告警           : %d 条" % len(self.warnings),
        ]
        for w in self.warnings:
            lines.append("  WARN " + w)
        return "\n".join(lines)


# ---------------------------------------------------------------- 转换

def strip_tracking_block(lines, slug, stats):
    """规则1: 删开头翻译记账块。

    从文件第一行起(允许前面有标题/空行, 在前 10 行内定位), 找到连续 > 引用行
    (最多 5 行), 必须包含 commit <40hex> 行且含 github.com/rust-lang/book 链接
    才删除, 删完停止。
    """
    start = None
    for i, ln in enumerate(lines[:10]):
        if ln.startswith(">"):
            start = i
            break
        if ln.strip():
            continue  # 标题等正文行, 继续往后找
    if start is None:
        stats.warn(slug, "开头未找到翻译记账块(前 10 行内无 > 引用行)")
        return lines
    end = start
    while end < len(lines) and lines[end].startswith(">") and end - start < 5:
        end += 1
    block = lines[start:end]
    has_commit = any(COMMIT_LINE_RE.match(b) for b in block)
    # 源链接行: github.com/rust-lang/book 或 raw.githubusercontent.com 变体
    has_link = any(("github.com/rust-lang/book" in b)
                   or ("raw.githubusercontent.com/rust-lang/book" in b) for b in block)
    if not (has_commit and has_link):
        stats.warn(slug, "开头引用块不含记账特征(commit/源链接), 未删除: %r"
                   % ("\\n".join(block)[:100]))
        return lines
    new = lines[:start] + lines[end:]
    # 折叠删除造成的连续空行
    if 0 < start < len(new) and not new[start - 1].strip() and not new[start].strip():
        del new[start]
    return new


def drop_first_heading(lines, slug, stats):
    """规则2: 删正文第一个 #/## 标题行; 报告不在前 10 个非空行内的情况。"""
    in_fence = False
    nonempty_seen = 0
    for i, ln in enumerate(lines):
        if fence_toggle(ln):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if ln.strip():
            nonempty_seen += 1
        if HEADING_RE.match(ln):
            if nonempty_seen > 10:
                stats.warn(slug, "首个标题不在文件前 10 个非空行内(第 %d 个非空行): %r"
                           % (nonempty_seen, ln[:50]))
            new = lines[:i] + lines[i + 1:]
            if 0 < i < len(new) and not new[i - 1].strip() and not new[i].strip():
                del new[i]
            return new
    # 回退: 全文无 #/## (如 ch12-01/02 译作用 ### 起头) 时, 删第一个非空行且为标题的行
    for i, ln in enumerate(lines):
        if not ln.strip():
            continue
        if re.match(r"^#{1,6}\s", ln):
            stats.warn(slug, "全文无 #/## 标题, 回退删除首个标题行(%r)" % ln[:40])
            new = lines[:i] + lines[i + 1:]
            if 0 < i < len(new) and not new[i - 1].strip() and not new[i].strip():
                del new[i]
            return new
        break  # 第一个非空行不是标题就不再找
    stats.warn(slug, "未找到任何级别的首标题")
    return lines


def parse_attrs(tag: str) -> dict:
    attrs = {}
    for m in ATTR_RE.finditer(tag):
        attrs[m.group(1).lower()] = m.group(2) if m.group(2) is not None else m.group(3)
    return attrs


def convert_img_tags(line: str, slug: str, stats) -> str:
    """规则3: <img alt="A" src="img/x.svg" class=... /> -> ![A](images/trpl-zh-cn/x.svg)"""
    def repl(m):
        tag = m.group(0)
        attrs = parse_attrs(tag)
        src = (attrs.get("src") or "").strip()
        if not src.startswith("img/"):
            stats.warn(slug, "img src 非 img/ 前缀: %r" % src)
        name = src[len("img/"):] if src.startswith("img/") else src
        alt = (attrs.get("alt") or "").strip()
        if not alt:
            alt = posixpath.splitext(posixpath.basename(name))[0]
        stats.add_image(src)
        return "![%s](images/%s/%s)" % (alt, COURSE_SLUG, name)
    return IMG_TAG_RE.sub(repl, line)


MD_IMG_RE = re.compile(r"!\[([^\]]*)\]\(\s*(img/[^\s)]+)\s*\)")


def convert_md_images(line: str, slug: str, stats) -> str:
    """规则3b: md 原生相对图片 ![alt](img/x.png) -> ![alt](images/trpl-zh-cn/x.png)。"""
    def repl(m):
        alt, src = m.group(1).strip(), m.group(2).strip()
        name = src[len("img/"):]
        if not alt:
            alt = posixpath.splitext(posixpath.basename(name))[0]
        stats.add_image(src)
        return "![%s](images/%s/%s)" % (alt, COURSE_SLUG, name)
    return MD_IMG_RE.sub(repl, line)


def strip_links_and_html(line: str, refdefs: dict, slug: str, stats) -> str:
    """规则4+5: 互链脱链 + 其余 HTML 标签清理(单行, 不在代码围栏内)。"""
    def ref_repl(m):
        text, rid = m.group(1), (m.group(2) or m.group(1)).lower()
        url = refdefs.get(rid)
        if url is None:
            stats.warn(slug, "引用式链接未找到定义 [%s], 保留原样" % rid)
            return m.group(0)
        if is_external(url):
            return m.group(0)  # 外链保留
        stats.reflinks_removed += 1
        return text
    line = REF_USE_RE.sub(ref_repl, line)

    def link_repl(m):
        text, url = m.group(1), m.group(2)
        if is_external(url) or url.startswith("#"):
            return m.group(0)
        stats.inline_links_removed += 1
        return text
    line = INLINE_LINK_RE.sub(link_repl, line)

    n = len(HTML_TAG_RE.findall(line))
    if n:
        stats.html_tags_removed += n
        line = HTML_TAG_RE.sub("", line)
    nc = len(HTML_COMMENT_RE.findall(line))
    if nc:
        stats.html_comments_removed += nc
        line = HTML_COMMENT_RE.sub("", line)
    return line


def merge_split_refdefs(lines, slug, stats):
    """合并拆成两行的引用式链接定义: "[id]:" + 下一行 URL。"""
    merged = []
    i = 0
    while i < len(lines):
        ln = lines[i]
        m = REF_DEF_SPLIT_RE.match(ln)
        if m and i + 1 < len(lines):
            nxt = lines[i + 1]
            if nxt.strip() and not nxt[:1].isspace() and not fence_toggle(nxt) \
                    and not REF_DEF_SPLIT_RE.match(nxt) and not REF_DEF_RE.match(nxt):
                merged.append("[%s]: %s" % (m.group(1), nxt.strip()))
                stats.refdefs_merged += 1
                i += 2
                continue
        merged.append(ln)
        i += 1
    return merged


def resolve_include(spec, slug, stats, listing_cache):
    """把 {{#include}}/{{#rustdoc_include}} 指令解析为 listings 源码内容。

    spec 形如 "../listings/<path>[:all|:anchor|:N[:M]]", 路径相对 src/。
    anchor 取 "// ANCHOR: name" 与 "// ANCHOR_END: name" 之间(不含标记行)。
    """
    path, _, modifier = spec.partition(":")
    rel = posixpath.normpath(posixpath.join("src", path))
    if rel.startswith("../") or rel.startswith("/"):
        stats.warn(slug, "include 路径越界, 未解析: %r" % spec)
        return None
    if rel not in listing_cache:
        listing_cache[rel] = fetch(REPO_RAW_BASE + rel).replace("\r\n", "\n").split("\n")
    content = listing_cache[rel]
    stats.includes_resolved += 1
    if not modifier or modifier == "all":
        return content
    m = re.match(r"^(\d+)(?::(\d*))?$", modifier)
    if m:  # 行号范围, 1 基闭区间, 空 end 表示到文件尾
        start = int(m.group(1))
        end = int(m.group(2)) if m.group(2) else len(content)
        return content[start - 1:end]
    # 命名 anchor
    out, capturing = [], False
    for ln in content:
        am = ANCHOR_RE.search(ln)
        if am and am.group(1) == modifier:
            capturing = True
            continue
        em = ANCHOR_END_RE.search(ln)
        if em and em.group(1) == modifier:
            capturing = False
            continue
        if capturing:
            out.append(ln)
    if not capturing and not out:
        stats.warn(slug, "include anchor %r 未命中, 未解析: %r" % (modifier, spec))
        return None
    return out


def transform_lines(lines, slug, stats, listing_cache):
    lines = merge_split_refdefs(lines, slug, stats)

    # 第一遍: 收集引用式链接定义(id -> url), 供判断外链/内链
    refdefs = {}
    in_fence = False
    for ln in lines:
        if fence_toggle(ln):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = REF_DEF_RE.match(ln)
        if m:
            refdefs.setdefault(m.group(1).lower(), m.group(2))

    out = []
    in_fence = False
    for ln in lines:
        if fence_toggle(ln):
            in_fence = not in_fence
            out.append(ln)
            continue
        if in_fence:
            m = INCLUDE_RE.match(ln)
            if m:  # mdBook include 指令 -> 内联 listings 源码
                content = resolve_include(m.group(2), slug, stats, listing_cache)
                if content is not None:
                    while content and content[-1].strip() == "":
                        content.pop()
                    out.extend(content)
                    continue
            out.append(ln)
            continue
        m = REF_DEF_RE.match(ln)
        if m:
            if is_external(m.group(2)):
                out.append(ln)  # 外链定义保留
            else:
                stats.refdefs_removed += 1  # 相对路径定义行删除
            continue
        ln = convert_img_tags(ln, slug, stats)
        ln = convert_md_images(ln, slug, stats)
        # 规则5: <br> -> 换行(拆行后逐段继续处理)
        parts = BR_TAG_RE.sub("\n", ln).split("\n")
        for part in parts:
            out.append(strip_links_and_html(part, refdefs, slug, stats))
    return out


def safety_check(lines, slug, stats):
    """规则6: 安全断言, 每项应命中 0; 命中则告警并删除该行(围栏内仅告警不删)。"""
    out = []
    in_fence = False
    for i, ln in enumerate(lines):
        if fence_toggle(ln):
            in_fence = not in_fence
            out.append(ln)
            continue
        if in_fence:
            if "{{#" in ln:
                stats.warn(slug, "代码围栏内出现 {{# (仅告警, 保留该行): %r" % ln[:60])
            out.append(ln)
            continue
        bad = None
        if "{{#" in ln:
            bad = "{{#"
        elif i == 0 and ln.strip() == "---":
            bad = "首行---"
        elif '=== "' in ln:
            bad = '=== "'
        elif "--8<--" in ln:
            bad = "--8<--"
        elif ln.startswith("!!! "):
            bad = "!!! "
        elif ln.startswith("??? "):
            bad = "??? "
        if bad:
            stats.warn(slug, "安全断言命中[%s], 已删除该行: %r" % (bad, ln[:60]))
            continue
        out.append(ln)
    return out


def convert_chapter(slug: str, raw: str, stats, listing_cache) -> str:
    text = raw.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    lines = strip_tracking_block(lines, slug, stats)
    lines = drop_first_heading(lines, slug, stats)
    lines = transform_lines(lines, slug, stats, listing_cache)
    lines = safety_check(lines, slug, stats)
    body = "\n".join(lines).strip("\n")
    # 规则7: 末尾署名(精确字符串)
    return body + "\n\n---\n\n" + SIGNATURE + "\n"


# ---------------------------------------------------------------- SUMMARY / courses.json

def parse_summary(text: str):
    entries = []
    for line in text.split("\n"):
        m = SUMMARY_ENTRY_RE.match(line)
        if m:
            entries.append((m.group(1), m.group(2)))
    return entries


def clean_title(raw: str) -> str:
    t = raw.replace("&nbsp;", " ").replace("`", "")
    t = re.sub(r"\s+", " ", t).strip()
    return t


def build_course_block(chapters):
    """按既有 courses.json 风格生成第 6 门课的文本块(4 空格缩进)。"""
    field_tpl = '      "%s": %s,'
    lines = [
        "    {",
        field_tpl % ("slug", json.dumps(COURSE_SLUG, ensure_ascii=False)),
        field_tpl % ("title", json.dumps(COURSE_TITLE, ensure_ascii=False)),
        field_tpl % ("summary", json.dumps(COURSE_SUMMARY, ensure_ascii=False)),
        field_tpl % ("language", json.dumps(COURSE_LANGUAGE, ensure_ascii=False)),
        field_tpl % ("color", json.dumps(COURSE_COLOR, ensure_ascii=False)),
        field_tpl % ("sort_order", str(COURSE_SORT)),
        '      "chapters": [',
    ]
    for i, (slug, title) in enumerate(chapters, start=1):
        obj = {"slug": slug, "title": title, "sort_order": i, "file": slug + ".md"}
        lines.append("        " + json.dumps(obj, ensure_ascii=False) + ",")
    # 最后一个章节行不带逗号
    lines[-1] = lines[-1].rstrip(",")
    lines.append("      ]")
    lines.append("    }")
    return "\n".join(lines)


def update_courses_json(json_path: Path, chapters):
    original = json_path.read_text(encoding="utf-8")
    data = json.loads(original)
    if len(data.get("courses", [])) not in (5, 6):
        raise SystemExit("courses.json 课程数异常: %d" % len(data["courses"]))

    suffix = "  ]\n}\n"
    block = build_course_block(chapters)
    clean = original
    if any(c["slug"] == COURSE_SLUG for c in data["courses"]):
        # 幂等: 先精确移除上次插入的块(重跑生成内容一致)
        old_segment = ",\n" + block + "\n" + suffix
        if old_segment not in clean:
            raise SystemExit("courses.json 已含 %s 但无法识别旧插入块, 请人工检查"
                             % COURSE_SLUG)
        clean = clean.replace(old_segment, suffix)
    if not clean.endswith(suffix):
        raise SystemExit("courses.json 结尾格式异常(应以 '\\n  ]\\n}\\n' 结束)")

    new_text = clean[: -len(suffix)] + ",\n" + block + "\n" + suffix
    # 校验: 前 5 门课文本一字未动 + JSON 合法 + 共 6 门
    idx = clean.rfind("\n  ]\n}")
    if not new_text.startswith(clean[:idx + 1]):
        raise SystemExit("内部错误: 既有课程文本被改动")
    new_data = json.loads(new_text)
    if [c["slug"] for c in new_data["courses"]] != [c["slug"] for c in data["courses"][:5]] + [COURSE_SLUG]:
        raise SystemExit("内部错误: 课程列表顺序异常")
    json_path.write_text(new_text, encoding="utf-8", newline="\n")
    return len(new_data["courses"])


# ---------------------------------------------------------------- 主流程

def main():
    parser = argparse.ArgumentParser(description="抓取 trpl-zh-cn 生成 seed 数据")
    parser.add_argument("--root", default=None,
                        help="code-tutorials 仓库根目录(默认: 脚本所在目录的上一级)")
    args = parser.parse_args()

    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parent.parent
    seed_dir = root / "backend" / "internal" / "store" / "seeddata"
    img_dir = root / "backend" / "static" / "images" / COURSE_SLUG
    courses_json = seed_dir / "courses.json"
    for p in (seed_dir, courses_json):
        if not p.exists():
            raise SystemExit("路径不存在: %s" % p)

    stats = Stats()

    # 1) 拉取并解析 SUMMARY.md
    summary_text = fetch(RAW_BASE + "SUMMARY.md")
    entries = parse_summary(summary_text)
    if len(entries) != EXPECTED_ENTRIES:
        raise SystemExit("SUMMARY 条目数 %d != 期望 %d" % (len(entries), EXPECTED_ENTRIES))
    slugs = []
    chapters = []
    for title_raw, path in entries:
        if "/" in path:
            raise SystemExit("SUMMARY 路径含子目录, 未支持: %s" % path)
        slug = posixpath.splitext(posixpath.basename(path))[0]
        slugs.append(slug)
        chapters.append((slug, clean_title(title_raw)))
    if len(set(slugs)) != len(slugs):
        raise SystemExit("slug 重复")

    # 2) 逐章抓取并转换(listings 缓存跨章复用)
    listing_cache = {}
    results = []
    for slug, (title, src_path) in zip(slugs, entries):
        raw = fetch(RAW_BASE + src_path)
        results.append((slug, convert_chapter(slug, raw, stats, listing_cache)))

    # 3) 写章节 md(防覆盖护栏: 已存在但缺本脚本署名 -> 报错停止)
    for slug, content in results:
        target = seed_dir / (slug + ".md")
        if target.exists():
            old = target.read_text(encoding="utf-8")
            if SIGNATURE not in old:
                raise SystemExit("目标已存在且不是本脚本产物(缺少署名块), 拒绝覆盖: %s" % target)
        target.write_text(content, encoding="utf-8", newline="\n")
        stats.chapters += 1

    # 4) 下载图片(原格式, 幂等: 内容一致则不重写)
    for src in sorted(stats.images):
        if not src:
            continue
        rel = src[len("img/"):] if src.startswith("img/") else src
        dest = img_dir / Path(*rel.split("/"))
        data = fetch(RAW_BASE + src, binary=True)
        if dest.exists() and dest.read_bytes() == data:
            stats.images_unchanged += 1
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            stats.images_downloaded += 1

    # 5) 完整性校验: 产物中每个图片引用必须对应已下载文件
    ref_re = re.compile(r"\]\(images/%s/([^)\s]+)\)" % COURSE_SLUG)
    broken = []
    for slug, content in results:
        for ref in ref_re.findall(content):
            if not (img_dir / Path(*ref.split("/"))).exists():
                broken.append("%s -> %s" % (slug, ref))
    if broken:
        raise SystemExit("存在未下载的图片引用 %d 处: %s" % (len(broken), broken[:5]))

    # 6) courses.json 追加第 6 门课
    course_count = update_courses_json(courses_json, chapters)

    print(stats.report())
    print("courses.json     : 共 %d 门课(第 %d 门为 %s)" % (course_count, COURSE_SORT, COURSE_SLUG))
    print("完成: %d 章 / %d 图片 -> %s" % (stats.chapters, len(stats.images), root))


if __name__ == "__main__":
    try:
        main()
    except SystemExit as e:
        print(e, file=sys.stderr)
        sys.exit(1)
