#!/usr/bin/env python3
"""跨层 HTTP / knowledge-parent.yaml 单元测试。"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "agent" / "skills" / "docs-okf" / "scripts"))
import okf_cross_layer as x  # noqa: E402


def test_https_repo_home_ssh_and_https() -> None:
    assert (
        x.https_repo_home("git@github.com:org/ea.git")
        == "https://github.com/org/ea"
    )
    assert (
        x.https_repo_home("https://github.com/org/ea.git")
        == "https://github.com/org/ea"
    )


def test_parent_web_base_github() -> None:
    p = x.Parent(
        knowledge_type="company",
        repository="git@github.com:org/ea.git",
        path="~/ws/ea",
        doc_dir="company",
        ref="main",
    )
    assert (
        x.parent_web_base(p)
        == "https://github.com/org/ea/blob/main/company"
    )


def test_unknown_host_no_web_base() -> None:
    p = x.Parent(
        knowledge_type="company",
        repository="https://example.com/org/ea.git",
        path="~/ws/ea",
        doc_dir="docs",
        ref="main",
    )
    assert x.parent_web_base(p) is None


def test_href_and_validate(tmp_path: Path) -> None:
    company = tmp_path / "ea"
    cdoc = company / "company"
    bd = cdoc / "knowledge" / "business" / "BD-EXAMPLE"
    bd.mkdir(parents=True)
    (bd / "BD-EXAMPLE.md").write_text("# bd\n", encoding="utf-8")
    sys_root = tmp_path / "sys" / "system"
    sys_root.mkdir(parents=True)
    x.write_parent(
        sys_root,
        x.Parent(
            knowledge_type="company",
            repository="https://github.com/org/ea.git",
            path=str(company),
            doc_dir="company",
            ref="main",
        ),
    )
    href = x.cross_layer_href(sys_root, "BD-EXAMPLE")
    assert href == (
        "https://github.com/org/ea/blob/main/company/"
        "knowledge/business/BD-EXAMPLE/BD-EXAMPLE.md"
    )
    assert x.validate_http_href(sys_root, href) is None


def test_http_without_parent_errors(tmp_path: Path) -> None:
    doc = tmp_path / "system"
    doc.mkdir(parents=True)
    err = x.validate_http_href(
        doc,
        "https://github.com/org/ea/blob/main/company/knowledge/business/BD-X/BD-X.md",
    )
    assert err and "缺少 knowledge-parent.yaml" in err


def test_rewrite_to_id() -> None:
    text = (
        "见 [BD-EXAMPLE](https://github.com/org/ea/blob/main/company/"
        "knowledge/business/BD-EXAMPLE/BD-EXAMPLE.md) 与本地。"
    )
    old = "https://github.com/org/ea/blob/main/company"
    new_text, n = x._rewrite_text(text, old, None)
    assert n == 1
    assert "BD-EXAMPLE" in new_text
    assert "https://" not in new_text


def main() -> None:
    test_https_repo_home_ssh_and_https()
    print("PASS test_https_repo_home_ssh_and_https")
    test_parent_web_base_github()
    print("PASS test_parent_web_base_github")
    test_unknown_host_no_web_base()
    print("PASS test_unknown_host_no_web_base")
    test_rewrite_to_id()
    print("PASS test_rewrite_to_id")
    with tempfile.TemporaryDirectory() as tmp:
        test_href_and_validate(Path(tmp))
        print("PASS test_href_and_validate")
        test_http_without_parent_errors(Path(tmp))
        print("PASS test_http_without_parent_errors")
    print("\nAll cross-layer tests passed.")


if __name__ == "__main__":
    main()
