#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# J&J Genie Workshop App — Installation Script
# Configures the repo for your Databricks workspace.
# ──────────────────────────────────────────────────────────────

CONFIG_FILE="config.json"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   J&J Genie Workshop App — Setup                         ║"
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
  existing_dataset=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('dataset',''))" 2>/dev/null || true)
fi

# ── Dataset selection ─────────────────────────────────────────

echo "Which dataset would you like to deploy?"
echo ""

dataset_labels=("Med Tech Sales" "HR Recruiting")
dataset_values=("med_tech_sales" "hr_recruiting")

# Find default selection index
default_idx=0
for i in "${!dataset_values[@]}"; do
  if [[ "${dataset_values[$i]}" == "${existing_dataset:-med_tech_sales}" ]]; then
    default_idx=$i
    break
  fi
done

selected=$default_idx
while true; do
  echo "  Select a dataset (use arrow keys, Enter to confirm):"
  echo ""
  for i in "${!dataset_labels[@]}"; do
    if [[ $i -eq $selected ]]; then
      echo "  > ${dataset_labels[$i]}"
    else
      echo "    ${dataset_labels[$i]}"
    fi
  done
  echo ""

  IFS= read -rsn1 key
  if [[ "$key" == $'\x1b' ]]; then
    read -rsn2 arrow
    case "$arrow" in
      '[A') (( selected > 0 )) && (( selected-- )) ;;
      '[B') (( selected < ${#dataset_labels[@]} - 1 )) && (( selected++ )) ;;
    esac
    lines=$(( ${#dataset_labels[@]} + 3 ))
    printf "\033[${lines}A\033[J"
  elif [[ "$key" == "" ]]; then
    DATASET="${dataset_values[$selected]}"
    break
  fi
done
echo "  Selected: ${dataset_labels[$selected]} ($DATASET)"

# Check that the selected dataset has files
if [[ ! -d "src/notebooks/$DATASET" ]] || [[ -z "$(ls -A "src/notebooks/$DATASET" 2>/dev/null)" ]]; then
  echo ""
  echo "  WARNING: Dataset '$DATASET' does not have notebooks yet."
  echo "  Only 'med_tech_sales' is fully configured at this time."
  echo ""
  read -rp "  Continue anyway? (y/N): " cont
  if [[ ! "$cont" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# ── Collect inputs ────────────────────────────────────────────

echo ""
echo "Enter your Databricks configuration values."
echo "(Press Enter to accept defaults shown in brackets.)"
echo ""

# Interactive profile selector
DBCFG="$HOME/.databrickscfg"
PROFILE=""
if [[ -f "$DBCFG" ]]; then
  profile_list=()
  while IFS= read -r line; do
    profile_list+=("$line")
  done < <(grep '^\[' "$DBCFG" | tr -d '[]')
  if [[ ${#profile_list[@]} -gt 0 ]]; then
    # Find default selection index
    default_idx=0
    for i in "${!profile_list[@]}"; do
      if [[ "${profile_list[$i]}" == "${existing_profile:-DEFAULT}" ]]; then
        default_idx=$i
        break
      fi
    done

    selected=$default_idx
    while true; do
      # Clear and redraw the menu
      echo "  Select a Databricks CLI profile (use arrow keys, Enter to confirm):"
      echo ""
      for i in "${!profile_list[@]}"; do
        if [[ $i -eq $selected ]]; then
          echo "  > ${profile_list[$i]}"
        else
          echo "    ${profile_list[$i]}"
        fi
      done
      echo ""

      # Read a single keypress
      IFS= read -rsn1 key
      if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 arrow
        case "$arrow" in
          '[A') # Up arrow
            (( selected > 0 )) && (( selected-- ))
            ;;
          '[B') # Down arrow
            (( selected < ${#profile_list[@]} - 1 )) && (( selected++ ))
            ;;
        esac
        # Move cursor up to redraw (menu lines + 2 for header/footer)
        lines=$(( ${#profile_list[@]} + 3 ))
        printf "\033[${lines}A\033[J"
      elif [[ "$key" == "" ]]; then
        # Enter pressed — confirm selection
        PROFILE="${profile_list[$selected]}"
        break
      fi
    done
    echo "  Selected: $PROFILE"
  fi
fi

if [[ -z "$PROFILE" ]]; then
  prompt PROFILE "Databricks CLI profile name" "${existing_profile:-DEFAULT}"
fi

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
while true; do
  prompt APP_NAME "App name" "${existing_app_name:-medtech-sales-genie}"
  if [[ "$APP_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    break
  fi
  echo "  Invalid: must be lowercase, no underscores, start/end with a letter or number."
  echo "  Got: '$APP_NAME' — please try again."
  echo ""
done

# Strip trailing slash from workspace URL
WORKSPACE_URL="${WORKSPACE_URL%/}"

# ── Confirm ───────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────────────────────────────"
echo "  Dataset:        $DATASET"
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
  "app_name": "$APP_NAME",
  "dataset": "$DATASET"
}
EOF
echo ""
echo "Saved your settings to $CONFIG_FILE"

# ── Generate config files from templates ──────────────────────
#
# Templates live in templates/ with __PLACEHOLDER__ tokens.
# We copy each template to its target location, replacing
# placeholders with the user's values. No reverse replacement
# needed — we always start fresh from the template.

echo "Configuring project files from templates..."

# Ensure dataset app directory exists
mkdir -p "src/app/$DATASET"

# template_source -> target_destination
declare -a TEMPLATES=(
  "templates/databricks.yml|databricks.yml"
  "templates/genie_app.yml|resources/genie_app.yml"
  "templates/pipeline_job.yml|resources/pipeline_job.yml"
  "templates/${DATASET}/app.py|src/app/${DATASET}/app.py"
  "templates/${DATASET}/app.yaml|src/app/${DATASET}/app.yaml"
  "templates/CLAUDE.md|CLAUDE.md"
  "templates/README.md|README.md"
)

for entry in "${TEMPLATES[@]}"; do
  src="${entry%%|*}"
  dst="${entry##*|}"
  if [[ ! -f "$src" ]]; then
    echo "  WARNING: Template not found: $src"
    continue
  fi
  # Copy template and replace placeholders
  sed \
    -e "s|__PROFILE__|${PROFILE}|g" \
    -e "s|__WORKSPACE_URL__|${WORKSPACE_URL}|g" \
    -e "s|__CATALOG__|${CATALOG}|g" \
    -e "s|__SCHEMA__|${SCHEMA}|g" \
    -e "s|__WAREHOUSE_ID__|${WAREHOUSE_ID}|g" \
    -e "s|__VOLUME_NAME__|${VOLUME_NAME}|g" \
    -e "s|__GENIE_SPACE_ID__|${GENIE_SPACE_ID}|g" \
    -e "s|__APP_NAME__|${APP_NAME}|g" \
    -e "s|__DATASET__|${DATASET}|g" \
    "$src" > "$dst"
  echo "  $src -> $dst"
done

# Clear cached bundle state (may point to old workspace)
rm -rf .databricks/ .databricks-resources.json 2>/dev/null || true

echo "Done!"

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
  echo "  databricks bundle run data_pipeline"
  echo "  databricks bundle run ask_genie"
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
echo "  Running: databricks bundle run data_pipeline"
echo "  (this may take a few minutes)"
echo ""
databricks bundle run data_pipeline

echo ""
echo "Step 3/3 — Starting the web app..."
echo "  Running: databricks bundle run ask_genie"
echo ""
databricks bundle run ask_genie

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
echo "      databricks bundle run ask_genie"
echo ""
echo "    Re-run the data pipeline:"
echo "      databricks bundle run data_pipeline"
echo ""
echo "    Remove everything from your workspace:"
echo "      databricks bundle destroy --auto-approve"
echo ""
echo "══════════════════════════════════════════════════════════"
echo ""
