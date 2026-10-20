#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""课程打包器：从磁盘 seeddata + static/images 抽出一门课，打成管理端可导入的 zip。

zip 布局（与 POST /api/v1/admin/courses/import 契约一致，见 backend/API.md）：
  courses.json        仅含该课程的条目
  <chapter>.md ...    全部章节正文（zip 根，文件名与 chapters[].file 一致）
  images/<slug>/**    该课程图片（解压时落到静态图片根目录下）

用法（在仓库根目录执行）：
  python tools/pack_course.py --slug jetpack-compose
  python tools/pack_course.py --slug hello-algo --out dist

确定性打包：条目按路径排序 + 固定时间戳，重跑产出的 zip sha256 一致。
依赖：仅标准库。
"""

import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path

# 固定时间戳（zip 最小合法值），保证重跑产物逐字节一致
FIXED_DATE_TIME = (1980, 1, 1, 0, 0, 0)


def add_bytes(z: zipfile.ZipFile, name: str, data: bytes) -> None:
    zi = zipfile.ZipInfo(name, date_time=FIXED_DATE_TIME)
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.external_attr = 0o644 << 16
    z.writestr(zi, data)


def main() -> None:
    ap = argparse.ArgumentParser(description="打包一门课程为可导入的课程包 zip")
    ap.add_argument("--slug", required=True, help="课程 slug（courses.json 里的 slug）")
    ap.add_argument("--seeddata", default="backend/internal/store/seeddata", help="seeddata 目录")
    ap.add_argument("--images-root", default="backend/static/images", help="静态图片根目录")
    ap.add_argument("--out", default="dist", help="输出目录")
    args = ap.parse_args()

    seeddata = Path(args.seeddata)
    courses_path = seeddata / "courses.json"
    if not courses_path.is_file():
        sys.exit(f"找不到 {courses_path}")

    courses = json.loads(courses_path.read_text(encoding="utf-8"))["courses"]
    course = next((c for c in courses if c["slug"] == args.slug), None)
    if course is None:
        sys.exit(f"courses.json 中不存在课程 {args.slug}；现有: {[c['slug'] for c in courses]}")

    missing = [ch["file"] for ch in course["chapters"] if not (seeddata / ch["file"]).is_file()]
    if missing:
        sys.exit(f"缺失章节文件（共 {len(missing)}）: {missing[:10]}")

    img_dir = Path(args.images_root) / args.slug
    images = sorted(p for p in img_dir.rglob("*") if p.is_file()) if img_dir.is_dir() else []

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / f"{args.slug}.zip"
    img_bytes_total = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        add_bytes(z, "courses.json",
                  json.dumps({"courses": [course]}, ensure_ascii=False, indent=2).encode("utf-8") + b"\n")
        for ch in sorted(course["chapters"], key=lambda c: c["file"]):
            add_bytes(z, ch["file"], (seeddata / ch["file"]).read_bytes())
        for p in images:
            # 契约：zip 内 images/** 解压到静态图片根目录下，故补 images/ 前缀
            rel = "images/" + p.relative_to(args.images_root).as_posix()
            data = p.read_bytes()
            img_bytes_total += len(data)
            add_bytes(z, rel, data)

    print(f"课程: {course['title']}（{args.slug}）")
    print(f"章节: {len(course['chapters'])} 个 md")
    print(f"图片: {len(images)} 个，源体积 {img_bytes_total / 1024 / 1024:.1f}MB")
    print(f"输出: {zip_path}（{zip_path.stat().st_size / 1024 / 1024:.1f}MB）")
    print(f"sha256: {hashlib.sha256(zip_path.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
