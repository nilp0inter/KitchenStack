"""FrostByte Printer Service - Label generation for Brother QL printers."""

import io
import os
from datetime import datetime
from pathlib import Path

import segno
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import Response
from PIL import Image, ImageDraw, ImageFont
from pydantic import BaseModel

app = FastAPI(title="FrostByte Printer Service", version="1.0.0")

# Configuration from environment variables
DRY_RUN = os.getenv("DRY_RUN", "true").lower() == "true"
APP_HOST = os.getenv("APP_HOST", "localhost")
PRINTER_MODEL = os.getenv("PRINTER_MODEL", "QL-700")
PRINTER_TAPE = os.getenv("PRINTER_TAPE", "62")
LABELS_OUTPUT_DIR = Path("/app/labels_output")


class PrintRequest(BaseModel):
    """Request model for label printing.

    Each label represents a single portion with its own unique ID.
    """
    id: str
    name: str
    ingredients: str
    container: str
    expiry_date: str


def generate_qr_code(url: str, size: int = 150) -> Image.Image:
    """Generate a QR code image for the given URL."""
    qr = segno.make(url, error="H")
    buffer = io.BytesIO()
    qr.save(buffer, kind="png", scale=5, border=1)
    buffer.seek(0)
    qr_image = Image.open(buffer)
    qr_image = qr_image.convert("RGB")
    qr_image = qr_image.resize((size, size), Image.Resampling.LANCZOS)
    return qr_image


def create_label_image(data: PrintRequest) -> Image.Image:
    """Create a label image with item information and QR code.

    Label layout for 62mm continuous tape (696 pixels wide):
    - Left side: Text information
    - Right side: QR code
    """
    # Label dimensions for 62mm tape (696px width, variable height)
    label_width = 696
    label_height = 300
    padding = 20
    qr_size = 200

    # Create white background
    label = Image.new("RGB", (label_width, label_height), "white")
    draw = ImageDraw.Draw(label)

    # Use default font (PIL's built-in)
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48)
        font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 32)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
    except OSError:
        # Fallback to default font if DejaVu not available
        font_title = ImageFont.load_default()
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()

    # Text area width (label width - QR code area - padding)
    text_area_width = label_width - qr_size - (padding * 3)

    # Draw item name (large title, truncate if too long)
    name_text = data.name
    if len(name_text) > 18:
        name_text = name_text[:15] + "..."
    draw.text((padding, padding), name_text, fill="black", font=font_title)

    # Draw ingredients
    ingredients_text = data.ingredients
    if len(ingredients_text) > 45:
        ingredients_text = ingredients_text[:42] + "..."
    draw.text((padding, padding + 60), ingredients_text, fill="gray", font=font_small)

    # Draw expiry date
    try:
        expiry = datetime.fromisoformat(data.expiry_date.replace("Z", "+00:00"))
        expiry_str = expiry.strftime("%d/%m/%Y")
    except ValueError:
        expiry_str = data.expiry_date

    # Draw expiry with label
    draw.text((padding, padding + 100), "Caduca:", fill="black", font=font_small)
    draw.text((padding, padding + 125), expiry_str, fill="black", font=font_large)

    # Generate and paste QR code
    qr_url = f"https://{APP_HOST}/item/{data.id}"
    qr_image = generate_qr_code(qr_url, qr_size)
    qr_x = label_width - qr_size - padding
    qr_y = (label_height - qr_size) // 2
    label.paste(qr_image, (qr_x, qr_y))

    return label


def print_to_brother_ql(label_image: Image.Image) -> None:
    """Send label image to Brother QL printer."""
    from brother_ql.conversion import convert
    from brother_ql.backends.helpers import send
    from brother_ql.raster import BrotherQLRaster

    # Create raster data
    qlr = BrotherQLRaster(PRINTER_MODEL)

    # Convert image to raster instructions
    instructions = convert(
        qlr=qlr,
        images=[label_image],
        label=PRINTER_TAPE,
        rotate="auto",
        threshold=70,
        dither=False,
        compress=False,
        red=False,
        dpi_600=False,
        hq=True,
        cut=True,
    )

    # Find and send to printer (assumes USB connection)
    # This will need to be configured based on actual printer setup
    send(instructions=instructions, printer_identifier="usb://0x04f9:0x2042", backend_identifier="pyusb")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "dry_run": DRY_RUN}


@app.post("/print")
async def print_label(request: PrintRequest):
    """Generate and print a label for the given item data."""
    try:
        # Generate label image
        label_image = create_label_image(request)

        if DRY_RUN:
            # Save to file instead of printing
            LABELS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"label_{request.id}_{timestamp}.png"
            filepath = LABELS_OUTPUT_DIR / filename
            label_image.save(filepath, "PNG")

            return {
                "status": "success",
                "message": f"Label saved to {filepath} (dry run mode)",
                "dry_run": True,
                "filename": filename
            }
        else:
            # Send to physical printer
            print_to_brother_ql(label_image)

            return {
                "status": "success",
                "message": "Label sent to printer",
                "dry_run": False
            }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to print label: {str(e)}")


@app.get("/preview")
async def preview_label(
    id: str = Query(..., description="Portion UUID"),
    name: str = Query(..., description="Item name"),
    ingredients: str = Query("", description="Ingredients list"),
    container: str = Query(..., description="Container type"),
    expiry_date: str = Query(..., description="Expiry date in ISO format"),
):
    """Generate a label preview image without printing.

    Returns the label as a PNG image for display in the UI.
    """
    try:
        request = PrintRequest(
            id=id,
            name=name,
            ingredients=ingredients,
            container=container,
            expiry_date=expiry_date,
        )
        label_image = create_label_image(request)

        buffer = io.BytesIO()
        label_image.save(buffer, format="PNG")
        buffer.seek(0)

        return Response(
            content=buffer.getvalue(),
            media_type="image/png",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate preview: {str(e)}")


@app.get("/")
async def root():
    """Root endpoint with service info."""
    return {
        "service": "FrostByte Printer Service",
        "version": "1.0.0",
        "dry_run": DRY_RUN,
        "printer_model": PRINTER_MODEL,
        "tape_size": PRINTER_TAPE
    }
