# J&J MedTech Sales Genie App

## Overview
Data backup and analytics solution for J&J MedTech surgical product sales. Loads 3 CSV datasets into Databricks Unity Catalog, creates metric views, powers a Genie space, and serves a branded AI chat advisor web app.

## Workspace
- **Profile:** `free-edition-datakafe`
- **Host:** `https://dbc-cbc6ac73-661b.cloud.databricks.com`
- **Catalog/Schema:** `jnj_medtech.sales.
- **SQL Warehouse:** `a1119b437a4a8d45`
- **Genie Space ID:** `01f12fb14eb21d5e9864032b2d13316f`
- **App Name:** `medtech-sales-genie`

## Project Structure
```
├── databricks.yml              # DAB bundle config
├── resources/
│   ├── valentina_job.yml       # Pipeline job (4 tasks)
│   └── valentina_app.yml       # App resource definition
├── src/
│   ├── notebooks/
│   │   ├── 01_setup_and_load.sql   # Create tables from CSVs
│   │   ├── 02_add_uc_metadata.sql  # PK constraints + table/column comments
│   │   └── 03_add_business_semantics.sql  # 7 metric views
│   ├── genie/
│   │   ├── 04_create_genie_space.py  # Creates/updates Genie space via REST API
│   │   └── valentina_genie.json      # Genie space config (serialized_space export)
│   └── app/
│       ├── app.py              # FastAPI backend (Genie API integration)
│       ├── app.yaml            # Databricks Apps config
│       ├── index.html          # Standalone HTML frontend (fallback)
│       ├── requirements.txt    # Python deps
│       └── frontend/           # React app (APX)
│           ├── src/App.js      # React chat UI
│           └── src/App.css     # J&J red branding
├── raw_data/                   # Source CSVs (uploaded to volume)
├── design/                     # UI reference screenshots
└── test_cases/                 # Validation test cases (Excel)
```

## Data Model

### Tables (medtech.sales)
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
databricks bundle run medtech_pipeline

# Start the app
databricks bundle run medtech_ask_genie

# View app logs
databricks apps logs medtech-sales-genie -p free-edition-datakafe

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
