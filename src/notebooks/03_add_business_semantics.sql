-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 - Add Business Semantics
-- MAGIC Define 7 governed metric views for KPIs across HCP volumes, product upgrades, and account targeting.

-- COMMAND ----------

USE CATALOG ${catalog};
USE SCHEMA ${schema};

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Total Procedure Volume

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.total_procedure_volume
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Total current year procedure volume by HCP, specialty, area, and rep"
source: ${catalog}.${schema}.hcp_procedure_volume
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Specialty
    expr: specialty
    comment: "Medical specialty"
  - name: Rep ID
    expr: rep_id
    comment: "Sales representative ID"
  - name: Account
    expr: account
    comment: "Hospital account"
  - name: Surgeon Name
    expr: surgeon_name
    comment: "HCP surgeon name"
measures:
  - name: Total CY Procedure Volume
    expr: SUM(cy_procedure_volume)
    comment: "Sum of current year procedure volume"
  - name: Total PY Procedure Volume
    expr: SUM(py_procedure_volume)
    comment: "Sum of prior year procedure volume"
  - name: HCP Count
    expr: COUNT(DISTINCT npi)
    comment: "Number of unique healthcare providers"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. YoY Procedure Growth

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.yoy_procedure_growth
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Year-over-year procedure volume change by HCP, specialty, and area"
source: ${catalog}.${schema}.hcp_procedure_volume
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Specialty
    expr: specialty
    comment: "Medical specialty"
  - name: Account
    expr: account
    comment: "Hospital account"
  - name: Surgeon Name
    expr: surgeon_name
    comment: "HCP surgeon name"
measures:
  - name: Total YoY Volume Change
    expr: SUM(cy_vs_py_procedure_volume)
    comment: "Sum of CY vs PY procedure volume change"
  - name: Avg YoY Volume Change
    expr: AVG(cy_vs_py_procedure_volume)
    comment: "Average CY vs PY procedure volume change"
  - name: Growing HCPs
    expr: "COUNT(CASE WHEN cy_vs_py_procedure_volume > 0 THEN 1 END)"
    comment: "Number of HCPs with positive growth"
  - name: Declining HCPs
    expr: "COUNT(CASE WHEN cy_vs_py_procedure_volume < 0 THEN 1 END)"
    comment: "Number of HCPs with negative growth"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Total Upgrade Opportunity

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.total_upgrade_opportunity
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Total upgrade opportunity dollars by territory, product line, and account"
source: ${catalog}.${schema}.product_upgrades
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Region
    expr: region
    comment: "Sales region"
  - name: Territory
    expr: territory
    comment: "Sales territory"
  - name: Account
    expr: account
    comment: "Hospital account"
  - name: Product Line
    expr: product_line
    comment: "Product line - Alpha, Beta, Gamma, Delta Series"
  - name: Product Category
    expr: product_category
    comment: "Accessories, Capital Equipment, Service Contract, Disposables"
  - name: IDN
    expr: idn
    comment: "Integrated Delivery Network"
measures:
  - name: Total CY Opportunity
    expr: SUM(cy_opportunity)
    comment: "Sum of current year opportunity dollars"
  - name: Total PY Opportunity
    expr: SUM(py_opportunity)
    comment: "Sum of prior year opportunity dollars"
  - name: Total Net Cost
    expr: SUM(net_cost_to_customer)
    comment: "Sum of net cost to customer"
  - name: Total Upgrade Codes
    expr: SUM(num_upgrade_codes)
    comment: "Total number of upgrade codes available"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Rolling 12 Sales

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.rolling_12_sales_metric
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Rolling 12-month sales across accounts, territories, and product lines"
source: ${catalog}.${schema}.account_targeting
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Region
    expr: region
    comment: "Sales region"
  - name: Territory
    expr: territory
    comment: "Sales territory"
  - name: Account
    expr: account
    comment: "Hospital account"
  - name: Product Line
    expr: product_line
    comment: "Product line"
  - name: Target Type
    expr: target_type
    comment: "Tier 1=Upgrade, Tier 2=Competitive, Tier 3=Market Expansion"
  - name: Rep ID
    expr: rep_id
    comment: "Sales rep ID"
measures:
  - name: Total Rolling 12 Sales
    expr: SUM(rolling_12_sales)
    comment: "Sum of rolling 12-month sales in dollars"
  - name: Total Opportunity
    expr: SUM(opportunity)
    comment: "Sum of opportunity dollars"
  - name: Account Count
    expr: COUNT(DISTINCT account)
    comment: "Number of unique accounts"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Account Penetration

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.account_penetration
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Account penetration rates and YoY trends by target type, area, and clinical focus"
source: ${catalog}.${schema}.account_targeting
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Account
    expr: account
    comment: "Hospital account"
  - name: Target Type
    expr: target_type
    comment: "Tier 1=Upgrade, Tier 2=Competitive, Tier 3=Market Expansion"
  - name: Clinical Focus Area
    expr: clinical_focus_area
    comment: "Medical specialty focus"
  - name: Product Line
    expr: product_line
    comment: "Product line"
  - name: GPO
    expr: gpo
    comment: "Group Purchasing Organization"
measures:
  - name: Avg Penetration 2025
    expr: AVG(penetration_2025)
    comment: "Average 2025 penetration percentage"
  - name: Avg Penetration 2024
    expr: AVG(penetration_2024)
    comment: "Average 2024 penetration percentage"
  - name: Avg Penetration 2023
    expr: AVG(penetration_2023)
    comment: "Average 2023 penetration percentage"
  - name: Avg 3 Month Trend
    expr: AVG(trend_3_month)
    comment: "Average 3-month trend"
  - name: Penetration Improving Count
    expr: "COUNT(CASE WHEN penetration_2025 > penetration_2024 THEN 1 END)"
    comment: "Accounts with improving penetration YoY"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Market Exposure

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.market_exposure
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Current and prior year market exposure by territory and product line"
source: ${catalog}.${schema}.account_targeting
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Region
    expr: region
    comment: "Sales region"
  - name: Territory
    expr: territory
    comment: "Sales territory"
  - name: Product Line
    expr: product_line
    comment: "Product line"
  - name: Account
    expr: account
    comment: "Hospital account"
  - name: Target Type
    expr: target_type
    comment: "Sales strategy tier"
measures:
  - name: Avg CY Market Exposure
    expr: AVG(cy_market_exposure)
    comment: "Average current year market exposure percentage"
  - name: Avg PY Market Exposure
    expr: AVG(py_market_exposure)
    comment: "Average prior year market exposure percentage"
  - name: Total Units Sold
    expr: SUM(total_units_sold)
    comment: "Total units sold"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Total Max Market

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.total_max_market
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Total max market opportunity by product line and area"
source: ${catalog}.${schema}.hcp_procedure_volume
dimensions:
  - name: Area
    expr: area
    comment: "Geographic area"
  - name: Specialty
    expr: specialty
    comment: "Medical specialty"
  - name: Account
    expr: account
    comment: "Hospital account"
measures:
  - name: Total CY Max Market
    expr: SUM(total_cy_max_market)
    comment: "Sum of total current year max market across all product lines"
  - name: Total PY Max Market
    expr: SUM(total_py_max_market)
    comment: "Sum of total prior year max market"
  - name: CY Alpha Market
    expr: SUM(cy_alpha_max_market)
    comment: "CY Alpha product line max market"
  - name: CY Beta Market
    expr: SUM(cy_beta_max_market)
    comment: "CY Beta product line max market"
  - name: CY Gamma Market
    expr: SUM(cy_gamma_max_market)
    comment: "CY Gamma product line max market"
  - name: CY Delta Market
    expr: SUM(cy_delta_max_market)
    comment: "CY Delta product line max market"
$$;
