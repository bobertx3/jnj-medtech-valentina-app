# Databricks notebook source
# MAGIC %md
# MAGIC # Configure bundle files (widget-based `install.sh`)
# MAGIC
# MAGIC This notebook writes **`databricks.yml`**, **`resources/*.yml`**, **`src/app/<dataset>/*`**, and **`config.json`** from **`templates/`** — the same outputs as **`install.sh`**, without running **`databricks auth login`** or **`databricks bundle deploy`**.
# MAGIC
# MAGIC **Where to run:** From a **full clone** of this repo (for example **Databricks Repos**). Do **not** run this if your workspace folder only contains a few files (no `templates/`); the renders will fail or be incomplete.
# MAGIC
# MAGIC After this succeeds, use the **Bundle** tab on the repo folder (or `databricks bundle deploy` from a terminal) to deploy.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parameters

# COMMAND ----------

dbutils.widgets.text("profile", "DEFAULT", "CLI profile name (must match databricks configure)")
dbutils.widgets.text("workspace_url", "", "Workspace URL (https://...)")
dbutils.widgets.text("catalog", "medtech", "Catalog (must exist)")
dbutils.widgets.text("schema", "sales", "Schema (created if needed)")
dbutils.widgets.text("warehouse_id", "", "SQL Warehouse ID")
dbutils.widgets.text("volume_name", "raw_data", "Volume name for CSV data")
dbutils.widgets.text("genie_space_id", "", "Empty Genie space ID from URL")
dbutils.widgets.text("app_name", "medtech-sales-genie", "App name (lowercase, hyphens, no underscores)")
dbutils.widgets.dropdown("dataset", "med_tech_sales", ["med_tech_sales", "hr_recruiting"], "Dataset")

# COMMAND ----------

import os
import re
import sys

# Repo root: this notebook lives in src/notebooks/
notebook_path = dbutils.notebook.entry_point.getDbutils().notebook().getContext().notebookPath().get()
notebook_dir = "/Workspace" + notebook_path.rsplit("/", 1)[0]
REPO_ROOT = os.path.normpath(os.path.join(notebook_dir, "..", ".."))
sys.path.insert(0, REPO_ROOT)

from configure_bundle import build_mapping, render_bundle

profile = dbutils.widgets.get("profile").strip()
workspace_url = dbutils.widgets.get("workspace_url").strip()
catalog = dbutils.widgets.get("catalog").strip()
schema = dbutils.widgets.get("schema").strip()
warehouse_id = dbutils.widgets.get("warehouse_id").strip()
volume_name = dbutils.widgets.get("volume_name").strip()
genie_space_id = dbutils.widgets.get("genie_space_id").strip()
app_name = dbutils.widgets.get("app_name").strip()
dataset = dbutils.widgets.get("dataset").strip()

for label, val in [
    ("Workspace URL", workspace_url),
    ("Warehouse ID", warehouse_id),
    ("Genie Space ID", genie_space_id),
]:
    if not val:
        raise ValueError(f"{label} is required.")

if not re.match(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$", app_name):
    raise ValueError(
        "Invalid app_name: lowercase letters, numbers, hyphens only; "
        "must start and end with a letter or number."
    )

print(f"REPO_ROOT = {REPO_ROOT}")
if not os.path.isdir(os.path.join(REPO_ROOT, "templates")):
    raise FileNotFoundError(
        f"No templates/ under {REPO_ROOT}. Import the full repo (zip with templates/, src/, raw_data/, resources/)."
    )

mapping = build_mapping(
    profile=profile,
    workspace_url=workspace_url,
    catalog=catalog,
    schema=schema,
    warehouse_id=warehouse_id,
    volume_name=volume_name,
    genie_space_id=genie_space_id,
    app_name=app_name,
    dataset=dataset,
)

for line in render_bundle(REPO_ROOT, mapping):
    print(line)

print("\nNext: open the parent folder in Workspace and use the Bundle tab → Deploy, or run: databricks bundle deploy --auto-approve")
