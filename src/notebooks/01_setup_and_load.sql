-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 01 - Setup and Load Raw Data
-- MAGIC Load 3 CSV files from the volume into Delta tables in `medtech.sales`.

-- COMMAND ----------

USE CATALOG medtech;
USE SCHEMA sales;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load HCP Procedure Volume (150 rows)

-- COMMAND ----------

CREATE OR REPLACE TABLE medtech.sales.hcp_procedure_volume AS
SELECT
  `NPI` AS npi,
  `Surgeon Name` AS surgeon_name,
  `Rep ID` AS rep_id,
  `Account` AS account,
  `Specialty` AS specialty,
  `Area` AS area,
  CAST(`CY Procedure Volume` AS INT) AS cy_procedure_volume,
  CAST(`PY Procedure Volume` AS INT) AS py_procedure_volume,
  CAST(`CY vs PY Procedure Volume` AS INT) AS cy_vs_py_procedure_volume,
  CAST(`CY Alpha Max Market` AS DOUBLE) AS cy_alpha_max_market,
  CAST(`CY Beta Max Market` AS DOUBLE) AS cy_beta_max_market,
  CAST(`CY Gamma Max Market` AS DOUBLE) AS cy_gamma_max_market,
  CAST(`CY Delta Max Market` AS DOUBLE) AS cy_delta_max_market,
  CAST(`Total CY Max Market` AS DOUBLE) AS total_cy_max_market,
  CAST(`PY Alpha Max Market` AS DOUBLE) AS py_alpha_max_market,
  CAST(`PY Beta Max Market` AS DOUBLE) AS py_beta_max_market,
  CAST(`PY Gamma Max Market` AS DOUBLE) AS py_gamma_max_market,
  CAST(`PY Delta Max Market` AS DOUBLE) AS py_delta_max_market,
  CAST(`Total PY Max Market` AS DOUBLE) AS total_py_max_market
FROM read_files(
  '/Volumes/medtech/sales/raw_data/hcp_procedure_volume.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load Product Upgrades (400 rows)

-- COMMAND ----------

CREATE OR REPLACE TABLE medtech.sales.product_upgrades AS
SELECT
  CAST(`Row Number` AS INT) AS row_number,
  `Area` AS area,
  `Region` AS region,
  `Territory` AS territory,
  `IDN` AS idn,
  `Rep ID` AS rep_id,
  `Account` AS account,
  `Product Line` AS product_line,
  `Product Category` AS product_category,
  `Product Description` AS product_description,
  `Comped Status` AS comped_status,
  `Segment` AS segment,
  CAST(`# of Upgrade Codes` AS INT) AS num_upgrade_codes,
  CAST(`# of Codes on Account Shelf` AS INT) AS num_codes_on_account_shelf,
  CAST(`# of Codes in IDN System` AS INT) AS num_codes_in_idn_system,
  CAST(`# of Codes in Neither` AS INT) AS num_codes_in_neither,
  `Discontinuation Date` AS discontinuation_date,
  CAST(`CY Opportunity ($)` AS DOUBLE) AS cy_opportunity,
  CAST(`PY Opportunity ($)` AS DOUBLE) AS py_opportunity,
  CAST(`Net Cost To Customer ($)` AS DOUBLE) AS net_cost_to_customer,
  CAST(`Rolling 12 Sales ($)` AS DOUBLE) AS rolling_12_sales
FROM read_files(
  '/Volumes/medtech/sales/raw_data/product_upgrades.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load Account Targeting (300 rows)

-- COMMAND ----------

CREATE OR REPLACE TABLE medtech.sales.account_targeting AS
SELECT
  CAST(`Row Number` AS INT) AS row_number,
  `Area` AS area,
  `Region` AS region,
  `Territory` AS territory,
  `Rep ID` AS rep_id,
  `IDN` AS idn,
  `Account` AS account,
  `Clinical Focus Area` AS clinical_focus_area,
  `Target Type` AS target_type,
  `Product Line` AS product_line,
  `Category` AS category,
  `GPO` AS gpo,
  CAST(`Total Units Sold` AS INT) AS total_units_sold,
  CAST(`Opportunity ($)` AS DOUBLE) AS opportunity,
  CAST(`Net Cost To Customer ($)` AS DOUBLE) AS net_cost_to_customer,
  CAST(`Rolling 12 Sales ($)` AS DOUBLE) AS rolling_12_sales,
  CAST(`# Codes on Account Shelf` AS INT) AS num_codes_on_account_shelf,
  CAST(`# Codes in System` AS INT) AS num_codes_in_system,
  CAST(`# Codes in Neither` AS INT) AS num_codes_in_neither,
  CAST(`2025 Penetration %` AS DOUBLE) AS penetration_2025,
  CAST(`2024 Penetration %` AS DOUBLE) AS penetration_2024,
  CAST(`2023 Penetration %` AS DOUBLE) AS penetration_2023,
  CAST(`3 Month Trend` AS DOUBLE) AS trend_3_month,
  CAST(`6 Month Trend` AS DOUBLE) AS trend_6_month,
  CAST(`9 Month Trend` AS DOUBLE) AS trend_9_month,
  CAST(`CY Market Exposure %` AS DOUBLE) AS cy_market_exposure,
  CAST(`PY Market Exposure %` AS DOUBLE) AS py_market_exposure
FROM read_files(
  '/Volumes/medtech/sales/raw_data/account_targeting.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Verify row counts

-- COMMAND ----------

SELECT 'hcp_procedure_volume' AS table_name, COUNT(*) AS row_count FROM medtech.sales.hcp_procedure_volume
UNION ALL
SELECT 'product_upgrades', COUNT(*) FROM medtech.sales.product_upgrades
UNION ALL
SELECT 'account_targeting', COUNT(*) FROM medtech.sales.account_targeting;
