#!/usr/bin/env python3
"""OKF 共享库单元测试。"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "agent" / "skills" / "docs-okf" / "scripts"))
import okf_lib  # noqa: E402


def test_parse_frontmatter():
    text = "---\ntype: Business Domain\nfull_id: BD-EXAMPLE\n---\n# Body\n"
    meta, body = okf_lib.parse_frontmatter(text)
    assert meta["type"] == "Business Domain"
    assert meta["full_id"] == "BD-EXAMPLE"
    assert body.strip() == "# Body"


def test_hierarchy_to_type():
    assert okf_lib.hierarchy_to_type("BD") == "Business Domain"
    assert okf_lib.hierarchy_to_type("API") == "API Endpoint"


def test_entity_relpath_business_bd():
    path = okf_lib.entity_relpath("business", "BD-EXAMPLE")
    assert path == "knowledge/business/BD-EXAMPLE.md"


def test_entity_relpath_application_sys():
    path = okf_lib.entity_relpath("application", "SYS-EXAMPLE")
    assert path == "knowledge/application/SYS-EXAMPLE.md"


def test_entity_relpath_application_api():
    path = okf_lib.entity_relpath("application", "API-EXAMPLE-001")
    assert path == "knowledge/application/MS-EXAMPLE/API-EXAMPLE-001.md"


def test_parse_frontmatter_list():
    text = "---\ntags: [business, BD]\n---\n"
    meta, body = okf_lib.parse_frontmatter(text)
    assert meta["tags"] == ["business", "BD"]
    assert body == ""


def test_parse_frontmatter_null():
    text = "---\nparent_id: null\ntitle: Example\n---\n"
    meta, body = okf_lib.parse_frontmatter(text)
    assert meta["parent_id"] is None
    assert meta["title"] == "Example"
    assert body == ""


def test_entity_relpath_ent_with_parent():
    path = okf_lib.entity_relpath("data", "ENT-T_BILLING", parent_id="DS-BILLING")
    assert path == "knowledge/data/ENT-EXAMPLE/ENT-T_BILLING.md"


def test_bundle_link():
    link = okf_lib.to_bundle_link("knowledge/application/APP-EXAMPLE.md")
    assert link == "/knowledge/application/APP-EXAMPLE.md"


def test_format_frontmatter_roundtrip():
    meta = {
        "type": "Feature",
        "tags": ["product", "FT"],
        "parent_id": None,
    }
    block = okf_lib.format_frontmatter(meta)
    parsed, _ = okf_lib.parse_frontmatter(block)
    assert parsed["type"] == "Feature"
    assert parsed["tags"] == ["product", "FT"]
    assert parsed["parent_id"] is None


def test_scan_concepts():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "index.md").write_text("# index\n", encoding="utf-8")
        (root / "log.md").write_text("# log\n", encoding="utf-8")
        concept = root / "knowledge" / "business" / "BD-EXAMPLE.md"
        concept.parent.mkdir(parents=True)
        concept.write_text("# concept\n", encoding="utf-8")
        found = list(okf_lib.scan_concepts(root))
        assert len(found) == 1
        assert found[0].name == "BD-EXAMPLE.md"


def test_is_concept_file():
    assert okf_lib.is_concept_file(Path("knowledge/business/BD-EXAMPLE.md"))
    assert not okf_lib.is_concept_file(Path("knowledge/business/index.md"))
    assert not okf_lib.is_concept_file(Path("manifest.yaml"))


def test_hierarchy_to_type_cap():
    assert okf_lib.hierarchy_to_type("CAP") == "Business Capability"


def test_entity_relpath_company_bd_in_domain_folder():
    path = okf_lib.entity_relpath("business", "BD-EXAMPLE", bundle="company")
    assert path == "knowledge/business/BD-EXAMPLE/BD-EXAMPLE.md"


def test_entity_relpath_company_bd_uses_full_id():
    path = okf_lib.entity_relpath("business", "BD-CHARGING", bundle="company")
    assert path == "knowledge/business/BD-CHARGING/BD-CHARGING.md"


def test_entity_relpath_company_cap_with_parent():
    path = okf_lib.entity_relpath(
        "business", "CAP-ORDER", parent_id="BD-CHARGING", bundle="company"
    )
    assert path == "knowledge/business/BD-CHARGING/CAP-ORDER.md"


def test_entity_relpath_company_cap():
    path = okf_lib.entity_relpath("business", "CAP-EXAMPLE", bundle="company")
    assert path == "knowledge/business/BD-EXAMPLE/CAP-EXAMPLE.md"


def test_entity_relpath_company_tpl():
    path = okf_lib.entity_relpath("technical", "TPL-EXAMPLE", bundle="company")
    assert path == "knowledge/technical/TPL-EXAMPLE.md"


def test_entity_relpath_system_ms_and_mw():
    assert (
        okf_lib.entity_relpath(
            "application", "MS-EXAMPLE", parent_id="APP-EXAMPLE", bundle="system"
        )
        == "knowledge/application/APP-EXAMPLE/MS-EXAMPLE/MS-EXAMPLE.md"
    )
    assert (
        okf_lib.entity_relpath("application", "APP-EXAMPLE", bundle="system")
        == "knowledge/application/APP-EXAMPLE/APP-EXAMPLE.md"
    )
    assert (
        okf_lib.entity_relpath("technical", "MW-EXAMPLE", bundle="system")
        == "knowledge/technical/MW-EXAMPLE/MW-EXAMPLE.md"
    )
    assert okf_lib.hierarchy_to_type("FR") == "Functional Requirement"


def test_entity_relpath_system_ms_requires_parent():
    try:
        okf_lib.entity_relpath("application", "MS-EXAMPLE", bundle="system")
    except ValueError as exc:
        assert "parent_id" in str(exc)
        return
    raise AssertionError("expected ValueError when system MS parent_id missing")


def test_entity_relpath_system_bd_at_perspective_root():
    path = okf_lib.entity_relpath("business", "BD-EXAMPLE", bundle="system")
    assert path == "knowledge/business/BD-EXAMPLE.md"


def main() -> None:
    tests = [
        test_parse_frontmatter,
        test_hierarchy_to_type,
        test_entity_relpath_business_bd,
        test_entity_relpath_application_sys,
        test_entity_relpath_application_api,
        test_bundle_link,
        test_parse_frontmatter_list,
        test_parse_frontmatter_null,
        test_entity_relpath_ent_with_parent,
        test_format_frontmatter_roundtrip,
        test_scan_concepts,
        test_is_concept_file,
        test_hierarchy_to_type_cap,
        test_entity_relpath_company_bd_in_domain_folder,
        test_entity_relpath_company_bd_uses_full_id,
        test_entity_relpath_company_cap,
        test_entity_relpath_company_cap_with_parent,
        test_entity_relpath_company_tpl,
        test_entity_relpath_system_ms_and_mw,
        test_entity_relpath_system_ms_requires_parent,
        test_entity_relpath_system_bd_at_perspective_root,
    ]
    for fn in tests:
        fn()
        print(f"PASS {fn.__name__}")
    print(f"\nAll {len(tests)} tests passed.")


if __name__ == "__main__":
    main()
