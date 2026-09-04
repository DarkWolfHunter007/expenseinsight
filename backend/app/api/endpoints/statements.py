import os
import shutil
import uuid
from typing import List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import Statement, Transaction, User
from ...models.schemas import StatementResponse, StatementStatusResponse
from ...services.statement_processor import StatementProcessor
from ..deps import get_current_user
from pathlib import Path

router = APIRouter()

BACKEND_DIR = Path(__file__).resolve().parents[3]
UPLOAD_DIR = str(BACKEND_DIR / "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload", response_model=List[StatementResponse])
async def upload_statements(
    files: List[UploadFile] = File(...),
    background_tasks: BackgroundTasks = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Uploads one or more bank statement PDFs and initiates the 7-stage processing pipeline.
    """
    if not files:
        raise HTTPException(status_code=400, detail="No files uploaded.")

    saved_statements = []
    processor = StatementProcessor(db=db)

    for file in files:
        if not file.filename.lower().endswith(".pdf"):
            continue

        file_id = str(uuid.uuid4())
        safe_filename = f"{file_id}_{file.filename}"
        file_path = os.path.join(UPLOAD_DIR, safe_filename)

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        stmt = Statement(
            id=file_id,
            user_id=current_user.id,
            file_name=file.filename,
            file_path=file_path,
            processing_status="uploaded",
            processing_step="Uploaded",
            processing_progress=0.0
        )
        db.add(stmt)
        db.commit()
        db.refresh(stmt)

        # Process synchronously or via background task
        try:
            processor.process_statement(statement_id=stmt.id, file_path_or_bytes=file_path)
            db.refresh(stmt)
        except Exception as e:
            print(f"Error processing statement {file.filename}: {e}")

        saved_statements.append(stmt)

    if not saved_statements:
        raise HTTPException(status_code=400, detail="Please upload valid PDF statement files.")

    return saved_statements


@router.get("", response_model=List[StatementResponse])
def list_statements(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Lists all statements uploaded by the user."""
    return db.query(Statement).filter(Statement.user_id == current_user.id).order_by(Statement.created_at.desc()).all()


@router.get("/{statement_id}", response_model=StatementResponse)
def get_statement(
    statement_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieves a single statement by ID."""
    stmt = db.query(Statement).filter(Statement.id == statement_id, Statement.user_id == current_user.id).first()
    if not stmt:
        raise HTTPException(status_code=404, detail="Statement not found.")
    return stmt


@router.get("/{statement_id}/status", response_model=StatementStatusResponse)
def get_statement_status(
    statement_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Returns processing status, active step, and completed steps for UI progress stepper (PRD Section 34)."""
    stmt = db.query(Statement).filter(Statement.id == statement_id, Statement.user_id == current_user.id).first()
    if not stmt:
        raise HTTPException(status_code=404, detail="Statement not found.")

    all_steps = [
        "Reading PDF document",
        "Extracting transactions",
        "Cleaning transaction descriptions",
        "Normalizing merchants & AI Categorization",
        "Building spending analysis",
        "Generating expense forecast",
        "Completed"
    ]

    completed = []
    if stmt.processing_progress >= 0.15:
        completed.append(all_steps[0])
    if stmt.processing_progress >= 0.35:
        completed.append(all_steps[1])
    if stmt.processing_progress >= 0.50:
        completed.append(all_steps[2])
    if stmt.processing_progress >= 0.65:
        completed.append(all_steps[3])
    if stmt.processing_progress >= 0.85:
        completed.append(all_steps[4])
    if stmt.processing_progress >= 0.95:
        completed.append(all_steps[5])
    if stmt.processing_status == "completed":
        completed.append(all_steps[6])

    return {
        "statement_id": stmt.id,
        "status": stmt.processing_status,
        "step": stmt.processing_step,
        "progress": stmt.processing_progress,
        "total_transactions": stmt.total_transactions,
        "completed_steps": completed
    }


@router.delete("/{statement_id}")
def delete_statement(
    statement_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Deletes statement and associated transactions."""
    stmt = db.query(Statement).filter(Statement.id == statement_id, Statement.user_id == current_user.id).first()
    if not stmt:
        raise HTTPException(status_code=404, detail="Statement not found.")

    if stmt.file_path and os.path.exists(stmt.file_path):
        try:
            os.remove(stmt.file_path)
        except Exception:
            pass

    db.delete(stmt)
    db.commit()
    return {"status": "success", "message": "Statement and associated data deleted."}


@router.post("/seed-sample", response_model=StatementResponse)
def seed_sample_statement(
    bank: str = "HDFC Bank",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    1-Click Ingestion of a realistic 6-month sample bank statement for instant testing.
    """
    sample_dir = str(BACKEND_DIR / "sample_statements")
    
    bank_files = {
        "HDFC Bank": "HDFC_6_Month_Statement_2026.pdf",
        "State Bank of India": "SBI_6_Month_Statement_2026.pdf",
        "ICICI Bank": "ICICI_6_Month_Statement_2026.pdf"
    }
    filename = bank_files.get(bank, "HDFC_6_Month_Statement_2026.pdf")
    sample_path = os.path.join(sample_dir, filename)

    if not os.path.exists(sample_path):
        from scripts.generate_sample_statements import generate_all_samples
        generate_all_samples()

    file_id = str(uuid.uuid4())
    dest_path = os.path.join(UPLOAD_DIR, f"{file_id}_{filename}")
    shutil.copyfile(sample_path, dest_path)

    stmt = Statement(
        id=file_id,
        user_id=current_user.id,
        file_name=filename,
        file_path=dest_path,
        bank_name=bank,
        processing_status="uploaded",
        processing_step="Uploaded",
        processing_progress=0.0
    )
    db.add(stmt)
    db.commit()
    db.refresh(stmt)

    processor = StatementProcessor(db=db)
    processor.process_statement(statement_id=stmt.id, file_path_or_bytes=dest_path)
    db.refresh(stmt)
    return stmt
