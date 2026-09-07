#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "agent" / "skills" / "docs-okf" / "scripts"))
import validate_bundle  # noqa: E402


FRONTMATTER = """\
---
type: Business Domain
title: 示例业务域
description: 示例
tags: [business, BD]
timestamp: "2026-06-16T00:00:00Z"
full_id: BD-EXAMPLE
perspective: business
hierarchy: BD
parent_id: null
layer_scope: application
---
"""


def _write_bundle(tmp: str, headings: list[str]) -> Path:
    root = Path(tmp) / "application"
    (root / "knowledge" / "business").mkdir(parents=True)
    (root / "index.md").write_text('---\nokf_version: "0.1"\n---\n', encoding="utf-8")
    body = "\n\n".join(f"{heading}\n\n- (none)" for heading in headings)
    (root / "knowledge" / "business" / "BD-EXAMPLE.md").write_text(
        FRONTMATTER + body + "\n",
        encoding="utf-8",
    )
    return root


def test_validator_accepts_legacy_english_h1_sections() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = _write_bundle(
            tmp,
            ["# Relations", "# Cross-perspective", "# Details", "# Evidence"],
        )
        validator = validate_bundle.Validator(root, "application")
        code = validator.run()
        assert code == 0


def test_validator_accepts_target_chinese_h2_sections() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = _write_bundle(
            tmp,
            ["## 关系", "## 跨视角", "## 详细说明", "## 依据与证据"],
        )
        validator = validate_bundle.Validator(root, "application")
        code = validator.run()
        assert code == 0


def test_validator_rejects_missing_section() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = _write_bundle(
            tmp,
            ["## 关系", "## 跨视角", "## 详细说明"],
        )
        validator = validate_bundle.Validator(root, "application")
        code = validator.run()
        assert code == 1


def test_validator_no_downstream_bundle_fallback() -> None:
    """system 不得把 /knowledge/… 回退到 application（禁止引下层）。"""
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        api = (
            repo
            / "application"
            / "knowledge"
            / "application"
            / "MS-EXAMPLE"
            / "API-EXAMPLE-001.md"
        )
        api.parent.mkdir(parents=True)
        api.write_text("# API\n", encoding="utf-8")

        sys_root = repo / "system"
        (sys_root / "knowledge" / "product").mkdir(parents=True)
        (sys_root / "index.md").write_text(
            '---\nokf_version: "0.1"\n---\n', encoding="utf-8"
        )
        concept = sys_root / "knowledge" / "product" / "UC-EXAMPLE.md"
        concept.write_text(
            "---\n"
            "type: Use Case\n"
            "title: 示例用例\n"
            "description: 示例\n"
            "tags: [product, UC]\n"
            'timestamp: "2026-07-18T00:00:00Z"\n'
            "full_id: UC-EXAMPLE\n"
            "perspective: product\n"
            "hierarchy: UC\n"
            "parent_id: null\n"
            "layer_scope: system\n"
            "---\n"
            "## 关系\n\n"
            "- (none)\n\n"
            "## 跨视角\n\n"
            "- map_to_api_id: [API-EXAMPLE-001]"
            "(/knowledge/application/MS-EXAMPLE/API-EXAMPLE-001.md)\n\n"
            "## 详细说明\n\n"
            "- (none)\n\n"
            "## 依据与证据\n\n"
            "示例\n",
            encoding="utf-8",
        )

        validator = validate_bundle.Validator(
            sys_root, "system", repo_root=repo
        )
        code = validator.run()
        assert code == 0
        assert validator.warnings >= 1


def test_validator_http_without_parent_errors() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "system"
        (root / "knowledge" / "business").mkdir(parents=True)
        (root / "index.md").write_text(
            '---\nokf_version: "0.1"\n---\n', encoding="utf-8"
        )
        (root / "knowledge" / "business" / "BD-EXAMPLE.md").write_text(
            FRONTMATTER.replace("layer_scope: application", "layer_scope: system")
            + "## 关系\n\n- (none)\n\n"
            "## 跨视角\n\n- (none)\n\n"
            "## 详细说明\n\n"
            "- 上游：[BD-EXAMPLE](https://github.com/org/ea/blob/main/company/"
            "knowledge/business/BD-EXAMPLE/BD-EXAMPLE.md)\n\n"
            "## 依据与证据\n\n示例\n",
            encoding="utf-8",
        )
        validator = validate_bundle.Validator(root, "system")
        code = validator.run()
        assert code == 1


def test_validator_cross_bundle_missing_still_warns() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        (repo / "application").mkdir()
        sys_root = repo / "system"
        (sys_root / "knowledge" / "product").mkdir(parents=True)
        (sys_root / "index.md").write_text(
            '---\nokf_version: "0.1"\n---\n', encoding="utf-8"
        )
        (sys_root / "knowledge" / "product" / "UC-EXAMPLE.md").write_text(
            "---\n"
            "type: Use Case\n"
            "title: 示例用例\n"
            "description: 示例\n"
            "tags: [product, UC]\n"
            'timestamp: "2026-07-18T00:00:00Z"\n'
            "full_id: UC-EXAMPLE\n"
            "perspective: product\n"
            "hierarchy: UC\n"
            "parent_id: null\n"
            "layer_scope: system\n"
            "---\n"
            "## 关系\n\n- (none)\n\n"
            "## 跨视角\n\n"
            "- map_to_api_id: [API-MISSING]"
            "(/knowledge/application/MS-EXAMPLE/API-MISSING.md)\n\n"
            "## 详细说明\n\n- (none)\n\n"
            "## 依据与证据\n\n示例\n",
            encoding="utf-8",
        )
        validator = validate_bundle.Validator(
            sys_root, "system", repo_root=repo
        )
        code = validator.run()
        assert code == 0
        assert validator.warnings >= 1


def main() -> None:
    tests = [
        test_validator_accepts_legacy_english_h1_sections,
        test_validator_accepts_target_chinese_h2_sections,
        test_validator_rejects_missing_section,
        test_validator_no_downstream_bundle_fallback,
        test_validator_cross_bundle_missing_still_warns,
        test_validator_http_without_parent_errors,
    ]
    for fn in tests:
        fn()
        print(f"PASS {fn.__name__}")
    print(f"\nAll {len(tests)} tests passed.")


if __name__ == "__main__":
    main()
