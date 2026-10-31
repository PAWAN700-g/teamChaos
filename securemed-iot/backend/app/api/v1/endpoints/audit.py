"""SecureMed IoT - Audit Ledger Verification & External Anchoring Endpoints.

Implements:
1. Retrieval of full SHA-256 tamper-evident audit ledger chain.
2. Cryptographic audit chain verification (detects modified records, dropped blocks, parent hash corruption).
3. External Anchoring Export (SHA-256 anchoring digest of current ledger state).
4. Explicit disclosure of the fundamental limitation of local hash chains against full-database recomputation.
5. Strict restriction against client audit writes (read-only for clients; appended only by trusted backend).
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone

from app.core.session_manager import security_manager

router = APIRouter()


class AuditVerificationResponse(BaseModel):
    is_intact: bool
    total_blocks_verified: int
    head_hash: str
    genesis_hash: str
    message: str
    corrupted_block: Optional[Dict[str, Any]] = None
    verified_at: str
    limitation_disclosure: str


class ExternalAnchoringResponse(BaseModel):
    audit_head_hash: str
    chain_length: int
    latest_event_id: str
    latest_timestamp: str
    anchoring_digest: str
    anchoring_format: str
    anchored_at: str
    limitation_disclosure: str


@router.get("/ledger", summary="Get Tamper-Evident Audit Ledger Chain")
async def get_audit_ledger():
    """Retrieve full chronological audit ledger chain with SHA-256 parent hashes."""
    return {
        "audit_head_hash": security_manager.audit_head_hash,
        "chain_length": len(security_manager.audit_log_chain),
        "events": security_manager.audit_log_chain,
    }


@router.get("/verify", response_model=AuditVerificationResponse, summary="Verify Cryptographic Hash-Chain Integrity")
async def verify_audit_ledger_integrity():
    """
    Cryptographically iterates through every block in the audit ledger from genesis:
    1. Verifies parent hash link continuity.
    2. Recomputes SHA-256 digest from canonical block content (event_id, actor, event_type, result, details).
    3. Detects any tampered, modified, or out-of-order blocks.
    4. Documents the limitation regarding whole-database rewriting.
    """
    is_intact, message, failure_info = security_manager.verify_audit_chain(include_details=True)
    anchoring_info = security_manager.get_anchoring_digest()

    return AuditVerificationResponse(
        is_intact=is_intact,
        total_blocks_verified=len(security_manager.audit_log_chain),
        head_hash=security_manager.audit_head_hash,
        genesis_hash="GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000",
        message=message,
        corrupted_block=failure_info,
        verified_at=datetime.now(timezone.utc).isoformat(),
        limitation_disclosure=anchoring_info["limitation_disclosure"],
    )


@router.get("/anchor", response_model=ExternalAnchoringResponse, summary="Export Latest Hash for External Anchoring")
async def export_anchoring_digest():
    """
    Exports cryptographic anchoring digest of the current tip of the audit chain.
    Intended for periodic publication to an external immutable ledger or RFC 3161 TSA
    to detect complete database rewriting attacks.
    """
    return ExternalAnchoringResponse(**security_manager.get_anchoring_digest())
