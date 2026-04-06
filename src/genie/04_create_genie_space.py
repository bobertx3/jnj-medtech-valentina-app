# Databricks notebook source
# MAGIC %md
# MAGIC # 04 - Create or Update Genie Space
# MAGIC Recreates the Genie space from the exported `genie_space.json` config,
# MAGIC then grants the app's service principal CAN_MANAGE permission on the space.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parameters

# COMMAND ----------

dbutils.widgets.text("catalog", "medtech", "Catalog")
dbutils.widgets.text("schema", "sales", "Schema")
dbutils.widgets.text("warehouse_id", "", "Warehouse ID")
dbutils.widgets.text("genie_space_id", "", "Genie Space ID")
dbutils.widgets.text("app_name", "", "Databricks App Name")
dbutils.widgets.text("dataset", "med_tech_sales", "Dataset")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
warehouse_id = dbutils.widgets.get("warehouse_id")
genie_space_id = dbutils.widgets.get("genie_space_id")
app_name = dbutils.widgets.get("app_name")
dataset = dbutils.widgets.get("dataset")

print(f"Catalog: {catalog}, Schema: {schema}, Dataset: {dataset}")
print(f"Warehouse: {warehouse_id}, Genie Space: {genie_space_id}")
print(f"App Name: {app_name}")

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
config_path = os.path.join(notebook_dir, dataset, "genie_space.json")

print(f"Loading config from: {config_path}")

with open(config_path, "r") as f:
    raw_config = f.read()

# Replace placeholder catalog.schema references with actual values
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
    else:
        raise Exception(f"Failed to create space ({resp.status_code}): {resp.text[:500]}")

final_space_id = space_id or new_id

# COMMAND ----------

# MAGIC %md
# MAGIC ## Grant App Service Principal access to the Genie Space
# MAGIC
# MAGIC The Databricks App has its own service principal. We need to grant it
# MAGIC CAN_MANAGE on the Genie space so the app can call the Genie API.

# COMMAND ----------

if app_name:
    # Look up the app to find its service principal
    print(f"Looking up app: {app_name}")
    app_resp = requests.get(
        f"{host}/api/2.0/apps/{app_name}",
        headers=headers,
    )

    if app_resp.status_code == 200:
        app_data = app_resp.json()
        sp_id = app_data.get("service_principal_id")
        sp_name = app_data.get("service_principal_name", "")
        print(f"App service principal ID: {sp_id}, name: {sp_name}")

        sp_client_id = app_data.get("service_principal_client_id", "")
        if sp_client_id:
            # Grant CAN_MANAGE on the Genie space
            # Permission object type is "genie", use service_principal_name = client_id
            print(f"Granting CAN_MANAGE on Genie space {final_space_id} to SP '{sp_name}' (client_id: {sp_client_id})...")
            perm_resp = requests.patch(
                f"{host}/api/2.0/permissions/genie/{final_space_id}",
                headers=headers,
                json={
                    "access_control_list": [
                        {
                            "service_principal_name": sp_client_id,
                            "permission_level": "CAN_MANAGE",
                        }
                    ]
                },
            )

            if perm_resp.status_code == 200:
                print("Genie space permission granted!")
            else:
                print(f"Genie permission failed ({perm_resp.status_code}): {perm_resp.text[:300]}")

            # Also grant CAN_USE on the SQL warehouse
            print(f"Granting CAN_USE on warehouse {warehouse_id} to SP '{sp_name}'...")
            wh_perm_resp = requests.patch(
                f"{host}/api/2.0/permissions/warehouses/{warehouse_id}",
                headers=headers,
                json={
                    "access_control_list": [
                        {
                            "service_principal_name": sp_client_id,
                            "permission_level": "CAN_USE",
                        }
                    ]
                },
            )

            if wh_perm_resp.status_code == 200:
                print("Warehouse permission granted!")
            else:
                print(f"Warehouse permission failed ({wh_perm_resp.status_code}): {wh_perm_resp.text[:300]}")

            # Grant Unity Catalog access so the SP can query tables
            print(f"Granting Unity Catalog access to SP '{sp_client_id}'...")
            uc_grants = [
                f"GRANT USE_CATALOG ON CATALOG {catalog} TO `{sp_client_id}`",
                f"GRANT USE_SCHEMA ON SCHEMA {catalog}.{schema} TO `{sp_client_id}`",
                f"GRANT SELECT ON SCHEMA {catalog}.{schema} TO `{sp_client_id}`",
            ]
            for grant_sql in uc_grants:
                try:
                    spark.sql(grant_sql)
                    print(f"  OK: {grant_sql}")
                except Exception as e:
                    print(f"  WARN: {grant_sql} -> {e}")
        else:
            print("WARNING: Could not find service principal client ID for app")
    else:
        print(f"WARNING: Could not find app '{app_name}' ({app_resp.status_code}). "
              f"Make sure 'databricks bundle deploy' was run first.")
else:
    print("WARNING: No app_name provided — skipping permission grant.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verify the Space

# COMMAND ----------

resp = requests.get(
    f"{host}/api/2.0/genie/spaces/{final_space_id}",
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
