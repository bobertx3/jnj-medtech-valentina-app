-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 - Add Business Semantics
-- MAGIC Define 7 governed metric views for KPIs across candidate pipeline, job requisitions, and hiring metrics.

-- COMMAND ----------

USE CATALOG ${catalog};
USE SCHEMA ${schema};

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Pipeline by Stage

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.pipeline_by_stage
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Candidate pipeline distribution by stage, source, department, and location"
source: ${catalog}.${schema}.candidate_pipeline
dimensions:
  - name: Department
    expr: department
    comment: "Target department for the position"
  - name: Business Unit
    expr: business_unit
    comment: "Business unit within the organization"
  - name: Source
    expr: source
    comment: "Recruiting source channel"
  - name: Stage
    expr: stage
    comment: "Current pipeline stage"
  - name: Location
    expr: location
    comment: "Geographic location"
measures:
  - name: Candidate Count
    expr: COUNT(DISTINCT candidate_id)
    comment: "Number of unique candidates"
  - name: Avg Days In Pipeline
    expr: AVG(total_days_in_pipeline)
    comment: "Average total days candidates spend in the pipeline"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Time to Fill

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.time_to_fill
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Time to fill analysis for filled requisitions by department, priority, and quarter"
source: ${catalog}.${schema}.job_requisitions
filter: "status = 'Filled'"
dimensions:
  - name: Department
    expr: department
    comment: "Department the requisition belongs to"
  - name: Business Unit
    expr: business_unit
    comment: "Business unit within the organization"
  - name: Location
    expr: location
    comment: "Geographic location of the position"
  - name: Priority
    expr: priority
    comment: "Requisition priority level"
  - name: Posting Quarter
    expr: posting_quarter
    comment: "Quarter when the requisition was posted"
measures:
  - name: Avg Days Open
    expr: AVG(days_open)
    comment: "Average number of days requisitions were open before being filled"
  - name: Requisition Count
    expr: COUNT(DISTINCT requisition_id)
    comment: "Number of filled requisitions"
  - name: Total Headcount Filled
    expr: SUM(headcount_filled)
    comment: "Total headcount filled across requisitions"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Offer Metrics

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.offer_metrics
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Offer and hire metrics for candidates who reached Offered or Hired stage"
source: ${catalog}.${schema}.candidate_pipeline
filter: "stage IN ('Offered', 'Hired')"
dimensions:
  - name: Department
    expr: department
    comment: "Target department"
  - name: Business Unit
    expr: business_unit
    comment: "Business unit"
  - name: Source
    expr: source
    comment: "Recruiting source channel"
  - name: Location
    expr: location
    comment: "Geographic location"
measures:
  - name: Avg Offer Amount
    expr: AVG(offer_amount)
    comment: "Average dollar amount of offers extended"
  - name: Offer Count
    expr: "COUNT(CASE WHEN stage = 'Offered' THEN 1 END) + COUNT(CASE WHEN stage = 'Hired' THEN 1 END)"
    comment: "Total number of offers extended (Offered + Hired)"
  - name: Hire Count
    expr: "COUNT(CASE WHEN stage = 'Hired' THEN 1 END)"
    comment: "Number of candidates who were hired"
  - name: Offer to Hire Rate
    expr: "CAST(COUNT(CASE WHEN stage = 'Hired' THEN 1 END) AS DOUBLE) / NULLIF(COUNT(*), 0)"
    comment: "Ratio of hires to total offers (decimal 0.0 to 1.0)"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Recruiter Performance

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.recruiter_performance
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Recruiter-level performance metrics including fill rates, acceptance rates, and satisfaction"
source: ${catalog}.${schema}.hiring_metrics
dimensions:
  - name: Recruiter ID
    expr: recruiter_id
    comment: "Recruiter identifier"
  - name: Quarter
    expr: quarter
    comment: "Reporting quarter"
  - name: Region
    expr: region
    comment: "Geographic region"
measures:
  - name: Total Positions Filled
    expr: SUM(positions_filled)
    comment: "Total number of positions filled"
  - name: Total Positions Open
    expr: SUM(positions_open)
    comment: "Total number of positions still open"
  - name: Avg Time To Fill
    expr: AVG(avg_time_to_fill_days)
    comment: "Average days to fill a position"
  - name: Avg Offer Acceptance Rate
    expr: AVG(offer_acceptance_rate)
    comment: "Average offer acceptance rate"
  - name: Avg Satisfaction Score
    expr: AVG(candidate_satisfaction_score)
    comment: "Average candidate satisfaction score"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Source Effectiveness

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.source_effectiveness
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Recruiting source effectiveness measured by hire rate and pipeline velocity"
source: ${catalog}.${schema}.candidate_pipeline
dimensions:
  - name: Source
    expr: source
    comment: "Recruiting source channel"
  - name: Department
    expr: department
    comment: "Target department"
  - name: Business Unit
    expr: business_unit
    comment: "Business unit"
measures:
  - name: Total Candidates
    expr: COUNT(DISTINCT candidate_id)
    comment: "Total number of unique candidates from this source"
  - name: Hired Count
    expr: "COUNT(CASE WHEN stage = 'Hired' THEN 1 END)"
    comment: "Number of candidates hired from this source"
  - name: Hire Rate
    expr: "CAST(COUNT(CASE WHEN stage = 'Hired' THEN 1 END) AS DOUBLE) / NULLIF(COUNT(DISTINCT candidate_id), 0)"
    comment: "Ratio of hires to total candidates (decimal 0.0 to 1.0)"
  - name: Avg Days In Pipeline
    expr: AVG(total_days_in_pipeline)
    comment: "Average total days candidates from this source spend in pipeline"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Diversity Metrics

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.diversity_metrics
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Diversity hiring metrics by department, region, and quarter"
source: ${catalog}.${schema}.hiring_metrics
dimensions:
  - name: Department
    expr: department
    comment: "Department name"
  - name: Business Unit
    expr: business_unit
    comment: "Business unit"
  - name: Region
    expr: region
    comment: "Geographic region"
  - name: Quarter
    expr: quarter
    comment: "Reporting quarter"
measures:
  - name: Avg Diversity Hire Pct
    expr: AVG(diversity_hire_pct)
    comment: "Average diversity hire percentage"
  - name: Total Positions Filled
    expr: SUM(positions_filled)
    comment: "Total positions filled"
  - name: Weighted Diversity Hires
    expr: SUM(diversity_hire_pct * positions_filled)
    comment: "Weighted diversity hires (diversity_hire_pct * positions_filled)"
$$;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Cost Per Hire Metric

-- COMMAND ----------

CREATE OR REPLACE VIEW ${catalog}.${schema}.cost_per_hire_metric
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Hiring cost analysis by department, region, and quarter"
source: ${catalog}.${schema}.hiring_metrics
dimensions:
  - name: Department
    expr: department
    comment: "Department name"
  - name: Business Unit
    expr: business_unit
    comment: "Business unit"
  - name: Region
    expr: region
    comment: "Geographic region"
  - name: Quarter
    expr: quarter
    comment: "Reporting quarter"
measures:
  - name: Avg Cost Per Hire
    expr: AVG(cost_per_hire)
    comment: "Average cost in dollars to fill a position"
  - name: Total Cost
    expr: SUM(cost_per_hire * positions_filled)
    comment: "Total hiring cost (cost_per_hire * positions_filled)"
  - name: Total Positions Filled
    expr: SUM(positions_filled)
    comment: "Total number of positions filled"
$$;
