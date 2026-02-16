"""FrostByte Printer Service - Direct PNG printing to Brother QL printers.

Labels are now rendered client-side in Elm. This service receives pre-rendered
PNG images and sends them directly to the printer.
"""

import base64
import multiprocessing
import os
import tempfile
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="FrostByte Printer Service", version="2.0.0")

# Configuration from environment variables
DRY_RUN = os.getenv("DRY_RUN", "true").lower() == "true"
PRINTER_MODEL = os.getenv("PRINTER_MODEL", "QL-700")
PRINTER_TAPE = os.getenv("PRINTER_TAPE", "62")
LABELS_OUTPUT_DIR = Path("/app/labels_output")


class PrintRequest(BaseModel):
    """Request model for label printing with pre-rendered PNG."""
    image_data: str  # Base64-encoded PNG image
    label_type: str  # Brother QL label identifier (e.g., "62", "29x90", "d24")


def _print_worker(image_path: str, label_type: str, printer_model: str, printer_uri: str, error_queue):
    """Worker function that runs in a subprocess with fresh USB state."""
    try:
        from brother_ql.conversion import convert
        from brother_ql.backends.helpers import send
        from brother_ql.raster import BrotherQLRaster

        qlr = BrotherQLRaster(printer_model)
        instructions = convert(
            qlr=qlr,
            images=[image_path],
            label=label_type,
            rotate="auto",
            threshold=70,
            dither=False,
            compress=False,
            red=False,
            dpi_600=False,
            hq=True,
            cut=True,
        )
        send(
            instructions=instructions,
            printer_identifier=printer_uri,
            backend_identifier="pyusb"
        )
    except Exception as e:
        error_queue.put(str(e))


def print_to_brother_ql(image_path: str, label_type: str) -> None:
    """Send PNG image to Brother QL printer.

    Runs in a subprocess so that libusb/pyusb always gets fresh USB
    device state — avoids stale handles after printer standby/wake.
    """
    printer_uri = os.getenv("BROTHER_QL_PRINTER", "usb://0x04f9:0x209b")
    error_queue = multiprocessing.Queue()
    proc = multiprocessing.Process(
        target=_print_worker,
        args=(image_path, label_type, PRINTER_MODEL, printer_uri, error_queue),
    )
    proc.start()
    proc.join(timeout=30)
    if proc.is_alive():
        proc.kill()
        raise RuntimeError("Printing timed out")
    if proc.exitcode != 0:
        if not error_queue.empty():
            raise RuntimeError(error_queue.get())
        raise RuntimeError(f"Print worker exited with code {proc.exitcode}")
    if not error_queue.empty():
        raise RuntimeError(error_queue.get())


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "dry_run": DRY_RUN,
        "version": "2.0.0"
    }


@app.post("/print")
async def print_label(request: PrintRequest):
    """Print a pre-rendered PNG label.

    Accepts a base64-encoded PNG image and either:
    - Saves it to disk (dry-run mode)
    - Sends it to the Brother QL printer
    """
    try:
        # Decode base64 PNG
        image_bytes = base64.b64decode(request.image_data)

        if DRY_RUN:
            # Save to file instead of printing
            LABELS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            filename = f"label_{request.label_type}_{timestamp}.png"
            filepath = LABELS_OUTPUT_DIR / filename

            with open(filepath, "wb") as f:
                f.write(image_bytes)

            return {
                "status": "success",
                "message": f"Label saved to {filepath} (dry run mode)",
                "dry_run": True,
                "filename": filename
            }
        else:
            # Write to temp file and print
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
                f.write(image_bytes)
                temp_path = f.name

            try:
                print_to_brother_ql(temp_path, request.label_type)
            finally:
                # Clean up temp file
                Path(temp_path).unlink(missing_ok=True)

            return {
                "status": "success",
                "message": "Label sent to printer",
                "dry_run": False
            }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to print label: {str(e)}")


@app.get("/")
async def root():
    """Root endpoint with service info."""
    return {
        "service": "FrostByte Printer Service",
        "version": "2.0.0",
        "dry_run": DRY_RUN,
        "printer_model": PRINTER_MODEL,
        "tape_size": PRINTER_TAPE,
        "note": "Labels are rendered client-side. This service accepts pre-rendered PNG images."
    }
