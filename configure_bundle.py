#!/usr/bin/env python3
"""
Render bundle YAML and app files from templates/ — same file outputs as install.sh
(without databricks auth login or bundle deploy).

Run from the repository root:
  python configure_bundle.py --help

Import from a notebook:
  from configure_bundle import build_mapping, render_bundle
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path
from typing import Iterable

# Placeholders must match templates/ and install.sh
PLACEHOLDER_KEYS = (
    "__PROFILE__",
    "__WORKSPACE_URL__",
    "__CATALOG__",
    "__SCHEMA__",
    "__WAREHOUSE_ID__",
    "__VOLUME_NAME__",
    "__GENIE_SPACE_ID__",
    "__APP_NAME__",
    "__DATASET__",
)

_APP_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$")


def render_content(content: str, mapping: dict[str, str]) -> str:
    for key in PLACEHOLDER_KEYS:
        if key in content:
            content = content.replace(key, mapping[key])
    return content


def template_pairs(dataset: str) -> list[tuple[str, str]]:
    return [
        ("templates/databricks.yml", "databricks.yml"),
        ("templates/genie_app.yml", "resources/genie_app.yml"),
        ("templates/pipeline_job.yml", "resources/pipeline_job.yml"),
        (f"templates/{dataset}/app.py", f"src/app/{dataset}/app.py"),
        (f"templates/{dataset}/app.yaml", f"src/app/{dataset}/app.yaml"),
        ("templates/CLAUDE.md", "CLAUDE.md"),
        ("templates/README.md", "README.md"),
    ]


def write_config_json(repo_root: Path, mapping: dict[str, str]) -> None:
    config = {
        "profile": mapping["__PROFILE__"],
        "workspace_url": mapping["__WORKSPACE_URL__"],
        "catalog": mapping["__CATALOG__"],
        "schema": mapping["__SCHEMA__"],
        "warehouse_id": mapping["__WAREHOUSE_ID__"],
        "volume_name": mapping["__VOLUME_NAME__"],
        "genie_space_id": mapping["__GENIE_SPACE_ID__"],
        "app_name": mapping["__APP_NAME__"],
        "dataset": mapping["__DATASET__"],
    }
    (repo_root / "config.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def clear_bundle_cache(repo_root: Path) -> None:
    databricks_dir = repo_root / ".databricks"
    resources_json = repo_root / ".databricks-resources.json"
    if databricks_dir.is_dir():
        shutil.rmtree(databricks_dir, ignore_errors=True)
    if resources_json.is_file():
        resources_json.unlink(missing_ok=True)


def render_bundle(repo_root: Path, mapping: dict[str, str]) -> list[str]:
    """Write templated files and config.json. Returns log lines."""
    repo_root = repo_root.resolve()
    dataset = mapping["__DATASET__"]
    (repo_root / "src" / "app" / dataset).mkdir(parents=True, exist_ok=True)
    (repo_root / "resources").mkdir(parents=True, exist_ok=True)

    log: list[str] = []
    for src_rel, dst_rel in template_pairs(dataset):
        src = repo_root / src_rel
        dst = repo_root / dst_rel
        if not src.is_file():
            log.append(f"WARNING: Template not found: {src_rel}")
            continue
        text = src.read_text(encoding="utf-8")
        dst.write_text(render_content(text, mapping), encoding="utf-8")
        log.append(f"{src_rel} -> {dst_rel}")

    write_config_json(repo_root, mapping)
    clear_bundle_cache(repo_root)
    log.append("Wrote config.json")
    log.append("Cleared .databricks cache (if present)")
    return log


def build_mapping(
    profile: str,
    workspace_url: str,
    catalog: str,
    schema: str,
    warehouse_id: str,
    volume_name: str,
    genie_space_id: str,
    app_name: str,
    dataset: str,
) -> dict[str, str]:
    workspace_url = workspace_url.rstrip("/")
    return {
        "__PROFILE__": profile,
        "__WORKSPACE_URL__": workspace_url,
        "__CATALOG__": catalog,
        "__SCHEMA__": schema,
        "__WAREHOUSE_ID__": warehouse_id,
        "__VOLUME_NAME__": volume_name,
        "__GENIE_SPACE_ID__": genie_space_id,
        "__APP_NAME__": app_name,
        "__DATASET__": dataset,
    }


def _validate_app_name(name: str) -> None:
    if not _APP_NAME_RE.match(name):
        raise SystemExit(
            "Invalid app_name: use lowercase letters, numbers, hyphens only; "
            "must start and end with a letter or number."
        )


def main(argv: Iterable[str] | None = None) -> None:
    p = argparse.ArgumentParser(
        description="Generate databricks.yml, resources/*.yml, and app files from templates/."
    )
    p.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root (contains templates/ and databricks.yml output path)",
    )
    p.add_argument("--profile", required=True, help="Databricks CLI profile name")
    p.add_argument("--workspace-url", required=True, help="Workspace URL (https://...)")
    p.add_argument("--catalog", required=True)
    p.add_argument("--schema", required=True)
    p.add_argument("--warehouse-id", required=True)
    p.add_argument("--volume-name", required=True)
    p.add_argument("--genie-space-id", required=True)
    p.add_argument("--app-name", required=True)
    p.add_argument("--dataset", default="med_tech_sales", choices=("med_tech_sales", "hr_recruiting"))

    args = p.parse_args(list(argv) if argv is not None else None)
    _validate_app_name(args.app_name)

    mapping = build_mapping(
        profile=args.profile,
        workspace_url=args.workspace_url,
        catalog=args.catalog,
        schema=args.schema,
        warehouse_id=args.warehouse_id,
        volume_name=args.volume_name,
        genie_space_id=args.genie_space_id,
        app_name=args.app_name,
        dataset=args.dataset,
    )

    for line in render_bundle(args.repo_root, mapping):
        print(line)
    print("Done.")


if __name__ == "__main__":
    main()
