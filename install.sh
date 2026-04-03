#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# J&J MedTech Sales Genie App — Installation Script
# Configures the repo for your Databricks workspace.
# ──────────────────────────────────────────────────────────────

CONFIG_FILE="config.json"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   J&J MedTech Sales Genie App — Setup                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Before you begin, make sure you have the following ready"
echo "in your Databricks workspace:"
echo ""
echo "  1. A Unity Catalog (e.g. 'medtech')"
echo "     The catalog must already exist. The setup will create"
echo "     the schema and volume for you automatically."
echo ""
echo "  2. A SQL Warehouse"
echo "     Go to SQL Warehouses in the sidebar and copy the ID"
echo "     from an existing warehouse. If you don't have one,"
echo "     create a Serverless SQL Warehouse first."
echo ""
echo "  3. An empty Genie Space"
echo "     Go to Genie in the sidebar, click '+ New' to create"
echo "     a blank space, then copy the ID from the URL:"
echo "     https://<your-workspace>/genie/rooms/<SPACE_ID>"
echo ""
echo "  4. Databricks CLI installed and configured"
echo "     Run 'databricks configure' if you haven't already."
echo ""
echo "──────────────────────────────────────────────────────────"
echo ""
read -rp "Ready to continue? (y/N): " ready
if [[ ! "$ready" =~ ^[Yy]$ ]]; then
  echo "No problem — come back when you have the above ready."
  exit 0
fi
echo ""

# ── Helper ────────────────────────────────────────────────────

prompt() {
  local var_name="$1" prompt_text="$2" default="${3:-}"
  local value
  if [[ -n "$default" ]]; then
    read -rp "$prompt_text [$default]: " value
    value="${value:-$default}"
  else
    while true; do
      read -rp "$prompt_text: " value
      [[ -n "$value" ]] && break
      echo "  This field is required."
    done
  fi
  eval "$var_name=\"\$value\""
}

# ── Check for existing config ─────────────────────────────────

if [[ -f "$CONFIG_FILE" ]]; then
  echo "Found existing $CONFIG_FILE. Loading your previous values."
  echo ""
  existing_profile=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('profile',''))" 2>/dev/null || true)
  existing_workspace_url=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('workspace_url',''))" 2>/dev/null || true)
  existing_catalog=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('catalog',''))" 2>/dev/null || true)
  existing_schema=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('schema',''))" 2>/dev/null || true)
  existing_warehouse_id=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('warehouse_id',''))" 2>/dev/null || true)
  existing_genie_space_id=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('genie_space_id',''))" 2>/dev/null || true)
  existing_volume_name=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('volume_name',''))" 2>/dev/null || true)
  existing_app_name=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('app_name',''))" 2>/dev/null || true)
fi

# ── Collect inputs ────────────────────────────────────────────

echo "Enter your Databricks configuration values."
echo "(Press Enter to accept defaults shown in brackets.)"
echo ""

prompt PROFILE "Databricks CLI profile name" "${existing_profile:-DEFAULT}"

echo ""
echo "  Your workspace URL looks like:"
echo "    https://adb-xxxxxxxxxxxx.xx.azuredatabricks.net"
echo "    https://dbc-xxxxxxxx-xxxx.cloud.databricks.com"
echo ""
prompt WORKSPACE_URL "Workspace URL" "${existing_workspace_url:-}"

echo ""
prompt CATALOG "Catalog name (must already exist)" "${existing_catalog:-medtech}"
prompt SCHEMA  "Schema name (will be created if needed)" "${existing_schema:-sales}"
prompt VOLUME_NAME "Volume name for CSV data (will be created if needed)" "${existing_volume_name:-raw_data}"

echo ""
echo "  Find your SQL Warehouse ID in the workspace under"
echo "  SQL Warehouses > your warehouse > Connection Details."
echo ""
prompt WAREHOUSE_ID "SQL Warehouse ID" "${existing_warehouse_id:-}"

echo ""
echo "  Paste the Genie Space ID from the URL of the empty"
echo "  space you created earlier."
echo ""
prompt GENIE_SPACE_ID "Genie Space ID" "${existing_genie_space_id:-}"

echo ""
echo "  Pick a name for the web app. Rules:"
echo "    - Lowercase letters, numbers, and hyphens only"
echo "    - No underscores or spaces"
echo ""
prompt APP_NAME "App name" "${existing_app_name:-medtech-sales-genie}"

# ── Validate app name ─────────────────────────────────────────

# Strip trailing slash from workspace URL
WORKSPACE_URL="${WORKSPACE_URL%/}"

if [[ ! "$APP_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
  echo ""
  echo "  ERROR: App name must be lowercase, no underscores, start/end with a letter or number."
  echo "  Got: '$APP_NAME'"
  exit 1
fi

# ── Confirm ───────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────────────────────────────"
echo "  Profile:        $PROFILE"
echo "  Workspace URL:  $WORKSPACE_URL"
echo "  Catalog:        $CATALOG"
echo "  Schema:         $SCHEMA"
echo "  Volume:         $VOLUME_NAME"
echo "  Warehouse ID:   $WAREHOUSE_ID"
echo "  Genie Space ID: $GENIE_SPACE_ID"
echo "  App Name:       $APP_NAME"
echo "──────────────────────────────────────────────────────────"
echo ""
read -rp "Does everything look correct? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted. Run this script again to start over."
  exit 0
fi

# ── Write config.json ─────────────────────────────────────────

cat > "$CONFIG_FILE" <<EOF
{
  "profile": "$PROFILE",
  "workspace_url": "$WORKSPACE_URL",
  "catalog": "$CATALOG",
  "schema": "$SCHEMA",
  "warehouse_id": "$WAREHOUSE_ID",
  "volume_name": "$VOLUME_NAME",
  "genie_space_id": "$GENIE_SPACE_ID",
  "app_name": "$APP_NAME"
}
EOF
echo ""
echo "Saved your settings to $CONFIG_FILE"

# ── Replace placeholders ──────────────────────────────────────

FILES=(
  databricks.yml
  resources/valentina_app.yml
  resources/valentina_job.yml
  src/app/app.py
  src/app/app.yaml
  CLAUDE.md
  README.md
)

replace_placeholder() {
  local placeholder="$1" value="$2"
  for f in "${FILES[@]}"; do
    if [[ -f "$f" ]]; then
      # Use | as sed delimiter to avoid conflicts with / in values
      sed -i'' -e "s|${placeholder}|${value}|g" "$f"
    fi
  done
}

# First, restore placeholders from previous config (for idempotent re-runs)
if [[ -n "${existing_profile:-}" ]]; then
  echo "Restoring placeholders from previous config..."
  # Reverse order: replace old values back to placeholders
  # Replace longer strings first to avoid partial matches
  replace_placeholder "${existing_profile}"        "__PROFILE__"
  replace_placeholder "${existing_workspace_url}"  "__WORKSPACE_URL__"
  replace_placeholder "${existing_catalog}.${existing_schema}." "__CATALOG__.__SCHEMA__."
  replace_placeholder "${existing_catalog}"        "__CATALOG__"
  replace_placeholder "${existing_schema}"         "__SCHEMA__"
  replace_placeholder "${existing_warehouse_id}"   "__WAREHOUSE_ID__"
  replace_placeholder "${existing_volume_name}"    "__VOLUME_NAME__"
  replace_placeholder "${existing_genie_space_id}" "__GENIE_SPACE_ID__"
  replace_placeholder "${existing_app_name}"       "__APP_NAME__"

  # Clear cached bundle state (may point to old workspace)
  rm -rf .databricks/ .databricks-resources.json 2>/dev/null || true
fi

echo "Configuring project files..."
replace_placeholder "__PROFILE__"        "$PROFILE"
replace_placeholder "__WORKSPACE_URL__"  "$WORKSPACE_URL"
replace_placeholder "__CATALOG__"        "$CATALOG"
replace_placeholder "__SCHEMA__"         "$SCHEMA"
replace_placeholder "__WAREHOUSE_ID__"   "$WAREHOUSE_ID"
replace_placeholder "__VOLUME_NAME__"    "$VOLUME_NAME"
replace_placeholder "__GENIE_SPACE_ID__" "$GENIE_SPACE_ID"
replace_placeholder "__APP_NAME__"       "$APP_NAME"

# Clean up sed backup files (macOS creates -e files)
find . -name "*-e" -type f -delete 2>/dev/null || true

echo "Done!"

# ── Deploy ────────────────────────────────────────────────────

# ── Authenticate ──────────────────────────────────────────────

echo ""
echo "Logging in to your Databricks workspace..."
echo ""
databricks auth login --host "$WORKSPACE_URL" --profile "$PROFILE"

# ── Deploy ────────────────────────────────────────────────────

echo ""
echo "Configuration complete! Ready to deploy."
echo ""
read -rp "Would you like to deploy now? (y/N): " deploy
if [[ ! "$deploy" =~ ^[Yy]$ ]]; then
  echo ""
  echo "You can deploy later by running:"
  echo "  databricks bundle deploy --auto-approve"
  echo "  databricks bundle run medtech_pipeline"
  echo "  databricks bundle run medtech_ask_genie"
  echo ""
  exit 0
fi

echo ""
echo "Step 1/3 — Pushing everything to your workspace..."
echo "  Running: databricks bundle deploy --auto-approve"
echo ""
databricks bundle deploy --auto-approve

echo ""
echo "Step 2/3 — Loading data and configuring the Genie space..."
echo "  Running: databricks bundle run medtech_pipeline"
echo "  (this may take a few minutes)"
echo ""
databricks bundle run medtech_pipeline

echo ""
echo "Step 3/3 — Starting the web app..."
echo "  Running: databricks bundle run medtech_ask_genie"
echo ""
databricks bundle run medtech_ask_genie

echo ""
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  All done! Your app should be running."
echo ""
echo "  Useful commands:"
echo ""
echo "    Check app status:"
echo "      databricks apps get $APP_NAME --profile $PROFILE"
echo ""
echo "    Re-deploy after making changes:"
echo "      databricks bundle deploy --auto-approve"
echo "      databricks bundle run medtech_ask_genie"
echo ""
echo "    Re-run the data pipeline:"
echo "      databricks bundle run medtech_pipeline"
echo ""
echo "    Remove everything from your workspace:"
echo "      databricks bundle destroy --auto-approve"
echo ""
echo "══════════════════════════════════════════════════════════"
echo ""
