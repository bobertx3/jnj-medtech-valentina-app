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

ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN candidate_id SET NOT NULL;
ALTER TABLE ${catalog}.${schema}.candidate_pipeline
ADD CONSTRAINT pk_candidate_pipeline PRIMARY KEY (candidate_id);

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN requisition_id SET NOT NULL;
ALTER TABLE ${catalog}.${schema}.job_requisitions
ADD CONSTRAINT pk_job_requisitions PRIMARY KEY (requisition_id);

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN row_number SET NOT NULL;
ALTER TABLE ${catalog}.${schema}.hiring_metrics
ADD CONSTRAINT pk_hiring_metrics PRIMARY KEY (row_number);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Table Comments (for Genie context)

-- COMMAND ----------

COMMENT ON TABLE ${catalog}.${schema}.candidate_pipeline IS 'Individual candidate records tracking progression through the recruiting pipeline. Contains candidate demographics, source channel, current stage, time-in-stage, offer amounts, and experience. Join to other tables via recruiter_id, department, and business_unit.';

-- COMMAND ----------

COMMENT ON TABLE ${catalog}.${schema}.job_requisitions IS 'Job requisition records with hiring targets and fulfillment status. Contains priority levels, salary ranges, headcount targets vs filled, posting quarter, and days open. Statuses include Open, Filled, Cancelled, On Hold.';

-- COMMAND ----------

COMMENT ON TABLE ${catalog}.${schema}.hiring_metrics IS 'Aggregated hiring performance metrics by recruiter, department, and quarter. Contains time-to-fill, time-to-offer, offer acceptance rates, cost per hire, referral rates, diversity hiring percentages, and candidate satisfaction scores.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Column Comments - candidate_pipeline

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN candidate_id COMMENT 'Unique candidate identifier (primary key)';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN candidate_name COMMENT 'Full name of the candidate';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN recruiter_id COMMENT 'Recruiter identifier - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN department COMMENT 'Target department for the position (e.g., Engineering, Sales, Marketing) - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN business_unit COMMENT 'Business unit within the organization - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN position_title COMMENT 'Title of the position the candidate is applying for';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN source COMMENT 'Recruiting source channel (e.g., LinkedIn, Referral, Job Board, Career Site, Recruiter Outreach)';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN stage COMMENT 'Current pipeline stage (e.g., Applied, Phone Screen, Interview, Offered, Hired, Rejected, Withdrawn)';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN days_in_stage COMMENT 'Number of days the candidate has been in the current stage';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN total_days_in_pipeline COMMENT 'Total number of days from application to current status';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN offer_amount COMMENT 'Dollar amount of the offer extended to the candidate (NULL if no offer made)';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN experience_years COMMENT 'Number of years of professional experience';
ALTER TABLE ${catalog}.${schema}.candidate_pipeline ALTER COLUMN location COMMENT 'Geographic location of the candidate or position';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Column Comments - job_requisitions

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN requisition_id COMMENT 'Unique requisition identifier (primary key)';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN recruiter_id COMMENT 'Recruiter identifier - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN department COMMENT 'Department the requisition belongs to - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN business_unit COMMENT 'Business unit within the organization - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN position_title COMMENT 'Title of the open position';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN location COMMENT 'Geographic location of the position';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN priority COMMENT 'Requisition priority level (e.g., High, Medium, Low, Critical)';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN status COMMENT 'Current requisition status: Open, Filled, Cancelled, or On Hold';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN days_open COMMENT 'Number of days the requisition has been open';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN target_salary_min COMMENT 'Minimum target salary ($) for the position';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN target_salary_max COMMENT 'Maximum target salary ($) for the position';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN headcount_needed COMMENT 'Total number of hires needed for this requisition';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN headcount_filled COMMENT 'Number of hires already completed for this requisition';
ALTER TABLE ${catalog}.${schema}.job_requisitions ALTER COLUMN posting_quarter COMMENT 'Quarter when the requisition was posted (e.g., Q1 2025, Q2 2025)';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Column Comments - hiring_metrics

-- COMMAND ----------

ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN row_number COMMENT 'Unique row identifier (primary key)';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN recruiter_id COMMENT 'Recruiter identifier - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN department COMMENT 'Department name - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN business_unit COMMENT 'Business unit within the organization - shared across all 3 tables';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN region COMMENT 'Geographic region for the hiring activity';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN quarter COMMENT 'Reporting quarter (e.g., Q1 2025, Q2 2025)';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN positions_filled COMMENT 'Number of positions filled in this period';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN positions_open COMMENT 'Number of positions still open in this period';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN avg_time_to_fill_days COMMENT 'Average number of days from requisition open to position filled';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN avg_time_to_offer_days COMMENT 'Average number of days from requisition open to offer extended';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN offer_acceptance_rate COMMENT 'Rate of offers accepted (decimal 0.0 to 1.0, multiply by 100 for %)';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN cost_per_hire COMMENT 'Average cost in dollars ($) to fill a position';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN referral_rate COMMENT 'Percentage of hires sourced from referrals (decimal 0.0 to 1.0)';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN diversity_hire_pct COMMENT 'Percentage of hires meeting diversity criteria (decimal 0.0 to 1.0)';
ALTER TABLE ${catalog}.${schema}.hiring_metrics ALTER COLUMN candidate_satisfaction_score COMMENT 'Average candidate satisfaction score for the recruiting process (scale varies)';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Verify Metadata

-- COMMAND ----------

DESCRIBE EXTENDED ${catalog}.${schema}.candidate_pipeline;
