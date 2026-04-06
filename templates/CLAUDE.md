# J&J Genie Workshop App

## Overview
Multi-dataset Genie workshop app. Users select a dataset (e.g. med_tech_sales, hr_recruiting) during install. Loads CSVs into Databricks Unity Catalog, creates metric views, powers a Genie space, and serves a branded AI chat advisor web app.

## Workspace
- **Profile:** `__PROFILE__`
- **Host:** `__WORKSPACE_URL__`
- **Catalog/Schema:** `__CATALOG__.__SCHEMA__`
- **SQL Warehouse:** `__WAREHOUSE_ID__`
- **Genie Space ID:** `__GENIE_SPACE_ID__`
- **App Name:** `__APP_NAME__`
- **Dataset:** `__DATASET__`

## Project Structure
```
├── databricks.yml              # DAB bundle config (dataset variable selects which to deploy)
├── resources/
│   ├── pipeline_job.yml        # Pipeline job (5 tasks, uses ${var.dataset} for paths)
│   └── genie_app.yml           # App resource (source_code_path uses ${var.dataset})
├── src/
│   ├── notebooks/
│   │   ├── 00_setup_data_in_volume.py  # Shared — copies CSVs for selected dataset
│   │   ├── med_tech_sales/             # MedTech Sales notebooks
│   │   │   ├── 01_setup_and_load.sql
│   │   │   ├── 02_add_uc_metadata.sql
│   │   │   └── 03_add_business_semantics.sql
│   │   └── hr_recruiting/              # HR Recruiting notebooks (future)
│   ├── genie/
│   │   ├── 04_create_genie_space.py    # Shared — loads genie_space.json for selected dataset
│   │   ├── med_tech_sales/
│   │   │   └── genie_space.json
│   │   └── hr_recruiting/              # Future
│   └── app/
│       ├── med_tech_sales/             # MedTech Sales app
│       │   ├── app.py
│       │   ├── app.yaml
│       │   ├── index.html
│       │   ├── requirements.txt
│       │   └── frontend/
│       └── hr_recruiting/              # Future
├── raw_data/
│   ├── med_tech_sales/                 # MedTech Sales CSVs
│   └── hr_recruiting/                  # Future
├── templates/                          # Template files for install.sh
│   ├── med_tech_sales/                 # Dataset-specific app templates
│   └── hr_recruiting/                  # Future
├── design/                             # UI reference screenshots
└── test_cases/                         # Validation test cases (Excel)
```

## Data Model (med_tech_sales)

### Tables (__CATALOG__.__SCHEMA__)
| Table | Rows | PK | Description |
|-------|------|----|-------------|
| `hcp_procedure_volume` | 150 | `npi` | HCP/surgeon procedure volumes, CY/PY market by product line |
| `product_upgrades` | 400 | `row_number` | Product upgrade opportunities by territory, product, account |
| `account_targeting` | 300 | `row_number` | Account targeting with penetration %, trends, GPO, tiers |

### Cross-table Join Keys
- `rep_id` - shared across all 3 tables
- `account` - shared across all 3 tables
- `territory` - shared between product_upgrades and account_targeting

### Metric Views (7)
- `total_procedure_volume` - CY procedure volume by area/specialty/rep
- `yoy_procedure_growth` - YoY procedure volume change
- `total_upgrade_opportunity` - Upgrade opportunity $ by territory/product
- `rolling_12_sales_metric` - Rolling 12-month sales
- `account_penetration` - Penetration rates and YoY trends
- `market_exposure` - CY/PY market exposure %
- `total_max_market` - Max market by product line

### Target Type Mapping
- **Tier 1** = Upgrade opportunity
- **Tier 2** = Competitive opportunity
- **Tier 3** = Market Expansion opportunity

## Key Commands
```bash
# Validate bundle
databricks bundle validate

# Deploy to workspace
databricks bundle deploy --auto-approve

# Run the pipeline job
databricks bundle run data_pipeline

# Start the app
databricks bundle run ask_genie

# View app logs
databricks apps logs __APP_NAME__ -p __PROFILE__

# Destroy deployment
databricks bundle destroy --auto-approve
```

## AI Dev Kit Skills Used
- `databricks-config` - workspace switching
- `databricks-unity-catalog` - volume/schema management
- `databricks-dbsql` - SQL execution
- `databricks-metric-views` - metric view creation
- `databricks-genie` - Genie space management
- `databricks-app-python` - app deployment
- `databricks-bundles` - DAB deployment
