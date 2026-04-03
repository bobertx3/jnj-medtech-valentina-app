# Databricks notebook source
# MAGIC %md
# MAGIC # 00 - Setup Volume
# MAGIC Creates the schema and volume (catalog must already exist), then copies raw CSV
# MAGIC files from the deployed repo into the Unity Catalog volume so downstream notebooks can read them.

# COMMAND ----------

import os
import shutil

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parameters

# COMMAND ----------

dbutils.widgets.text("catalog", "medtech", "Catalog")
dbutils.widgets.text("schema", "sales", "Schema")
dbutils.widgets.text("volume_name", "raw_data", "Volume Name")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
volume_name = dbutils.widgets.get("volume_name")

print(f"Catalog: {catalog}, Schema: {schema}, Volume: {volume_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create schema and volume (catalog must already exist)

# COMMAND ----------

spark.sql(f"USE CATALOG {catalog}")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {schema}")
spark.sql(f"USE SCHEMA {schema}")
spark.sql(f"CREATE VOLUME IF NOT EXISTS {volume_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Copy CSVs from repo to volume

# COMMAND ----------

# Resolve the raw_data directory relative to this notebook
notebook_path = dbutils.notebook.entry_point.getDbutils().notebook().getContext().notebookPath().get()
notebook_dir = "/Workspace" + notebook_path.rsplit("/", 1)[0]
raw_data_dir = os.path.join(notebook_dir, "..", "..", "raw_data")
raw_data_dir = os.path.normpath(raw_data_dir)

volume_path = f"/Volumes/{catalog}/{schema}/{volume_name}"

csv_files = ["hcp_procedure_volume.csv", "product_upgrades.csv", "account_targeting.csv"]

for csv_file in csv_files:
    src = os.path.join(raw_data_dir, csv_file)
    dst = os.path.join(volume_path, csv_file)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"Copied: {csv_file} -> {dst}")
    else:
        print(f"WARNING: {src} not found")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verify files in volume

# COMMAND ----------

files = dbutils.fs.ls(f"dbfs:{volume_path}")
for f in files:
    print(f"{f.name:40s} {f.size:>10,} bytes")
