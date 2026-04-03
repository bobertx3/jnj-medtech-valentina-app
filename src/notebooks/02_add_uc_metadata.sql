-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 02 - Add UC Metadata
-- MAGIC Add primary key constraints, table comments, and column comments to all 3 tables for data governance, discoverability, and Genie context.

-- COMMAND ----------

USE CATALOG ${catalog};
USE SCHEMA ${schema};

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Primary Keys

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN npi SET NOT NULL;
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume
ADD CONSTRAINT pk_hcp_procedure_volume PRIMARY KEY (npi);

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN row_number SET NOT NULL;
ALTER TABLE ${catalog}.${schema}.product_upgrades
ADD CONSTRAINT pk_product_upgrades PRIMARY KEY (row_number);

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN row_number SET NOT NULL;
ALTER TABLE ${catalog}.${schema}.account_targeting
ADD CONSTRAINT pk_account_targeting PRIMARY KEY (row_number);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Table Comments (for Genie context)

-- COMMAND ----------

COMMENT ON TABLE ${catalog}.${schema}.hcp_procedure_volume IS 'Healthcare provider (HCP/surgeon) procedure volumes by NPI. Contains current year (CY) and prior year (PY) procedure volumes and max market opportunity by product line (Alpha, Beta, Gamma, Delta). Join to other tables via rep_id and account.';

-- COMMAND ----------

COMMENT ON TABLE ${catalog}.${schema}.product_upgrades IS 'Product upgrade opportunities by account, territory, and product. Contains upgrade codes, opportunity dollar amounts, discontinuation dates, and rolling 12-month sales. Product lines: Alpha, Beta, Gamma, Delta. Categories: Accessories, Capital Equipment, Service Contract, Disposables.';

-- COMMAND ----------

COMMENT ON TABLE ${catalog}.${schema}.account_targeting IS 'Account-level strategic targeting with penetration metrics. Contains target types (Tier 1=Upgrade, Tier 2=Competitive, Tier 3=Market Expansion), GPO affiliations, clinical focus areas, and year-over-year penetration trends. Key for identifying high-value opportunities.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Column Comments - account_targeting

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN row_number COMMENT 'Unique row identifier (primary key)';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN area COMMENT 'Geographic area (e.g., Northeast, Southeast, Central, Northwest, Southwest)';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN region COMMENT 'Geographic region within an area';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN territory COMMENT 'Sales territory assigned to a rep';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN rep_id COMMENT 'Sales representative identifier - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN idn COMMENT 'Integrated Delivery Network - hospital system name';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN account COMMENT 'Hospital or facility account name - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN clinical_focus_area COMMENT 'Clinical specialty or focus area for targeting';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN target_type COMMENT 'Sales strategy tier: Tier 1 = Upgrade, Tier 2 = Competitive, Tier 3 = Market Expansion, Non-Target = not targeted';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN product_line COMMENT 'Product line: Alpha Series, Beta Series, Gamma Series, or Delta Series';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN category COMMENT 'Product category within a product line';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN gpo COMMENT 'Group Purchasing Organization affiliation';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN total_units_sold COMMENT 'Total number of units sold to this account';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN opportunity COMMENT 'Dollar opportunity value ($) for this account/product/focus combination';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN net_cost_to_customer COMMENT 'Net cost to customer in dollars ($) after discounts';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN rolling_12_sales COMMENT 'Rolling 12-month sales in dollars ($)';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN num_codes_on_account_shelf COMMENT 'Number of product codes on the account shelf';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN num_codes_in_system COMMENT 'Number of product codes in the hospital system';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN num_codes_in_neither COMMENT 'Number of product codes not on shelf or in system';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN penetration_2025 COMMENT 'Product penetration percentage for 2025 (decimal 0.0 to 1.0, multiply by 100 for %)';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN penetration_2024 COMMENT 'Product penetration percentage for 2024 (decimal 0.0 to 1.0)';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN penetration_2023 COMMENT 'Product penetration percentage for 2023 (decimal 0.0 to 1.0)';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN trend_3_month COMMENT '3-month sales trend indicator';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN trend_6_month COMMENT '6-month sales trend indicator';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN trend_9_month COMMENT '9-month sales trend indicator';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN cy_market_exposure COMMENT 'Current year market exposure percentage';
ALTER TABLE ${catalog}.${schema}.account_targeting ALTER COLUMN py_market_exposure COMMENT 'Prior year market exposure percentage';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Column Comments - product_upgrades

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN row_number COMMENT 'Unique row identifier (primary key)';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN area COMMENT 'Geographic area (e.g., Northeast, Southeast, Central, Northwest, Southwest)';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN region COMMENT 'Geographic region within an area';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN territory COMMENT 'Sales territory assigned to a rep';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN idn COMMENT 'Integrated Delivery Network - hospital system name';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN rep_id COMMENT 'Sales representative identifier - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN account COMMENT 'Hospital or facility account name - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN product_line COMMENT 'Product line: Alpha Series, Beta Series, Gamma Series, or Delta Series';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN product_category COMMENT 'Product category (e.g., Accessories, Capital Equipment, Service Contract, Disposables)';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN product_description COMMENT 'Specific product name/description within a category';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN comped_status COMMENT 'Whether the product is provided at no cost: Comped or Not Comped';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN segment COMMENT 'Market segment classification';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN num_upgrade_codes COMMENT 'Number of upgrade product codes available';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN num_codes_on_account_shelf COMMENT 'Number of product codes on the account shelf';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN num_codes_in_idn_system COMMENT 'Number of product codes in the IDN hospital system';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN num_codes_in_neither COMMENT 'Number of product codes not on shelf or in system';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN discontinuation_date COMMENT 'Date when the product will be or was discontinued';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN cy_opportunity COMMENT 'Current year dollar opportunity value ($) for this product upgrade';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN py_opportunity COMMENT 'Prior year dollar opportunity value ($) for this product upgrade';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN net_cost_to_customer COMMENT 'Net cost to customer in dollars ($) after discounts';
ALTER TABLE ${catalog}.${schema}.product_upgrades ALTER COLUMN rolling_12_sales COMMENT 'Rolling 12-month sales in dollars ($)';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Column Comments - hcp_procedure_volume

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN npi COMMENT 'National Provider Identifier - unique ID for each healthcare provider (primary key)';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN surgeon_name COMMENT 'Full name of the surgeon/HCP';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN rep_id COMMENT 'Sales representative identifier - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN account COMMENT 'Hospital or facility account name - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN specialty COMMENT 'Medical specialty of the surgeon (e.g., General Surgery, Orthopedics)';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN area COMMENT 'Geographic area (e.g., Northeast, Southeast, Central, Northwest, Southwest)';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN cy_procedure_volume COMMENT 'Current year total procedure volume count';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN py_procedure_volume COMMENT 'Prior year total procedure volume count';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN cy_vs_py_procedure_volume COMMENT 'Year-over-year change in procedure volume (CY minus PY)';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN cy_alpha_max_market COMMENT 'Current year max market opportunity ($) for Alpha Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN cy_beta_max_market COMMENT 'Current year max market opportunity ($) for Beta Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN cy_gamma_max_market COMMENT 'Current year max market opportunity ($) for Gamma Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN cy_delta_max_market COMMENT 'Current year max market opportunity ($) for Delta Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN total_cy_max_market COMMENT 'Total current year max market opportunity ($) across all product lines';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN py_alpha_max_market COMMENT 'Prior year max market opportunity ($) for Alpha Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN py_beta_max_market COMMENT 'Prior year max market opportunity ($) for Beta Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN py_gamma_max_market COMMENT 'Prior year max market opportunity ($) for Gamma Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN py_delta_max_market COMMENT 'Prior year max market opportunity ($) for Delta Series products';
ALTER TABLE ${catalog}.${schema}.hcp_procedure_volume ALTER COLUMN total_py_max_market COMMENT 'Total prior year max market opportunity ($) across all product lines';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Verify Metadata

-- COMMAND ----------

DESCRIBE EXTENDED ${catalog}.${schema}.hcp_procedure_volume;
