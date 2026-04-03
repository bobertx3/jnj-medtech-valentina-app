# J&J MedTech Valentina - Data Backup & AI Advisor

A Databricks-powered data backup and analytics solution for J&J MedTech surgical product sales data. Features a natural language AI chat advisor (Valentina) backed by Databricks Genie and Unity Catalog metric views.

## Architecture

```
Raw CSVs ─→ Unity Catalog Volume ─→ Delta Tables (3) ─→ Metric Views (7)
                                                              │
                                          ┌──────────────────┤
                                          ▼                   ▼
                                    Genie Space        FastAPI + React App
                                   (NL Queries)       (AI Advisor Chat UI)
```

## What's Included

### Data Pipeline
- **3 CSV datasets** loaded into `medtech.sales` catalog:
  - `hcp_procedure_volume` (150 rows) - Surgeon procedure volumes by NPI
  - `product_upgrades` (400 rows) - Product upgrade opportunities
  - `account_targeting` (300 rows) - Account targeting with penetration metrics
- **Primary key constraints** on all tables
- **7 metric views** for governed KPIs (procedure volume, YoY growth, upgrade opportunity, rolling sales, penetration, market exposure, max market)

### Genie Space
Natural language SQL exploration with 10 sample questions from validated test cases, covering simple lookups to complex cross-table analytics.

### Web Application
J&J MedTech branded AI Advisor chat interface:
- Red (#EB1700) header with J&J branding
- Sidebar navigation (Chat, History, Dashboard, Contact Center)
- Platform Group selector
- Chat with Valentina AI powered by Genie API
- Markdown table rendering, SQL viewer, suggested prompts

## Quick Start

### Prerequisites
- [Databricks CLI](https://docs.databricks.com/dev-tools/cli/install.html) installed
- Profile `free-edition-rleach` configured in `~/.databrickscfg`

### Deploy

```bash
# Validate the bundle
databricks bundle validate

# Deploy all resources
databricks bundle deploy --auto-approve

# Run the data pipeline
databricks bundle run valentina_pipeline

# Start the web app
databricks bundle run valentina_advisor
```

### Teardown

```bash
databricks bundle destroy --auto-approve
```

## Project Structure

```
├── databricks.yml              # Databricks Asset Bundle config
├── resources/
│   ├── valentina_job.yml       # Pipeline job definition
│   └── valentina_app.yml       # App resource definition
├── src/
│   ├── notebooks/              # SQL notebooks (pipeline)
│   │   ├── 01_setup_and_load.sql
│   │   ├── 02_constraints.sql
│   │   └── 03_metric_views.sql
│   └── app/                    # Web application
│       ├── app.py              # FastAPI backend
│       ├── app.yaml            # Databricks Apps config
│       ├── index.html          # Standalone HTML (fallback UI)
│       ├── requirements.txt
│       └── frontend/           # React frontend (APX)
├── raw_data/                   # Source CSV files
├── design/                     # UI reference screenshots
└── test_cases/                 # Validation test cases
```

## Data Model

### Relationships
- **rep_id** and **account** are the primary join keys across all 3 tables
- **territory**, **idn**, and **product_line** link product_upgrades and account_targeting
- Target Types: Tier 1 = Upgrade, Tier 2 = Competitive, Tier 3 = Market Expansion
- Product Lines: Alpha, Beta, Gamma, Delta Series

## Built With
- **Databricks Unity Catalog** - Data governance and catalog management
- **Databricks Genie** - Natural language SQL interface
- **Databricks Metric Views** - Governed business KPIs
- **Databricks Apps** - Managed web application hosting
- **Databricks Asset Bundles** - Infrastructure as code deployment
- **FastAPI** - Backend API framework
- **React** - Frontend UI framework
- **Databricks AI Dev Kit** - Development tooling
