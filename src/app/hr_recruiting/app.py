"""
J&J HR Recruiting Genie App - FastAPI Backend + Static React Frontend
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

app = FastAPI(title="J&J HR Recruiting Genie App")

GENIE_SPACE_ID = os.getenv("GENIE_SPACE_ID", "01f0b40597a9152c935ddb6a25d08f59")
WAREHOUSE_ID = os.getenv("DATABRICKS_WAREHOUSE_ID", "796f36d00b204fb6")


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
    """Fetch dashboard KPI and chart data from the HR recruiting tables."""
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

        kpis_candidates = run_query("SELECT COUNT(*) AS total_candidates, SUM(CASE WHEN stage = 'Hired' THEN 1 ELSE 0 END) AS total_positions_filled FROM medtech.sales.candidate_pipeline")
        kpis_metrics = run_query("SELECT ROUND(AVG(avg_time_to_fill_days), 1) AS avg_time_to_fill, ROUND(AVG(offer_acceptance_rate) * 100, 1) AS avg_offer_acceptance_rate FROM medtech.sales.hiring_metrics")
        kpis = [{**(kpis_candidates[0] if kpis_candidates else {}), **(kpis_metrics[0] if kpis_metrics else {})}]
        candidates_by_stage = run_query("SELECT stage, COUNT(*) AS candidate_count FROM medtech.sales.candidate_pipeline GROUP BY stage ORDER BY candidate_count DESC")
        candidates_by_source = run_query("SELECT source, COUNT(*) AS candidate_count FROM medtech.sales.candidate_pipeline GROUP BY source ORDER BY candidate_count DESC")
        positions_by_department = run_query("SELECT department, SUM(headcount_needed) AS position_count FROM medtech.sales.job_requisitions GROUP BY department ORDER BY position_count DESC")
        top_recruiters = run_query("SELECT recruiter_id AS recruiter_name, SUM(positions_filled) AS positions_filled FROM medtech.sales.hiring_metrics GROUP BY recruiter_id ORDER BY positions_filled DESC LIMIT 10")
        pipeline_by_bu = run_query("SELECT business_unit, COUNT(*) AS candidate_count FROM medtech.sales.candidate_pipeline GROUP BY business_unit ORDER BY candidate_count DESC")
        cost_per_hire_by_dept = run_query("SELECT department, ROUND(AVG(cost_per_hire), 0) AS avg_cost_per_hire FROM medtech.sales.hiring_metrics GROUP BY department ORDER BY avg_cost_per_hire DESC")

        return {
            "kpis": kpis[0] if kpis else {},
            "candidates_by_stage": candidates_by_stage,
            "candidates_by_source": candidates_by_source,
            "positions_by_department": positions_by_department,
            "top_recruiters": top_recruiters,
            "pipeline_by_bu": pipeline_by_bu,
            "cost_per_hire_by_dept": cost_per_hire_by_dept,
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
