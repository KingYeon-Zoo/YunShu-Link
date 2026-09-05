#!/usr/bin/env python3
"""抓取开源中文语料，生成演示用知识库文档与对应的 SQL 片段。

语料来源都是 MIT 协议的公开仓库，不含任何本项目自造内容：

  - pwxcoo/chinese-xinhua   成语词典、歇后语
  - chinese-poetry/chinese-poetry  论语、元曲、幽梦影

产物有两份，都会提交进仓库，因此演示重置流程本身不需要联网：

  scripts/demo/corpus/<知识库>/*.md   真实语料文档，将来接上 RAGFlow 可直接上传
  scripts/demo/seed-demo-knowledge.sql  由上面文件的真实体积/切片数生成的影子表数据

只有需要更新语料时才重跑本脚本：

  python3 scripts/demo/fetch-demo-corpus.py
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORPUS_DIR = ROOT / "scripts" / "demo" / "corpus"
SQL_OUT = ROOT / "scripts" / "demo" / "seed-demo-knowledge.sql"
DOCS_DIR = ROOT / "docs"

XINHUA = "https://raw.githubusercontent.com/pwxcoo/chinese-xinhua/master/data/"
POETRY = "https://raw.githubusercontent.com/chinese-poetry/chinese-poetry/master/"

# 一个切片约 600 字；用于把真实文档体积换算成看起来自洽的切片与 Token 统计。
CHARS_PER_CHUNK = 600
CHARS_PER_TOKEN = 1.5


def fetch_json(url: str, attempts: int = 4) -> object:
    """抓取 JSON。raw.githubusercontent.com 偶发 SSL 断流，重试几次即可。"""
    request = urllib.request.Request(
        urllib.parse.quote(url, safe=":/"),
        headers={"User-Agent": "yunshu-link-demo-corpus"},
    )
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, ssl.SSLError) as exc:
            last_error = exc
            if attempt < attempts:
                print(f"  第 {attempt} 次抓取失败，重试：{url.rsplit('/', 1)[-1]}")
                time.sleep(2 * attempt)
    raise SystemExit(f"抓取失败 {url}：{last_error}")


@dataclass
class Document:
    name: str
    body: str


@dataclass
class KnowledgeBase:
    slug: str
    name: str
    description: str
    documents: list[Document] = field(default_factory=list)


def is_simplified(text: str) -> bool:
    """粗筛繁体，避免简繁混排。

    字表不含「於」「爲」等古文引文里合法保留的异体字，只挑简体中绝不会出现的形。
    """
    return not any(char in text for char in "來說時對這將無讓國學實體變萬個們")


def build_idiom_kb() -> KnowledgeBase:
    """成语词典按拼音首字母分卷，每卷一个文档。"""
    entries = fetch_json(XINHUA + "idiom.json")
    groups: dict[str, list[dict]] = {}
    for entry in entries:
        explanation = (entry.get("explanation") or "").strip()
        word = (entry.get("word") or "").strip()
        if not word or not explanation or len(explanation) < 8:
            continue
        initial = (entry.get("abbreviation") or "?")[0].upper()
        if not initial.isalpha():
            continue
        groups.setdefault(initial, []).append(entry)

    # 取词条最多的 8 个字母，每卷截断到 220 条，控制单文档体积。
    picked = sorted(groups.items(), key=lambda item: -len(item[1]))[:8]
    kb = KnowledgeBase(
        slug="chengyu",
        name="成语典故词库",
        description="源自开源新华字典项目的成语释义与出处，按拼音首字母分卷，可用于成语接龙、释义问答。",
    )
    for initial, items in sorted(picked):
        lines = [f"# 成语典故词库 · {initial} 卷", ""]
        for entry in items[:220]:
            lines.append(f"## {entry['word']}")
            lines.append(f"- 拼音：{entry.get('pinyin') or '—'}")
            lines.append(f"- 释义：{entry['explanation'].strip()}")
            derivation = (entry.get("derivation") or "").strip()
            if derivation and derivation != "无":
                lines.append(f"- 出处：{derivation}")
            example = (entry.get("example") or "").strip()
            if example and example != "无":
                lines.append(f"- 例句：{example}")
            lines.append("")
        kb.documents.append(
            Document(f"成语典故-{initial}卷.md", "\n".join(lines).rstrip() + "\n")
        )
    return kb


def build_xiehouyu_kb() -> KnowledgeBase:
    """歇后语按条数均分成若干册。"""
    entries = [
        entry
        for entry in fetch_json(XINHUA + "xiehouyu.json")
        if (entry.get("riddle") or "").strip() and (entry.get("answer") or "").strip()
    ][:2400]

    kb = KnowledgeBase(
        slug="xiehouyu",
        name="民间歇后语与俗语",
        description="开源新华字典项目收录的歇后语，含谜面与谜底，用于方言趣味问答和语音互动游戏。",
    )
    per_volume = 400
    for index in range(0, len(entries), per_volume):
        volume = index // per_volume + 1
        chunk = entries[index : index + per_volume]
        lines = [f"# 民间歇后语 · 第 {volume} 册", ""]
        for entry in chunk:
            lines.append(f"- {entry['riddle'].strip()} —— {entry['answer'].strip()}")
        kb.documents.append(
            Document(f"民间歇后语-第{volume}册.md", "\n".join(lines) + "\n")
        )
    return kb


def build_guoxue_kb() -> KnowledgeBase:
    """论语按篇拆分，附元曲与幽梦影选段。"""
    kb = KnowledgeBase(
        slug="guoxue",
        name="国学启蒙语料库",
        description="论语全文按篇拆分，另收元曲与幽梦影选段，供国学陪伴型智能体做原文引用与讲解。",
    )

    for chapter in fetch_json(POETRY + "论语/lunyu.json"):
        title = (chapter.get("chapter") or "").strip()
        paragraphs = [p.strip() for p in chapter.get("paragraphs", []) if p.strip()]
        if not title or not paragraphs:
            continue
        lines = [f"# 论语 · {title}", ""]
        for order, paragraph in enumerate(paragraphs, start=1):
            lines.append(f"{order}. {paragraph}")
        kb.documents.append(Document(f"论语-{title}.md", "\n".join(lines) + "\n"))

    yuanqu = [
        item
        for item in fetch_json(POETRY + "元曲/yuanqu.json")
        if item.get("title") and item.get("paragraphs")
    ][:260]
    lines = ["# 元曲选段", ""]
    for item in yuanqu:
        lines.append(f"## {item['title']}")
        lines.append(f"作者：{item.get('author') or '佚名'}")
        lines.append("")
        lines.extend(
            paragraph.strip() for paragraph in item["paragraphs"] if paragraph.strip()
        )
        lines.append("")
    kb.documents.append(Document("元曲选段.md", "\n".join(lines).rstrip() + "\n"))

    lines = ["# 幽梦影", ""]
    for item in fetch_json(POETRY + "幽梦影/youmengying.json"):
        content = (item.get("content") or "").strip()
        if not content:
            continue
        lines.append(f"- {content}")
        for comment in item.get("comment", []):
            comment = comment.strip()
            if comment:
                lines.append(f"  - {comment}")
    kb.documents.append(Document("幽梦影.md", "\n".join(lines) + "\n"))

    for document in kb.documents:
        if not is_simplified(document.body[:400]):
            raise SystemExit(f"{document.name} 疑似繁体，请检查语料来源")
    return kb


def build_product_kb() -> KnowledgeBase:
    """产品文档知识库直接取仓库 docs/ 下现成的集成说明。"""
    picks = [
        ("ota-upgrade-guide.md", "OTA 固件升级指南.md"),
        ("firmware-build.md", "固件编译说明.md"),
        ("firmware-setting.md", "固件配置说明.md"),
        ("mqtt-gateway-integration.md", "MQTT 网关接入.md"),
        ("voiceprint-integration.md", "声纹识别接入.md"),
        ("ragflow-integration.md", "RAGFlow 知识库接入.md"),
        ("mcp-endpoint-integration.md", "MCP 接入点说明.md"),
        ("device-call-guide.md", "设备呼叫功能说明.md"),
        ("FAQ.md", "常见问题解答.md"),
    ]
    kb = KnowledgeBase(
        slug="product",
        name="云枢产品文档库",
        description="云枢智联的固件烧录、OTA 升级、网关接入与常见问题文档，供售后型智能体直接检索作答。",
    )
    for source, target in picks:
        path = DOCS_DIR / source
        if not path.is_file():
            print(f"  跳过缺失文档：docs/{source}")
            continue
        kb.documents.append(Document(target, path.read_text(encoding="utf-8")))
    if not kb.documents:
        raise SystemExit("docs/ 下未找到任何可用文档")
    return kb


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def dataset_id(slug: str) -> str:
    """稳定的伪 RAGFlow dataset id，重跑脚本不会变。"""
    return hashlib.sha256(f"yunshu-demo-dataset-{slug}".encode()).hexdigest()[:32]


def document_id(slug: str, name: str) -> str:
    return hashlib.sha256(f"yunshu-demo-doc-{slug}-{name}".encode()).hexdigest()[:32]


def render_sql(bases: list[KnowledgeBase]) -> str:
    lines = [
        "-- 由 scripts/demo/fetch-demo-corpus.py 生成，请勿手工编辑。",
        "-- 语料来自 MIT 协议的 pwxcoo/chinese-xinhua 与 chinese-poetry/chinese-poetry，",
        "-- 以及本仓库 docs/ 下的产品文档；正文文件在 scripts/demo/corpus/。",
        "--",
        "-- rag_model_id 必须留空：非空时列表接口会去 RAGFlow 核对，演示环境没有",
        "-- RAGFlow 服务，核对失败会让知识库卡片变红并弹出英文异常。留空则整条",
        "-- 同步链路短路（KnowledgeBaseServiceImpl#syncDatasetFromRAG）。",
        "-- run 固定为 DONE：其余状态会让前端把文档显示成待解析，并触发远端同步。",
        "",
        "DELETE FROM `ai_rag_knowledge_document`;",
        "DELETE FROM `ai_rag_dataset`;",
        "",
    ]

    dataset_rows: list[str] = []
    document_rows: list[str] = []

    for order, base in enumerate(bases, start=1):
        ds_id = dataset_id(base.slug)
        total_chars = sum(len(doc.body) for doc in base.documents)
        total_chunks = 0
        total_tokens = 0

        for doc_order, document in enumerate(base.documents, start=1):
            size = len(document.body.encode("utf-8"))
            chunk_count = max(1, len(document.body) // CHARS_PER_CHUNK)
            token_count = int(len(document.body) / CHARS_PER_TOKEN)
            total_chunks += chunk_count
            total_tokens += token_count
            document_rows.append(
                "({}, {}, {}, {}, {}, {}, 'naive', '1', 'DONE', 1, {}, {}, 1, "
                "@demo_user_id, DATE_SUB(NOW(), INTERVAL {} MINUTE), "
                "DATE_SUB(NOW(), INTERVAL {} MINUTE))".format(
                    sql_literal(document_id(base.slug, document.name)),
                    sql_literal(ds_id),
                    sql_literal(document_id(base.slug, document.name)),
                    sql_literal(document.name),
                    size,
                    sql_literal(document.name.rsplit(".", 1)[-1]),
                    chunk_count,
                    token_count,
                    # 越靠前的文档上传时间越晚，列表按 created_at 倒序展示。
                    order * 180 + doc_order * 7,
                    order * 180 + doc_order * 7 - 3,
                )
            )

        dataset_rows.append(
            "({}, {}, NULL, {}, {}, 'bge-large-zh-v1.5', 'me', 'naive', {}, {}, {}, 1, "
            "@demo_user_id, DATE_SUB(NOW(), INTERVAL {} DAY), "
            "@demo_user_id, DATE_SUB(NOW(), INTERVAL {} MINUTE))".format(
                sql_literal(ds_id),
                sql_literal(ds_id),
                sql_literal(base.name),
                sql_literal(base.description),
                total_chunks,
                len(base.documents),
                total_tokens,
                order + 2,
                order * 180,
            )
        )
        print(
            f"  {base.name}：{len(base.documents)} 篇 / "
            f"{total_chars // 1000}k 字 / {total_chunks} 切片"
        )

    lines.append("INSERT INTO `ai_rag_dataset`")
    lines.append(
        "(`id`, `dataset_id`, `rag_model_id`, `name`, `description`, `embedding_model`, "
        "`permission`, `chunk_method`, `chunk_count`, `document_count`, `token_num`, "
        "`status`, `creator`, `created_at`, `updater`, `updated_at`)"
    )
    lines.append("VALUES")
    lines.append(",\n".join(dataset_rows) + ";")
    lines.append("")
    lines.append("INSERT INTO `ai_rag_knowledge_document`")
    lines.append(
        "(`id`, `dataset_id`, `document_id`, `name`, `size`, `type`, `chunk_method`, "
        "`status`, `run`, `progress`, `chunk_count`, `token_count`, `enabled`, "
        "`creator`, `created_at`, `updated_at`)"
    )
    lines.append("VALUES")
    lines.append(",\n".join(document_rows) + ";")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="生成演示知识库语料")
    parser.add_argument(
        "--keep-existing",
        action="store_true",
        help="保留 corpus/ 下已有文件，只重新生成 SQL",
    )
    args = parser.parse_args()

    print("抓取开源语料……")
    bases = [
        build_guoxue_kb(),
        build_idiom_kb(),
        build_xiehouyu_kb(),
        build_product_kb(),
    ]

    if not args.keep_existing and CORPUS_DIR.exists():
        shutil.rmtree(CORPUS_DIR)
    for base in bases:
        target_dir = CORPUS_DIR / base.slug
        target_dir.mkdir(parents=True, exist_ok=True)
        for document in base.documents:
            (target_dir / document.name).write_text(document.body, encoding="utf-8")

    print("生成 SQL 片段……")
    SQL_OUT.write_text(render_sql(bases), encoding="utf-8")

    total_bytes = sum(
        path.stat().st_size for path in CORPUS_DIR.rglob("*.md")
    )
    print(f"完成：{CORPUS_DIR.relative_to(ROOT)} 共 {total_bytes // 1024} KiB")
    print(f"      {SQL_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
