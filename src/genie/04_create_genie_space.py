# Databricks notebook source
# MAGIC %md
# MAGIC # 04 - Create or Update Genie Space
# MAGIC Recreates the Genie space from the exported `valentina_genie.json` config.
# MAGIC Uses the REST API directly (no MCP required).

# COMMAND ----------

# MAGIC %md
# MAGIC ## Load the Genie config from the repo

# COMMAND ----------

import json
import os
import requests
from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# Resolve config path relative to this notebook's location
notebook_path = dbutils.notebook.entry_point.getDbutils().notebook().getContext().notebookPath().get()
notebook_dir = "/Workspace" + notebook_path.rsplit("/", 1)[0]
config_path = os.path.join(notebook_dir, "valentina_genie.json")

print(f"Loading config from: {config_path}")

with open(config_path, "r") as f:
    genie_config = json.load(f)

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
