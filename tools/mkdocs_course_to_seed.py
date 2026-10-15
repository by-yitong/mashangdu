#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mkdocs 教程仓库 -> 教程 App 后端 seed 格式 转换脚本。

用法示例（在仓库根目录执行）：
    python tools/mkdocs_course_to_seed.py \
        --repo krahets/hello-algo --branch main --docs-dir docs \
        --langs Python,Go --course-slug hello-algo --course-title "Hello 算法" \
        --language "Python/Go" --color "#059669" --sort-order 5 \
        --source-url https://www.hello-algo.com \
        --out backend/internal/store/seeddata

做什么：
  1. 拉取 mkdocs.yml，按 nav 顺序（唯一权威目录顺序）遍历所有页面；
  2. 逐页下载 docs/<path>.md 源文件并转换为纯 Markdown seed 正文：
     - 删除 frontmatter、正文第一个 H1、原生 HTML 块、mermaid 围栏；
     - ``=== "语言"`` 代码标签页只保留 --langs 指定的语言，内容去 4 空格缩进，
       去掉围栏 title="..." 属性，每个语言块前加 **语言** 加粗标签；
     - ``=== "<N>"`` 数字标签页（动画步骤图）拍平为顺序内容（契约未覆盖语法，
       按最接近契约精神处理）；
     - ``!!! / ???`` 警告框转块引用（`> **标题**` + `> ` 前缀）；
     - ``--8<-- "path"`` 包含指令递归取内容（先仓库根、再 docs/ 前缀，深度<=3）；
     - `` ```src `` 源码引用块（`[file]{..}-[class]{..}-[func]{..}`，契约未覆盖
       语法）从仓库 codes/<lang>/<章节>/ 提取真实 Python/Go 代码，按语言输出；
     - 相对图片路径改写为 jsdelivr CDN 绝对 URL，删除行尾 {..}/{:..} 属性；
     - 末尾追加署名行（CC BY-NC-SA 4.0 要求，不可省）。
  3. slug = {章节短名}-{文件名 stem}，sort_order 全书 nav 顺序全局递增；
  4. 幂等写出：md 按 slug 覆盖；courses.json 按 slug 原位替换、无则追加到末尾，
     其余课程内容原样保留。

依赖：仅标准库 + PyYAML。
"""

import argparse
import json
import posixpath
import re
import sys
import time
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("需要 PyYAML：pip install pyyaml")

# ---------------------------------------------------------------------------
# 内置配置（可被命令行参数覆盖的部分见 argparse）
# ---------------------------------------------------------------------------

# 章目录 -> slug 短名 映射（契约冻结；不在此表中的章目录整章跳过并告警）
DEFAULT_SHORT_NAME_MAP = {
    "chapter_hello_algo": "hello",
    "chapter_preface": "preface",
    "chapter_introduction": "introduction",
    "chapter_computational_complexity": "complexity",
    "chapter_data_structure": "data-structure",
    "chapter_array_and_linkedlist": "array-linkedlist",
    "chapter_stack_and_queue": "stack-queue",
    "chapter_hashing": "hashing",
    "chapter_tree": "tree",
    "chapter_heap": "heap",
    "chapter_graph": "graph",
    "chapter_searching": "searching",
    "chapter_sorting": "sorting",
    "chapter_divide_and_conquer": "divide-conquer",
    "chapter_backtracking": "backtracking",
    "chapter_dynamic_programming": "dp",
    "chapter_greedy": "greedy",
    "chapter_appendix": "appendix",
}

DEFAULT_SUMMARY = (
    "动画图解数据结构与算法，覆盖复杂度分析、经典数据结构与十大排序等 16 章。"
    "内容来自 krahets《Hello 算法》（hello-algo.com），遵循 CC BY-NC-SA 4.0 授权转载。"
)

DEFAULT_ATTRIBUTION = (
    "> 本文来自 [Hello 算法](https://www.hello-algo.com/)，"
    "作者 krahets，采用 CC BY-NC-SA 4.0 授权转载。"
)

# 代码语言 -> codes/ 目录与扩展名（用于 ```src 源码引用块的提取）
LANG_CODE_DIRS = {"python": ("python", ".py"), "go": ("go", ".go")}

USER_AGENT = "Mozilla/5.0 (seed-converter; mkdocs-course-to-seed)"
INCLUDE_MAX_DEPTH = 3  # --8<-- 递归深度上限（契约）

# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------


def fetch_text(url: str, retries: int = 2, timeout: int = 30) -> str:
    """GET 一个 URL，返回 utf-8 文本；失败重试 retries 次，最终抛异常。"""
    last_err = None
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read().decode("utf-8")
        except Exception as exc:  # noqa: BLE001 - 网络/404 等统一重试
            last_err = exc
            if attempt < retries:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"GET {url} 失败: {last_err}")


def fetch_text_or_none(url: str, retries: int = 2, timeout: int = 30):
    """同 fetch_text，但失败返回 None（用于可选包含场景）。"""
    try:
        return fetch_text(url, retries=retries, timeout=timeout)
    except Exception:  # noqa: BLE001
        return None


# ---------------------------------------------------------------------------
# nav 解析
# ---------------------------------------------------------------------------


def parse_nav(mkdocs_text: str):
    """解析 mkdocs.yml 的 nav，返回有序页面列表。

    每个元素: (组标题, nav标题或None, docs相对路径)。
    nav 条目两种形态：裸路径字符串（标题取该页 H1）或 {标题: 路径}。
    """
    cfg = yaml.safe_load(mkdocs_text)
    nav = cfg.get("nav") or []
    pages = []
    for group in nav:
        if not isinstance(group, dict) or len(group) != 1:
            continue
        group_title = next(iter(group))
        for entry in group[group_title] or []:
            if isinstance(entry, str):
                pages.append((group_title, None, entry))
            elif isinstance(entry, dict) and len(entry) == 1:
                title, path = next(iter(entry.items()))
                pages.append((group_title, str(title), str(path)))
    return pages


def clean_title(title: str) -> str:
    """标题清洗：&nbsp; 转空格、去掉结尾 ' *'、压缩连续空格。"""
    t = title.replace("&nbsp;", " ")
    t = re.sub(r"\s+\*\s*$", "", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t


def extract_h1(lines):
    """取正文第一个 H1 文本（跳过 frontmatter 与围栏内内容）。"""
    in_fence = False
    skip_fm = lines and lines[0].strip() == "---"
    for i, line in enumerate(lines):
        if skip_fm and i == 0:
            # 跳过 frontmatter 区块
            for j in range(1, min(len(lines), 40)):
                if lines[j].strip() == "---":
                    skip_fm = False
                    i = j
                    break
            if skip_fm:
                return ""
            continue
        if re.match(r"^```", line):
            in_fence = not in_fence
            continue
        if not in_fence and re.match(r"^#\s+\S", line):
            return re.sub(r"^#\s+", "", line).strip()
    return ""


# ---------------------------------------------------------------------------
# ```src 源码引用块：提取真实代码
# ---------------------------------------------------------------------------

SRC_SPEC_RE = re.compile(
    r"\[file\]\{(?P<file>[^}]*)\}-\[class\]\{(?P<cls>[^}]*)\}-\[func\]\{(?P<func>[^}]*)\}"
)


def _norm(name: str) -> str:
    """名字归一化：去非字母数字并转小写，用于跨语言类名/函数名匹配。

    例：linked_list_stack / LinkedListStack / linkedListStack 都归一为 linkedliststack。
    """
    return re.sub(r"[^0-9a-z]", "", name.lower())


# ----- Go 源码扫描：带字符串/注释感知的花括号深度计算 -----


def _go_scan_line(line: str, state: dict) -> int:
    """扫描一行 Go 代码，返回该行 {} 深度增量；state 保存跨行的字符串/注释状态。"""
    depth = 0
    i, n = 0, len(line)
    mode = state.get("mode", "normal")  # normal / line / block / str / raw / rune
    while i < n:
        c = line[i]
        nxt = line[i + 1] if i + 1 < n else ""
        if mode == "normal":
            if c == "/" and nxt == "/":
                break  # 行注释到行尾
            if c == "/" and nxt == "*":
                mode = "block"
                i += 2
                continue
            if c == '"':
                mode = "str"
                i += 1
                continue
            if c == "`":
                mode = "raw"
                i += 1
                continue
            if c == "'":
                mode = "rune"
                i += 1
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            i += 1
        elif mode == "block":
            if c == "*" and nxt == "/":
                mode = "normal"
                i += 2
                continue
            i += 1
        elif mode == "str":
            if c == "\\":
                i += 2
                continue
            if c == '"':
                mode = "normal"
            i += 1
        elif mode == "raw":
            if c == "`":
                mode = "normal"
            i += 1
        elif mode == "rune":
            if c == "\\":
                i += 2
                continue
            if c == "'":
                mode = "normal"
            i += 1
    if mode == "line":
        mode = "normal"
    state["mode"] = mode
    return depth


def _go_block_end(lines, start: int) -> int:
    """返回 Go 花括号块（lines[start] 为含 { 的起始行）的结束行下标（闭区间）。"""
    depth = 0
    state = {"mode": "normal"}
    for i in range(start, len(lines)):
        depth += _go_scan_line(lines[i], state)
        if depth <= 0 and i > start:
            return i
        if depth <= 0 and "{" in lines[i] and i == start and lines[i].rstrip().endswith("}"):
            return i  # 单行块
    return len(lines) - 1


def _take_preceding_comments(lines, idx: int, lang: str):
    """取紧贴定义上方、中间无空行的注释行（Python: #；Go: // 或单行 ）。"""
    out = []
    j = idx - 1
    while j >= 0:
        s = lines[j].strip()
        if lang == "python" and s.startswith("#"):
            out.append(lines[j])
        elif lang == "go" and (s.startswith("//") or (s.startswith("/*") and s.endswith("*/"))):
            out.append(lines[j])
        else:
            break
        j -= 1
    out.reverse()
    return out


def _py_class_spans(lines):
    """定位所有顶层 class 块：[(类名, 起行, 止行)]（止行闭区间）。"""
    spans = []
    i = 0
    while i < len(lines):
        m = re.match(r"^class\s+(\w+)", lines[i])
        if m:
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j][:1] in (" ", "\t")):
                j += 1
            j -= 1
            while j > i and not lines[j].strip():
                j -= 1
            spans.append((m.group(1), i, j))
            i = j + 1
        else:
            i += 1
    return spans


def extract_python(src: str, cls: str, func: str) -> str:
    """从 Python 源码提取类或函数体；cls/func 为文档中的逻辑名（归一化匹配）。"""
    lines = src.splitlines()
    norm_cls, norm_func = _norm(cls), _norm(func)

    target_span = None
    if norm_cls:
        target_span = next(
            ((s, e) for name, s, e in _py_class_spans(lines) if _norm(name) == norm_cls),
            None,
        )
        if target_span is None:
            return ""
        if not norm_func:
            # 只给了类名：输出整个类体（含类上方紧贴的注释行）
            s, e = target_span
            out = _take_preceding_comments(lines, s, "python") + lines[s : e + 1]
            while out and not out[-1].strip():
                out.pop()
            return "\n".join(out)

    def find_def(lo: int, hi: int):
        for k in range(lo, hi + 1):
            m = re.match(r"^(\s*)def\s+(\w+)", lines[k])
            if m and (not norm_func or _norm(m.group(2)) == norm_func):
                indent = len(m.group(1).expandtabs(4))
                e = k
                while e + 1 <= hi:
                    nxt = lines[e + 1]
                    if not nxt.strip():
                        e += 1
                        continue
                    if len(nxt.expandtabs(4)) - len(nxt.expandtabs(4).lstrip()) > indent:
                        e += 1
                        continue
                    break
                return (k, e)
        return None

    if target_span:
        span = find_def(target_span[0], target_span[1])
    else:
        span = find_def(0, len(lines) - 1)  # 顶层优先，找不到再看任何位置
    if span is None:
        return ""

    start, end = span
    out = _take_preceding_comments(lines, start, "python") + lines[start : end + 1]
    # 按定义行的缩进整体左移（方法提取时回到列 0）
    indent = len(re.match(r"[ \t]*", lines[start]).group(0))
    pat = re.compile(r"^[ \t]{%d}" % indent) if indent else None
    out = [(pat.sub("", ln) if (pat and ln.strip()) else ln) for ln in out]
    while out and not out[-1].strip():
        out.pop()
    return "\n".join(out)


def extract_go(src: str, cls: str, func: str) -> str:
    """从 Go 源码提取函数/方法；cls 模式输出 type 声明 + 全部方法 + 构造函数。"""
    lines = src.splitlines()
    norm_cls, norm_func = _norm(cls), _norm(func)

    funcs = []  # (接收者类型或"", 函数名, 起行, 止行)
    types = []  # (类型名, 起行, 止行)
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^func\s*(?:\(([^)]*)\))?\s*(\w+)\s*\(", line)
        if m:
            recv = ""
            if m.group(1):
                recv = m.group(1).replace("*", "").split()[-1]
            end = _go_block_end(lines, i)
            funcs.append((recv, m.group(2), i, end))
            i = end + 1
            continue
        m = re.match(r"^type\s+(\w+)", line)
        if m:
            end = _go_block_end(lines, i) if "{" in line else i
            types.append((m.group(1), i, end))
            i = end + 1
            continue
        i += 1

    def render(span):
        s, e = span
        head = _take_preceding_comments(lines, s, "go")
        body = lines[s : e + 1]
        while body and not body[-1].strip():
            body.pop()
        return head + body

    def join(blocks):
        out = []
        for b in blocks:
            if out:
                out.append("")
            out.extend(b)
        return "\n".join(out)

    def pick(cands, norm_name):
        """按 精确 -> 唯一后缀 -> 唯一前缀 匹配函数名。

        文档里的逻辑名是 Python 风格（如 insert / constant / pre_order），
        Go 侧常带语言特有前后缀（insertNode / spaceConstant / preOrderI），
        唯一匹配即认为是同一函数。
        """
        exact = [f for f in cands if _norm(f[1]) == norm_name]
        if exact:
            return exact[0]
        suffix = [f for f in cands if _norm(f[1]).endswith(norm_name)]
        if len(suffix) == 1:
            return suffix[0]
        prefix = [f for f in cands if _norm(f[1]).startswith(norm_name)]
        if len(prefix) == 1:
            return prefix[0]
        return None

    if norm_func:
        # Python 构造方法 __init__ 在 Go 侧对应 newXxx 构造函数
        if norm_func == "init" and norm_cls:
            cons = [f for f in funcs if not f[0] and _norm(f[1]) == "new" + norm_cls]
            if cons:
                return "\n".join(render(cons[0][2:]))
        candidates = [f for f in funcs if _norm(f[1]) == norm_func] or funcs
        if norm_cls:
            preferred = [f for f in candidates if _norm(f[0]) == norm_cls]
            candidates = preferred or candidates
        chosen = pick(candidates, norm_func)
        if chosen is None:
            return ""
        return "\n".join(render(chosen[2:]))

    if norm_cls:
        blocks = []
        for name, s, e in types:
            if _norm(name) == norm_cls:
                blocks.append(render((s, e)))
                break
        for recv, _name, s, e in funcs:
            if _norm(recv) == norm_cls:
                blocks.append(render((s, e)))
        for recv, name, s, e in funcs:
            if not recv and _norm(name) == "new" + norm_cls:
                blocks.append(render((s, e)))
        return join(blocks).strip()

    return ""


class SrcResolver:
    """拉取并缓存 codes/ 源码文件，按语言提取代码片段。"""

    def __init__(self, repo: str, branch: str, docs_dir: str, langs, retries=2, timeout=30):
        self.base = f"https://raw.githubusercontent.com/{repo}/{branch}/codes"
        self.docs_dir = docs_dir
        self.langs = [lang for lang in langs if lang.lower() in LANG_CODE_DIRS]
        self.retries = retries
        self.timeout = timeout
        self.cache = {}

    def _source(self, lang: str, chapter_dir: str, stem: str):
        if lang.lower() not in LANG_CODE_DIRS:
            return None
        code_dir, ext = LANG_CODE_DIRS[lang.lower()]
        url = f"{self.base}/{code_dir}/{chapter_dir}/{stem}{ext}"
        if url not in self.cache:
            self.cache[url] = fetch_text_or_none(url, retries=self.retries, timeout=self.timeout) or ""
        return self.cache[url] or None

    def resolve(self, spec: str, chapter_dir: str):
        """返回 ([(lang, code)], [提取失败的语言])。spec 不合法抛 ValueError。"""
        m = SRC_SPEC_RE.search(spec)
        if not m:
            raise ValueError(f"无法解析 src 规范: {spec.strip()[:80]}")
        stem, cls, func = m.group("file").strip(), m.group("cls").strip(), m.group("func").strip()
        out = []
        missing = []
        for lang in self.langs:
            src = self._source(lang, chapter_dir, stem)
            if src is None:
                missing.append(f"{lang}(源文件不存在)")
                continue
            if lang.lower() == "python":
                code = extract_python(src, cls, func)
            else:
                code = extract_go(src, cls, func)
            if code.strip():
                out.append((lang, code))
            else:
                missing.append(lang)
        return out, missing


# ---------------------------------------------------------------------------
# 页面正文转换
# ---------------------------------------------------------------------------

TAB_RE = re.compile(r'^===\s+"(?P<label>[^"]*)"\s*$')
ADMO_RE = re.compile(r'^(?P<mark>!{3}|\?{3})\s+(?P<type>[\w-]+)(?:\s+"(?P<title>[^"]*)")?\s*$')
STEP_TAB_RE = re.compile(r"^<\d+>$")
FENCE_RE = re.compile(r"^```(.*)$")
FENCE_TITLE_RE = re.compile(r'\s+title="[^"]*"')
INCLUDE_RE = re.compile(r"^--8<--\s+[\"'](?P<path>[^\"']+)[\"']\s*$")
IMG_RE = re.compile(r"!\[(?P<alt>[^\]]*)\]\((?P<url>[^)]+)\)")
TRAIL_ATTR_RE = re.compile(r"\s*\{[: ][^{}]*\}$")
STANDALONE_ATTR_RE = re.compile(r"^\{[: ][^{}]*\}$")
IMG_EXT = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp")


class Converter:
    """单页 Markdown 转换器（一次运行共用一个实例，聚合告警）。"""

    def __init__(self, args, cdn_base: str, src_resolver: SrcResolver):
        self.args = args
        self.cdn_base = cdn_base.rstrip("/")
        self.resolver = src_resolver
        self.warnings = []

    def warn(self, page: str, msg: str):
        self.warnings.append(f"[{page}] {msg}")

    # ---- 主入口 ----

    def convert(self, text: str, doc_path: str, depth: int = 0) -> str:
        """转换一页：返回纯文本 Markdown 正文（不含署名行）。"""
        page = posixpath.basename(doc_path)
        lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        lines = self._strip_frontmatter(lines)
        lines = self._drop_first_h1(lines)
        out = self._transform(lines, page, doc_path, depth)
        out = self._post_process(out, page, doc_path)
        out = self._tidy(out)
        return "\n".join(out)

    # ---- 各步骤 ----

    @staticmethod
    def _strip_frontmatter(lines):
        if lines and lines[0].strip() == "---":
            for i in range(1, min(len(lines), 40)):
                if lines[i].strip() == "---":
                    return lines[i + 1 :]
        return lines

    @staticmethod
    def _drop_first_h1(lines):
        """删除正文第一个 H1 行（标题进 courses.json 的 title 字段）。"""
        in_fence = False
        for i, line in enumerate(lines):
            if FENCE_RE.match(line):
                in_fence = not in_fence
                continue
            if not in_fence and re.match(r"^#\s+\S", line):
                return lines[:i] + lines[i + 1 :]
        return lines

    @staticmethod
    def _collect_indented_block(lines, start: int):
        """收集 4 空格缩进块，返回 (去缩进内容行, 停止下标)。

        块 = 从 start 起，直到第一条非空且缩进 <4 的行；块尾空行剔除。
        """
        body = []
        i = start
        last_content = -1
        while i < len(lines):
            line = lines[i]
            if line.strip() == "":
                body.append("")
                i += 1
                continue
            if line.startswith("    ") or line.startswith("\t"):
                body.append(line[4:] if line.startswith("    ") else line.lstrip("\t").expandtabs(4))
                last_content = len(body) - 1
                i += 1
                continue
            break
        return body[: last_content + 1], i

    def _transform(self, lines, page: str, doc_path: str, depth: int):
        """结构化转换主循环：标签页 / 警告框 / 包含 / src / mermaid / 围栏。"""
        out = []
        i = 0
        n = len(lines)
        while i < n:
            line = lines[i]

            # --- 代码语言标签页 / 数字步骤标签页（连续 === 视为一组）---
            if TAB_RE.match(line):
                tabs = []
                while i < n and TAB_RE.match(lines[i]):
                    label = TAB_RE.match(lines[i]).group("label")
                    body, i = self._collect_indented_block(lines, i + 1)
                    tabs.append((label, body))
                    while i < n and lines[i].strip() == "":
                        i += 1
                out.extend(self._emit_tabs(tabs, page, doc_path, depth))
                if out and out[-1].strip():
                    out.append("")  # 与后续正文保持空行分隔
                continue

            # --- admonition 警告框 -> 块引用 ---
            m = ADMO_RE.match(line)
            if m:
                title = m.group("title")
                body, i = self._collect_indented_block(lines, i + 1)
                conv = self._transform(body, page, doc_path, depth)
                while conv and not conv[0].strip():
                    conv.pop(0)
                while conv and not conv[-1].strip():
                    conv.pop()
                quote = []
                if title:
                    quote.append(f"> **{title}**")
                for ln in conv:
                    quote.append(("> " + ln).rstrip())
                if quote:
                    out.append("")
                    out.extend(quote)
                    out.append("")
                continue

            # --- --8<-- 文件包含 ---
            m = INCLUDE_RE.match(line)
            if m:
                inc_path = m.group("path")
                included = self._fetch_include(inc_path, page, depth)
                if included is not None:
                    out.extend(self._transform(included, page, inc_path, depth + 1))
                else:
                    self.warn(page, f"包含指令取不到内容，已删除: {inc_path}")
                i += 1
                continue

            # --- ```src 源码引用块 -> 按语言输出真实代码 ---
            m = FENCE_RE.match(line)
            if m and m.group(1).strip() == "src":
                j = i + 1
                spec_lines = []
                while j < n and not FENCE_RE.match(lines[j]):
                    spec_lines.append(lines[j])
                    j += 1
                spec = " ".join(s.strip() for s in spec_lines if s.strip())
                chapter_dir = posixpath.dirname(doc_path)
                try:
                    pairs, missing = self.resolver.resolve(spec, chapter_dir)
                except ValueError as exc:
                    self.warn(page, str(exc))
                    pairs, missing = [], []
                for lang in missing:
                    self.warn(page, f"src 引用块 {lang} 代码提取失败，已跳过: {spec[:80]}")
                if not pairs:
                    self.warn(page, f"src 引用块提取不到代码，已删除: {spec[:80]}")
                for lang, code in pairs:
                    out.append("")
                    out.append(f"**{lang}**")
                    out.append("")
                    out.append("```" + lang.lower())
                    out.extend(code.split("\n"))
                    out.append("```")
                    out.append("")
                i = j + 1
                continue

            # --- mermaid 围栏：整块删除并告警 ---
            if m and m.group(1).strip() == "mermaid":
                j = i + 1
                while j < n and not FENCE_RE.match(lines[j]):
                    j += 1
                self.warn(page, "mermaid 围栏已删除")
                i = j + 1
                continue

            # --- 普通围栏：原样复制，去掉 info 串中的 title 属性 ---
            if m:
                out.append(FENCE_TITLE_RE.sub("", line))
                i += 1
                continue

            out.append(line)
            i += 1
        return out

    def _emit_tabs(self, tabs, page: str, doc_path: str, depth: int):
        """输出一组标签页：语言页签按 --langs 过滤，数字页签（动画步骤）拍平。"""
        keep = self.args.langs
        if all(STEP_TAB_RE.match(lbl) for lbl, _ in tabs):
            out = []
            for _lbl, body in tabs:
                if not any(b.strip() for b in body):
                    continue
                out.append("")
                out.extend(self._transform(body, page, doc_path, depth))
            return out
        out = []
        for label, body in tabs:
            if label not in keep:
                continue
            conv = self._transform(body, page, doc_path, depth)
            while conv and not conv[0].strip():
                conv.pop(0)
            while conv and not conv[-1].strip():
                conv.pop()
            if not conv:
                continue
            out.append("")
            out.append(f"**{label}**")
            out.append("")
            out.extend(conv)
        return out

    def _fetch_include(self, inc_path: str, page: str, depth: int):
        """--8<-- 包含：先按仓库根相对路径取，404 再按 docs/ 前缀取；深度受限。"""
        if depth >= INCLUDE_MAX_DEPTH:
            self.warn(page, f"包含嵌套超深（>{INCLUDE_MAX_DEPTH}），已删除: {inc_path}")
            return None
        root = f"https://raw.githubusercontent.com/{self.args.repo}/{self.args.branch}"
        for candidate in (f"{root}/{inc_path}", f"{root}/{self.args.docs_dir}/{inc_path}"):
            text = fetch_text_or_none(candidate, retries=self.args.retries, timeout=self.args.timeout)
            if text is not None:
                return text.replace("\r\n", "\n").split("\n")
        return None

    def _rewrite_image(self, m, doc_path: str) -> str:
        """相对图片路径 -> jsdelivr 绝对 URL；已是绝对地址则原样保留。"""
        url = m.group("url").strip()
        if re.match(r"^[a-zA-Z]+://", url) or url.startswith("//") or url.startswith("data:"):
            return f"![{m.group('alt')}]({url})"
        base_dir = posixpath.dirname(doc_path)
        resolved = posixpath.normpath(posixpath.join(base_dir, url))
        return f"![{m.group('alt')}]({self.cdn_base}/{resolved})"

    def _post_process(self, lines, page: str, doc_path: str):
        """围栏外收尾：图片改写、行尾属性删除、原生 HTML 清理、行内 <u> 去壳。"""
        out = []
        in_fence = False
        i = 0
        n = len(lines)
        while i < n:
            line = lines[i]
            if FENCE_RE.match(line):
                in_fence = not in_fence
                out.append(line)
                i += 1
                continue
            if in_fence:
                out.append(line)
                i += 1
                continue

            # 原生 HTML 块：<div>/<figure>/<center> ... 到配对闭合标签
            hm = re.match(r"^<(div|figure|center)\b[^>]*>", line)
            if hm:
                tag = hm.group(1)
                depth_tag = 1
                j = i
                while j < n - 1 and depth_tag > 0:
                    j += 1
                    depth_tag += len(re.findall(rf"<{tag}\b[^>]*>", lines[j]))
                    depth_tag -= len(re.findall(rf"</{tag}>", lines[j]))
                self.warn(page, f"删除原生 HTML 块 <{tag}>（{j - i + 1} 行）")
                i = j + 1
                continue

            # 单行 HTML（表格标题 <p>、<h*> 等）：整行删除
            if re.match(r"^<p\b[^>]*>.*</p>\s*$", line) or re.match(r"^<h[1-6]\b[^>]*>.*</h[1-6]>\s*$", line):
                self.warn(page, f"删除单行 HTML 块: {line.strip()[:60]}")
                i += 1
                continue

            # 行内 <u> 标签：去壳留字（术语下划线仅是排版样式）
            line = re.sub(r"</?u>", "", line)

            # 图片路径改写 + 行尾 {..}/{:..} 属性删除
            line = IMG_RE.sub(lambda m: self._rewrite_image(m, doc_path), line)
            line = TRAIL_ATTR_RE.sub("", line)
            if STANDALONE_ATTR_RE.match(line.strip()):
                i += 1
                continue

            out.append(line)
            i += 1
        return out

    @staticmethod
    def _tidy(lines):
        """去首尾空行、压缩 3+ 连续空行为 2。"""
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        out = []
        blanks = 0
        for ln in lines:
            if ln.strip() == "":
                blanks += 1
                if blanks > 2:
                    continue
            else:
                blanks = 0
            out.append(ln)
        return out


# ---------------------------------------------------------------------------
# courses.json 输出（保持既有文件的手写风格：章节一行一个对象）
# ---------------------------------------------------------------------------


def dump_courses_json(courses) -> str:
    """按既有 courses.json 的排版风格序列化（2 空格缩进、章节单行对象）。"""
    parts = ['{\n  "courses": [\n']
    for ci, course in enumerate(courses):
        parts.append("    {\n")
        parts.append('      "slug": %s,\n' % json.dumps(course["slug"], ensure_ascii=False))
        parts.append('      "title": %s,\n' % json.dumps(course["title"], ensure_ascii=False))
        parts.append('      "summary": %s,\n' % json.dumps(course["summary"], ensure_ascii=False))
        parts.append('      "language": %s,\n' % json.dumps(course["language"], ensure_ascii=False))
        parts.append('      "color": %s,\n' % json.dumps(course["color"], ensure_ascii=False))
        parts.append('      "sort_order": %d,\n' % course["sort_order"])
        parts.append('      "chapters": [\n')
        chs = course["chapters"]
        for ki, ch in enumerate(chs):
            one = json.dumps(ch, ensure_ascii=False)
            comma = "," if ki < len(chs) - 1 else ""
            parts.append("        %s%s\n" % (one, comma))
        parts.append("      ]\n")
        parts.append("    }" + ("," if ci < len(courses) - 1 else "") + "\n")
    parts.append("  ]\n}\n")
    return "".join(parts)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="mkdocs 教程仓库转 seed 格式（详见文件头注释）")
    p.add_argument("--repo", default="krahets/hello-algo", help="GitHub 仓库 owner/name")
    p.add_argument("--branch", default="main", help="分支名")
    p.add_argument("--docs-dir", default="docs", help="仓库内 mkdocs 文档源目录（raw 路径前缀）")
    p.add_argument("--langs", default="Python,Go", help="保留的代码标签页语言，逗号分隔")
    p.add_argument("--course-slug", default="hello-algo", help="课程 slug")
    p.add_argument("--course-title", default="Hello 算法", help="课程标题")
    p.add_argument("--summary", default=DEFAULT_SUMMARY, help="课程简介")
    p.add_argument("--language", default="Python/Go", help="课程语言标注")
    p.add_argument("--color", default="#059669", help="课程主题色")
    p.add_argument("--sort-order", type=int, default=5, help="课程 sort_order")
    p.add_argument("--source-url", default="https://www.hello-algo.com", help="来源站点（署名用）")
    p.add_argument("--attribution", default=None, help="自定义署名行（默认 Hello 算法 CC BY-NC-SA 4.0）")
    p.add_argument("--out", default="backend/internal/store/seeddata", help="seeddata 输出目录")
    p.add_argument("--short-map-json", default=None, help="覆盖内置章目录->短名映射（JSON 文件）")
    p.add_argument("--limit", type=int, default=0, help="只转换前 N 页（调试用，0=全部）")
    p.add_argument("--timeout", type=int, default=30, help="HTTP 超时秒数")
    p.add_argument("--retries", type=int, default=2, help="HTTP 失败重试次数")
    return p


def main(argv=None) -> int:
    args = build_arg_parser().parse_args(argv)
    args.langs = [s.strip() for s in args.langs.split(",") if s.strip()]
    raw_base = f"https://raw.githubusercontent.com/{args.repo}/{args.branch}"
    docs_base = f"{raw_base}/{args.docs_dir}"
    cdn_base = f"https://cdn.jsdelivr.net/gh/{args.repo}@{args.branch}/{args.docs_dir}"
    attribution = args.attribution or DEFAULT_ATTRIBUTION

    short_map = dict(DEFAULT_SHORT_NAME_MAP)
    if args.short_map_json:
        short_map.update(json.loads(Path(args.short_map_json).read_text(encoding="utf-8")))

    # 1. 拉取 nav（唯一权威目录顺序）
    print(f"==> 拉取 mkdocs.yml: {raw_base}/mkdocs.yml")
    mkdocs_text = fetch_text(f"{raw_base}/mkdocs.yml", retries=args.retries, timeout=args.timeout)
    pages = parse_nav(mkdocs_text)
    print(f"    nav 条目共 {len(pages)} 条")

    # 2. 过滤：章目录必须在短名映射中，否则整章跳过并告警
    selected = []
    for _group, nav_title, doc_path in pages:
        if not doc_path.endswith(".md"):
            print(f"    [跳过] 非 md 条目: {doc_path}")
            continue
        chapter_dir = doc_path.split("/")[0]
        if chapter_dir not in short_map:
            print(f"    [跳过] 章目录无短名映射: {doc_path}")
            continue
        selected.append((doc_path, nav_title))
    if args.limit:
        selected = selected[: args.limit]

    resolver = SrcResolver(args.repo, args.branch, args.docs_dir, args.langs,
                           retries=args.retries, timeout=args.timeout)
    conv = Converter(args, cdn_base, resolver)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    # 3. 逐页下载并转换
    chapters = []
    slugs_seen = set()
    total_bytes = 0
    for idx, (doc_path, nav_title) in enumerate(selected, start=1):
        stem = Path(doc_path).stem
        chapter_dir = doc_path.split("/")[0]
        slug = f"{short_map[chapter_dir]}-{stem}"
        if slug in slugs_seen:
            conv.warn(doc_path, f"slug 重复: {slug}，该页已跳过")
            print(f"    [错误] slug 重复: {slug}，跳过 {doc_path}")
            continue
        slugs_seen.add(slug)

        try:
            text = fetch_text(f"{docs_base}/{doc_path}", retries=args.retries, timeout=args.timeout)
        except Exception as exc:  # noqa: BLE001
            conv.warn(doc_path, f"下载失败: {exc}")
            print(f"    [错误] 下载失败 {doc_path}: {exc}")
            continue

        if nav_title:
            title = clean_title(nav_title)
        else:
            title = clean_title(extract_h1(text.replace("\r\n", "\n").split("\n")) or stem)

        body = conv.convert(text, doc_path)
        content = body + "\n\n" + attribution + "\n"
        encoded = content.encode("utf-8")  # UTF-8 无 BOM；write_bytes 保持 LF
        (out_dir / f"{slug}.md").write_bytes(encoded)
        total_bytes += len(encoded)
        chapters.append({"slug": slug, "title": title, "sort_order": idx, "file": f"{slug}.md"})
        print(f"    [{idx:3d}/{len(selected)}] {slug}  <-  {doc_path}  ({len(encoded)} B)")

    # 4. courses.json：按 slug 原位替换（幂等），无则追加到末尾；其余课程原样保留
    json_path = out_dir / "courses.json"
    data = json.loads(json_path.read_text(encoding="utf-8")) if json_path.exists() else {"courses": []}
    new_course = {
        "slug": args.course_slug,
        "title": args.course_title,
        "summary": args.summary,
        "language": args.language,
        "color": args.color,
        "sort_order": args.sort_order,
        "chapters": chapters,
    }
    replaced = False
    for i, c in enumerate(data["courses"]):
        if c.get("slug") == args.course_slug:
            data["courses"][i] = new_course
            replaced = True
            break
    if not replaced:
        data["courses"].append(new_course)
    json_path.write_bytes(dump_courses_json(data["courses"]).encode("utf-8"))

    # 5. 统计与告警
    print("\n===== 统计 =====")
    print(f"章节数: {len(chapters)}")
    print(f"输出总字节: {total_bytes}")
    if conv.warnings:
        print(f"警告 {len(conv.warnings)} 条:")
        for w in conv.warnings:
            print(f"  - {w}")
    else:
        print("警告: 无")
    print(f"courses.json 已{'原位替换' if replaced else '末尾追加'}课程 {args.course_slug}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
