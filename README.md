# J&J MedTech Sales Genie Workshop
-- BOBBY

A Databricks workshop that loads curated med-tech sales data into Unity Catalog, creates governed metric views, builds a Genie Space for natural-language analytics, and deploys a branded web app — all driven by six sequential notebooks.

## Business context

This demo models how a med-tech field organization reasons about **procedure volume**, **wallet share**, and **commercial opportunity** across accounts and surgeons:

- **HCP / surgeon lens** — Current-year and prior-year procedure volumes by specialty and product line, tied to NPI-level HCP records.
- **Account & territory lens** — Opportunity dollars, rolling 12-month sales, penetration trends, GPO alignment, and geographic hierarchy (area → region → territory).
- **Product & upgrade lens** — Upgrade paths, competitive positioning, and targeting tiers:
  - **Tier 1 — Upgrade** — Expand share with existing customers.
  - **Tier 2 — Competitive** — Win from competitors.
  - **Tier 3 — Market expansion** — New procedures or greenfield opportunity.

The sample data spans **four product families** (Alpha, Beta, Gamma, Delta Series) and **five U.S. areas** (Northeast, Southeast, Central, Northwest, Southwest).

## Prerequisites

| Requirement | Notes |
|---|---|
| Databricks workspace with Unity Catalog | You need permission to create schemas, tables, volumes, and apps |
| SQL Warehouse | Go to **SQL Warehouses** → pick one → copy the Warehouse ID |

## Getting started

Upload this repo to your Databricks workspace (**Workspace** → **Import** → select the folder), then run the notebooks in order:

| Notebook | What it does |
|---|---|
| `00_prerequisites` | Read this first — instructions to create a volume and upload the 3 CSV files |
| `01_setup_and_load` | Creates 3 Delta tables from the CSVs |
| `02_add_uc_metadata` | Adds primary keys, table comments, and column comments |
| `03_add_business_semantics` | Creates 7 governed metric views |
| `04_create_genie_space` | Creates (or updates) the Genie Space |
| `05_deploy_app` | Uploads app source and deploys the Databricks App |

Each notebook has **widgets** at the top for catalog, schema, warehouse ID, and other config. Fill them in and run all cells. Every notebook is re-run safe.

## Datasets

| Table | Rows | Description |
|---|---|---|
| `hcp_procedure_volume` | 150 | Surgeon/HCP procedure volumes by NPI, specialty, and product line |
| `product_upgrades` | 400 | Product upgrade opportunities by account, territory, and product |
| `account_targeting` | 300 | Account opportunity, penetration, GPO, tiers, and rolling 12-month sales |

**Metric views (7):** `total_procedure_volume`, `yoy_procedure_growth`, `total_upgrade_opportunity`, `rolling_12_sales_metric`, `account_penetration`, `market_exposure`, `total_max_market`

**Join keys:** `rep_id` and `account` link all three base tables.

## Project structure

```
notebooks/
  00_prerequisites.ipynb          # Start here — volume and CSV upload instructions
  01_setup_and_load.ipynb         # Load CSVs → Delta tables
  02_add_uc_metadata.ipynb        # PKs, table comments, column comments
  03_add_business_semantics.ipynb # 7 governed metric views
  04_create_genie_space.ipynb     # Create / update Genie Space
  05_deploy_app.ipynb             # Deploy Databricks App
  genie_space.json                # Genie Space config (used by notebook 04)

app/
  app.py                          # FastAPI backend
  app.yaml                        # Databricks App config (auth, resources)
  index.html                      # Chat + dashboard UI
  requirements.txt

raw_data/
  med_tech_sales/
    account_targeting.csv
    hcp_procedure_volume.csv
    product_upgrades.csv
```

## Built with

- **Databricks Unity Catalog** — Tables, volumes, and metric views
- **Databricks Genie** — Natural language to SQL with governed context
- **Databricks Apps** — Hosted FastAPI app with user authentication
- **FastAPI & httpx** — Genie REST client and polling
