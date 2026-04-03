# Databricks notebook source
# MAGIC %md
# MAGIC # 04 - Create or Update Genie Space
# MAGIC Recreates the Genie space from the exported `valentina_genie.json` config.
# MAGIC Uses the REST API directly (no MCP required).

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parameters

# COMMAND ----------

dbutils.widgets.text("catalog", "medtech", "Catalog")
dbutils.widgets.text("schema", "sales", "Schema")
dbutils.widgets.text("warehouse_id", "", "Warehouse ID")
dbutils.widgets.text("genie_space_id", "", "Genie Space ID")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
warehouse_id = dbutils.widgets.get("warehouse_id")
genie_space_id = dbutils.widgets.get("genie_space_id")

print(f"Catalog: {catalog}, Schema: {schema}")
print(f"Warehouse: {warehouse_id}, Genie Space: {genie_space_id}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Load the Genie config from the repo

# COMMAND ----------

import json
import os
import re
import requests
from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# Resolve config path relative to this notebook's location
notebook_path = dbutils.notebook.entry_point.getDbutils().notebook().getContext().notebookPath().get()
notebook_dir = "/Workspace" + notebook_path.rsplit("/", 1)[0]
config_path = os.path.join(notebook_dir, "valentina_genie.json")

print(f"Loading config from: {config_path}")

with open(config_path, "r") as f:
    raw_config = f.read()

# Replace placeholder catalog.schema references with actual values
# Handles both __CATALOG__.__SCHEMA__ placeholders and any prior values
raw_config = re.sub(r'__CATALOG__\.__SCHEMA__', f'{catalog}.{schema}', raw_config)
raw_config = raw_config.replace('__WAREHOUSE_ID__', warehouse_id)
raw_config = raw_config.replace('__GENIE_SPACE_ID__', genie_space_id)

genie_config = json.loads(raw_config)

# Override from widget params
genie_config["space_id"] = genie_space_id
genie_config["warehouse_id"] = warehouse_id

print(f"Genie Space: {genie_config['display_name']}")
print(f"Tables: {len(genie_config['table_identifiers'])}")
print(f"Sample Questions: {len(genie_config['sample_questions'])}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create or Update the Genie Space
# MAGIC
# MAGIC The REST API uses these endpoints:
# MAGIC - **Create (import)**: `POST /api/2.0/genie/spaces`
# MAGIC - **Update**: `PATCH /api/2.0/genie/spaces/{space_id}`
# MAGIC
# MAGIC Both accept a `serialized_space` field (JSON string) that contains the full
# MAGIC space configuration: tables, metric views, instructions, SQL examples, and benchmarks.

# COMMAND ----------

host = w.config.host.rstrip("/")
headers = w.config.authenticate()
headers["Content-Type"] = "application/json"

space_id = genie_config.get("space_id")
serialized_space = json.dumps(genie_config["serialized_space"])

# Try to update existing space first, create if it doesn't exist
if space_id:
    print(f"Attempting to update existing space: {space_id}")
    resp = requests.patch(
        f"{host}/api/2.0/genie/spaces/{space_id}",
        headers=headers,
        json={
            "warehouse_id": warehouse_id,
            "serialized_space": serialized_space,
            "title": genie_config["display_name"],
            "description": genie_config["description"],
        },
    )

    if resp.status_code == 200:
        print(f"Updated space: {space_id}")
    elif resp.status_code == 404:
        print(f"Space {space_id} not found, creating new one...")
        space_id = None
    else:
        print(f"Update failed ({resp.status_code}): {resp.text[:300]}")
        space_id = None

if not space_id:
    print("Creating new Genie space...")
    resp = requests.post(
        f"{host}/api/2.0/genie/spaces",
        headers=headers,
        json={
            "warehouse_id": genie_config["warehouse_id"],
            "serialized_space": serialized_space,
            "title": genie_config["display_name"],
            "description": genie_config["description"],
        },
    )

    if resp.status_code == 200:
        new_space = resp.json()
        new_id = new_space.get("space_id") or new_space.get("id")
        print(f"Created new space: {new_id}")
        print(f"NOTE: Update GENIE_SPACE_ID in app.yaml and app.py to: {new_id}")
    else:
        raise Exception(f"Failed to create space ({resp.status_code}): {resp.text[:500]}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verify the Space

# COMMAND ----------

verify_id = space_id or new_id
resp = requests.get(
    f"{host}/api/2.0/genie/spaces/{verify_id}",
    headers=headers,
    params={"include_serialized_space": "true"},
)
data = resp.json()

ss = json.loads(data.get("serialized_space", "{}"))
instructions = ss.get("instructions", {})
benchmarks = ss.get("benchmarks", {})

print(f"Space ID:        {data.get('space_id')}")
print(f"Display Name:    {data.get('display_name')}")
print(f"Warehouse:       {data.get('warehouse_id')}")
print(f"Tables:          {len(data.get('table_identifiers', []))}")
print(f"Sample Qs:       {len(data.get('sample_questions', []))}")
print(f"Text Instructions: {len(instructions.get('text_instructions', []))} entries")
print(f"SQL Examples:    {len(instructions.get('example_question_sqls', []))} entries")
print(f"Benchmarks:      {len(benchmarks.get('questions', []))} entries")
