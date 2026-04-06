-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 01 - Setup and Load Raw Data
-- MAGIC Load 3 CSV files from the volume into Delta tables.

-- COMMAND ----------

USE CATALOG ${catalog};
USE SCHEMA ${schema};

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load Candidate Pipeline (300 rows)

-- COMMAND ----------

CREATE OR REPLACE TABLE ${catalog}.${schema}.candidate_pipeline AS
SELECT
  CAST(`Candidate ID` AS INT) AS candidate_id,
  `Candidate Name` AS candidate_name,
  `Recruiter ID` AS recruiter_id,
  `Department` AS department,
  `Business Unit` AS business_unit,
  `Position Title` AS position_title,
  `Source` AS source,
  `Stage` AS stage,
  CAST(`Days In Stage` AS INT) AS days_in_stage,
  CAST(`Total Days In Pipeline` AS INT) AS total_days_in_pipeline,
  CAST(`Offer Amount` AS DOUBLE) AS offer_amount,
  CAST(`Experience Years` AS INT) AS experience_years,
  `Location` AS location
FROM read_files(
  '/Volumes/${catalog}/${schema}/${volume_name}/hr_recruiting/candidate_pipeline.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load Job Requisitions (150 rows)

-- COMMAND ----------

CREATE OR REPLACE TABLE ${catalog}.${schema}.job_requisitions AS
SELECT
  `Requisition ID` AS requisition_id,
  `Recruiter ID` AS recruiter_id,
  `Department` AS department,
  `Business Unit` AS business_unit,
  `Position Title` AS position_title,
  `Location` AS location,
  `Priority` AS priority,
  `Status` AS status,
  CAST(`Days Open` AS INT) AS days_open,
  CAST(`Target Salary Min` AS DOUBLE) AS target_salary_min,
  CAST(`Target Salary Max` AS DOUBLE) AS target_salary_max,
  CAST(`Headcount Needed` AS INT) AS headcount_needed,
  CAST(`Headcount Filled` AS INT) AS headcount_filled,
  `Posting Quarter` AS posting_quarter
FROM read_files(
  '/Volumes/${catalog}/${schema}/${volume_name}/hr_recruiting/job_requisitions.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load Hiring Metrics (400 rows)

-- COMMAND ----------

CREATE OR REPLACE TABLE ${catalog}.${schema}.hiring_metrics AS
SELECT
  CAST(`Row Number` AS INT) AS row_number,
  `Recruiter ID` AS recruiter_id,
  `Department` AS department,
  `Business Unit` AS business_unit,
  `Region` AS region,
  `Quarter` AS quarter,
  CAST(`Positions Filled` AS INT) AS positions_filled,
  CAST(`Positions Open` AS INT) AS positions_open,
  CAST(`Avg Time To Fill Days` AS DOUBLE) AS avg_time_to_fill_days,
  CAST(`Avg Time To Offer Days` AS DOUBLE) AS avg_time_to_offer_days,
  CAST(`Offer Acceptance Rate` AS DOUBLE) AS offer_acceptance_rate,
  CAST(`Cost Per Hire` AS DOUBLE) AS cost_per_hire,
  CAST(`Referral Rate` AS DOUBLE) AS referral_rate,
  CAST(`Diversity Hire Pct` AS DOUBLE) AS diversity_hire_pct,
  CAST(`Candidate Satisfaction Score` AS DOUBLE) AS candidate_satisfaction_score
FROM read_files(
  '/Volumes/${catalog}/${schema}/${volume_name}/hr_recruiting/hiring_metrics.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Verify row counts

-- COMMAND ----------

SELECT 'candidate_pipeline' AS table_name, COUNT(*) AS row_count FROM ${catalog}.${schema}.candidate_pipeline
UNION ALL
SELECT 'job_requisitions', COUNT(*) FROM ${catalog}.${schema}.job_requisitions
UNION ALL
SELECT 'hiring_metrics', COUNT(*) FROM ${catalog}.${schema}.hiring_metrics;
