"""
J&J MedTech Sales Genie App - FastAPI Backend + Static React Frontend
"""

import os
import json
import time
import asyncio
import logging

from fastapi import FastAPI, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional
from databricks.sdk import WorkspaceClient
from databricks.sdk.core import Config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="J&J MedTech Sales Genie App")

GENIE_SPACE_ID = os.getenv("GENIE_SPACE_ID", "01f12fb14eb21d5e9864032b2d13316f")
WAREHOUSE_ID = os.getenv("DATABRICKS_WAREHOUSE_ID", "a1119b437a4a8d45")


def get_workspace_client() -> WorkspaceClient:
    """Get workspace client using app auth (service principal)."""
    return WorkspaceClient(config=Config())


class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None
    sql: Optional[str] = None
    data: Optional[list] = None
    columns: Optional[list] = None


@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, request: Request):
    """Send a message to the Genie space via direct REST API calls."""
    import httpx

    try:
        cfg = Config()
        host = (cfg.host or "").rstrip("/")
        sp_headers = cfg.authenticate()
        headers = {**sp_headers, "Content-Type": "application/json"}
        base = f"{host}/api/2.0/genie/spaces/{GENIE_SPACE_ID}"

        async with httpx.AsyncClient(timeout=120) as client:
            # 1) Start conversation or send follow-up
            if req.conversation_id:
                r = await client.post(
                    f"{base}/conversations/{req.conversation_id}/messages",
                    headers=headers,
                    json={"content": req.message},
                )
            else:
                r = await client.post(
                    f"{base}/start-conversation",
                    headers=headers,
                    json={"content": req.message},
                )
            r.raise_for_status()
            resp_data = r.json()

            conversation_id = resp_data.get("conversation_id", req.conversation_id)
            message_id = resp_data.get("message_id") or resp_data.get("id")

            # 2) Poll for message completion
            msg_data = {}
            if message_id and conversation_id:
                for _ in range(45):
                    await asyncio.sleep(3)
                    try:
                        mr = await client.get(
                            f"{base}/conversations/{conversation_id}/messages/{message_id}",
                            headers=headers,
                        )
                        msg_data = mr.json()
                        status = msg_data.get("status", "")
                        if status in ("COMPLETED", "FAILED", "CANCELLED"):
                            break
                    except Exception:
                        continue

            # 3) Parse response
            logger.info(f"Genie response status: {msg_data.get('status')}")
            logger.info(f"Genie response keys: {list(msg_data.keys())}")
            logger.info(f"Genie attachments count: {len(msg_data.get('attachments', []))}")
            if msg_data.get('error'):
                logger.error(f"Genie error: {msg_data['error']}")
            if msg_data.get('attachments'):
                for i, att in enumerate(msg_data['attachments']):
                    logger.info(f"Attachment {i} keys: {list(att.keys())}")
            reply_text = ""
            sql_query = None
            result_data = None
            result_columns = None

            for att in msg_data.get("attachments", []):
                text_obj = att.get("text")
                if text_obj and text_obj.get("content"):
                    reply_text += text_obj["content"]

                query_obj = att.get("query")
                if query_obj:
                    sql_query = query_obj.get("query")
                    desc = query_obj.get("description")
                    if desc:
                        reply_text += f"\n\n{desc}"

                    # 4) Fetch query results
                    if query_obj.get("statement_id"):
                        try:
                            qr = await client.get(
                                f"{base}/conversations/{conversation_id}/messages/{message_id}/query-result",
                                headers=headers,
                            )
                            qr_data = qr.json()
                            stmt = qr_data.get("statement_response", {})
                            cols = stmt.get("manifest", {}).get("schema", {}).get("columns", [])
                            if cols:
                                result_columns = [c.get("name", "") for c in cols]
                            da = stmt.get("result", {}).get("data_array", [])
                            if da:
                                result_data = [list(row) for row in da]
                        except Exception as e:
                            logger.warning(f"Could not fetch query result: {e}")

            if not reply_text and result_data and result_columns:
                reply_text = "Here are the results:"

            if result_data and result_columns and len(result_data) > 0:
                table_md = "\n\n| " + " | ".join(result_columns) + " |\n"
                table_md += "| " + " | ".join(["---"] * len(result_columns)) + " |\n"
                for row in result_data[:50]:
                    table_md += "| " + " | ".join(str(v) if v is not None else "" for v in row) + " |\n"
                reply_text += table_md

            if not reply_text:
                reply_text = "I wasn't able to generate a response. Could you try rephrasing?"

            return ChatResponse(
                reply=reply_text,
                conversation_id=conversation_id,
                message_id=message_id,
                sql=sql_query,
                data=result_data,
                columns=result_columns,
            )
    except httpx.HTTPStatusError as e:
        logger.error(f"Chat API error: {e.response.status_code} {e.response.text}")
        raise HTTPException(status_code=500, detail=e.response.text)
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class FeedbackRequest(BaseModel):
    conversation_id: str
    message_id: str
    rating: str  # POSITIVE, NEGATIVE, or NONE


@app.post("/api/feedback")
async def feedback(req: FeedbackRequest):
    """Send feedback on a Genie message."""
    import httpx

    try:
        cfg = Config()
        host = (cfg.host or "").rstrip("/")
        sp_headers = cfg.authenticate()
        headers = {**sp_headers, "Content-Type": "application/json"}

        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(
                f"{host}/api/2.0/genie/spaces/{GENIE_SPACE_ID}/conversations/{req.conversation_id}/messages/{req.message_id}/feedback",
                headers=headers,
                json={"rating": req.rating},
            )
            r.raise_for_status()
            return {"status": "ok", "rating": req.rating}
    except Exception as e:
        logger.error(f"Feedback error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/health")
async def health():
    return {"status": "healthy", "genie_space_id": GENIE_SPACE_ID}


@app.get("/api/dashboard")
async def dashboard_data():
    """Fetch dashboard KPI and chart data from the tables."""
    try:
        w = get_workspace_client()

        def run_query(query):
            """Execute SQL via statement execution API and return list of dicts."""
            resp = w.statement_execution.execute_statement(
                warehouse_id=WAREHOUSE_ID,
                statement=query,
                wait_timeout="50s",
            )
            if not resp.result or not resp.manifest:
                return []
            cols = [c.name for c in resp.manifest.schema.columns]
            rows = []
            for row in (resp.result.data_array or []):
                d = {}
                for i, col in enumerate(cols):
                    val = row[i]
                    # Try to convert numeric strings
                    if val is not None:
                        try:
                            val = float(val)
                            if val == int(val):
                                val = int(val)
                        except (ValueError, TypeError):
                            pass
                    d[col] = val
                rows.append(d)
            return rows

        kpis = run_query("SELECT SUM(opportunity) AS total_opportunity, SUM(rolling_12_sales) AS total_rolling_12_sales, COUNT(DISTINCT account) AS total_accounts, SUM(total_units_sold) AS total_units FROM jnj_medtech.sales.account_targeting")
        opp_by_product = run_query("SELECT product_line, SUM(opportunity) AS total_opportunity FROM jnj_medtech.sales.account_targeting GROUP BY product_line ORDER BY total_opportunity DESC")
        opp_by_target = run_query("SELECT target_type, SUM(opportunity) AS total_opportunity FROM jnj_medtech.sales.account_targeting GROUP BY target_type ORDER BY total_opportunity DESC")
        top_accounts = run_query("SELECT account, SUM(opportunity) AS total_opportunity, SUM(rolling_12_sales) AS total_rolling_12_sales, ROUND(AVG(penetration_2025)*100, 1) AS avg_penetration FROM jnj_medtech.sales.account_targeting GROUP BY account ORDER BY total_opportunity DESC LIMIT 10")
        opp_by_area = run_query("SELECT area, SUM(opportunity) AS total_opportunity FROM jnj_medtech.sales.account_targeting GROUP BY area ORDER BY total_opportunity DESC")
        vol_by_specialty = run_query("SELECT specialty, SUM(cy_procedure_volume) AS total_volume FROM jnj_medtech.sales.hcp_procedure_volume GROUP BY specialty ORDER BY total_volume DESC")
        top_surgeons = run_query("SELECT surgeon_name, cy_procedure_volume, specialty FROM jnj_medtech.sales.hcp_procedure_volume ORDER BY cy_procedure_volume DESC LIMIT 8")

        return {
            "kpis": kpis[0] if kpis else {},
            "opp_by_product": opp_by_product,
            "opp_by_target": opp_by_target,
            "top_accounts": top_accounts,
            "opp_by_area": opp_by_area,
            "vol_by_specialty": vol_by_specialty,
            "top_surgeons": top_surgeons,
        }
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Serve React static files
static_dir = os.path.join(os.path.dirname(__file__), "frontend", "build")
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=os.path.join(static_dir, "static")), name="static")

    @app.get("/{full_path:path}")
    async def serve_react(full_path: str):
        file_path = os.path.join(static_dir, full_path)
        if os.path.isfile(file_path):
            return FileResponse(file_path)
        return FileResponse(os.path.join(static_dir, "index.html"))
else:
    # Serve inline HTML when no React build exists
    @app.get("/{full_path:path}")
    async def serve_inline(full_path: str):
        if full_path.startswith("api/"):
            raise HTTPException(status_code=404)
        return FileResponse(
            os.path.join(os.path.dirname(__file__), "index.html"),
            media_type="text/html",
        )
