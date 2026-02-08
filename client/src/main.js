import './main.css'
import { Elm } from './Main.elm'

// Font embedding for SVG to PNG conversion
// Web fonts loaded via CSS are not available when SVG is serialized to a blob.
// We fetch the font files and embed them as base64 data URLs.
let fontCache = null

async function loadFontAsBase64(url, mimeType) {
  const response = await fetch(url)
  const arrayBuffer = await response.arrayBuffer()
  const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))
  return `data:${mimeType};base64,${base64}`
}

async function ensureFontsLoaded() {
  if (fontCache) return fontCache

  // Fetch font files and convert to base64 data URLs
  const [regularData, boldData] = await Promise.all([
    loadFontAsBase64('https://fonts.gstatic.com/s/atkinsonhyperlegible/v12/9Bt23C1KxNDXMspQ1lPyU89-1h6ONRlW45GE5Q.ttf', 'font/ttf'),
    loadFontAsBase64('https://fonts.gstatic.com/s/atkinsonhyperlegible/v12/9Bt73C1KxNDXMspQ1lPyU89-1h6ONRlW45G8WbcNcw.ttf', 'font/ttf')
  ])

  // Also register fonts with document.fonts for canvas text measurement
  const regularFont = new FontFace('Atkinson Hyperlegible', `url(${regularData})`, { weight: '400' })
  const boldFont = new FontFace('Atkinson Hyperlegible', `url(${boldData})`, { weight: '700' })

  await Promise.all([regularFont.load(), boldFont.load()])
  document.fonts.add(regularFont)
  document.fonts.add(boldFont)

  fontCache = { regular: regularData, bold: boldData }
  return fontCache
}

function embedFontsInSvg(svgElement, fonts) {
  const styleElement = document.createElementNS('http://www.w3.org/2000/svg', 'style')
  styleElement.textContent = `
    @font-face {
      font-family: 'Atkinson Hyperlegible';
      font-weight: 400;
      src: url('${fonts.regular}') format('truetype');
    }
    @font-face {
      font-family: 'Atkinson Hyperlegible';
      font-weight: 700;
      src: url('${fonts.bold}') format('truetype');
    }
  `
  svgElement.insertBefore(styleElement, svgElement.firstChild)
}

// Preload fonts at startup
ensureFontsLoaded().catch(e => console.warn('Font preload failed:', e))

// Initialize Elm application
const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    currentDate: new Date().toISOString().split('T')[0],
    appHost: window.location.host
  }
})

// SVG to PNG conversion port
// When rotate=true: SVG is rendered with swapped dimensions (landscape display),
// then rotated 90° clockwise for the printer-expected portrait orientation.
// When rotate=false: SVG is rendered directly at width×height with no rotation.
app.ports.requestSvgToPng.subscribe(async ({ svgId, requestId, width, height, rotate }) => {
  try {
    // Wait for next frame to ensure SVG is rendered
    await new Promise(resolve => requestAnimationFrame(resolve))

    const svgElement = document.getElementById(svgId)
    if (!svgElement) {
      app.ports.receivePngResult.send({
        requestId,
        dataUrl: null,
        error: 'SVG element not found: ' + svgId
      })
      return
    }

    // Clone SVG to avoid modifying the displayed element
    const svgClone = svgElement.cloneNode(true)

    // Ensure fonts are loaded and embed into the clone
    const fonts = await ensureFontsLoaded()
    embedFontsInSvg(svgClone, fonts)

    // Ensure SVG has proper dimensions and namespace
    const svgWidth = svgClone.getAttribute('width') || width
    const svgHeight = svgClone.getAttribute('height') || height
    svgClone.setAttribute('width', svgWidth)
    svgClone.setAttribute('height', svgHeight)
    svgClone.setAttribute('xmlns', 'http://www.w3.org/2000/svg')

    // Serialize SVG to string
    const serializer = new XMLSerializer()
    const svgString = serializer.serializeToString(svgClone)

    // Use base64 encoding for better compatibility
    const base64 = btoa(unescape(encodeURIComponent(svgString)))
    const url = `data:image/svg+xml;base64,${base64}`

    // Load SVG as image
    const img = new Image()
    img.onload = () => {
      let dataUrl

      if (rotate) {
        // Display dimensions (swapped for landscape)
        const displayWidth = height
        const displayHeight = width

        // Create canvas at display dimensions (landscape)
        const canvas = document.createElement('canvas')
        canvas.width = displayWidth
        canvas.height = displayHeight
        const ctx = canvas.getContext('2d')

        // White background
        ctx.fillStyle = 'white'
        ctx.fillRect(0, 0, displayWidth, displayHeight)

        // Draw SVG image in landscape
        ctx.drawImage(img, 0, 0, displayWidth, displayHeight)

        // Rotate 90° clockwise for print output (back to width×height)
        const rotatedCanvas = document.createElement('canvas')
        rotatedCanvas.width = width
        rotatedCanvas.height = height
        const rotatedCtx = rotatedCanvas.getContext('2d')

        // White background on rotated canvas
        rotatedCtx.fillStyle = 'white'
        rotatedCtx.fillRect(0, 0, width, height)

        // Rotate 90° clockwise: translate to right edge, then rotate
        rotatedCtx.translate(width, 0)
        rotatedCtx.rotate(Math.PI / 2)
        rotatedCtx.drawImage(canvas, 0, 0)

        dataUrl = rotatedCanvas.toDataURL('image/png')
      } else {
        // No rotation: render directly at width×height
        const canvas = document.createElement('canvas')
        canvas.width = width
        canvas.height = height
        const ctx = canvas.getContext('2d')

        // White background
        ctx.fillStyle = 'white'
        ctx.fillRect(0, 0, width, height)

        // Draw SVG image
        ctx.drawImage(img, 0, 0, width, height)

        dataUrl = canvas.toDataURL('image/png')
      }

      app.ports.receivePngResult.send({
        requestId,
        dataUrl,
        error: null
      })
    }

    img.onerror = () => {
      app.ports.receivePngResult.send({
        requestId,
        dataUrl: null,
        error: 'Failed to load SVG as image'
      })
    }

    img.src = url
  } catch (e) {
    app.ports.receivePngResult.send({
      requestId,
      dataUrl: null,
      error: e.message
    })
  }
})

// Text measurement port for dynamic font sizing and word wrapping
app.ports.requestTextMeasure.subscribe(({
  requestId,
  titleText,
  ingredientsText,
  fontFamily,
  titleFontSize,
  titleMinFontSize,
  smallFontSize,
  maxWidth,
  ingredientsMaxChars
}) => {
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')

  // Helper function to word-wrap text
  const wrapText = (text, font) => {
    ctx.font = font
    const words = text.split(' ')
    const lines = []
    let currentLine = ''

    for (const word of words) {
      const testLine = currentLine ? currentLine + ' ' + word : word
      if (ctx.measureText(testLine).width <= maxWidth) {
        currentLine = testLine
      } else {
        if (currentLine) lines.push(currentLine)
        currentLine = word
      }
    }
    if (currentLine) lines.push(currentLine)
    return lines
  }

  // Find fitted font size for title, then wrap if still needed
  let fittedSize = titleFontSize
  ctx.font = `bold ${fittedSize}px ${fontFamily}`

  // First, shrink font until it fits or reaches min size
  while (ctx.measureText(titleText).width > maxWidth && fittedSize > titleMinFontSize) {
    fittedSize--
    ctx.font = `bold ${fittedSize}px ${fontFamily}`
  }

  // If at min size and still doesn't fit, wrap to multiple lines
  let titleLines = [titleText]
  if (ctx.measureText(titleText).width > maxWidth) {
    titleLines = wrapText(titleText, `bold ${fittedSize}px ${fontFamily}`)
  }

  // Word-wrap ingredients text
  const truncatedIngredients = ingredientsText.length > ingredientsMaxChars
    ? ingredientsText.slice(0, ingredientsMaxChars - 3) + '...'
    : ingredientsText

  const ingredientLines = wrapText(truncatedIngredients, `${smallFontSize}px ${fontFamily}`)

  app.ports.receiveTextMeasureResult.send({
    requestId,
    titleFittedFontSize: fittedSize,
    titleLines,
    ingredientLines
  })
})

// Pinch-zoom and pan handling for label preview
const zoomState = {}

function initZoomHandler(elementId, initialZoom) {
  const el = document.getElementById(elementId)
  if (!el) return

  const state = {
    zoom: initialZoom,
    panX: 0,
    panY: 0,
    isDragging: false,
    lastX: 0,
    lastY: 0,
    touchStartDistance: 0,
    touchStartZoom: 1
  }
  zoomState[elementId] = state

  // Update the transform of the inner element
  const updateTransform = () => {
    const inner = el.querySelector('[data-zoom-target]')
    if (inner) {
      inner.style.transform = `scale(${state.zoom}) translate(${state.panX}px, ${state.panY}px)`
    }
  }

  // Wheel zoom handler
  el.addEventListener('wheel', (e) => {
    e.preventDefault()
    const delta = e.deltaY > 0 ? -0.05 : 0.05
    state.zoom = Math.max(0.25, Math.min(3.0, state.zoom + delta))
    updateTransform()
    app.ports.receivePinchZoomUpdate.send({
      zoom: state.zoom,
      panX: state.panX,
      panY: state.panY
    })
  }, { passive: false })

  // Mouse drag for panning
  el.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return // Only left click
    state.isDragging = true
    state.lastX = e.clientX
    state.lastY = e.clientY
    el.style.cursor = 'grabbing'
  })

  document.addEventListener('mousemove', (e) => {
    if (!state.isDragging) return
    const dx = (e.clientX - state.lastX) / state.zoom
    const dy = (e.clientY - state.lastY) / state.zoom
    state.panX += dx
    state.panY += dy
    state.lastX = e.clientX
    state.lastY = e.clientY
    updateTransform()
  })

  document.addEventListener('mouseup', () => {
    if (state.isDragging) {
      state.isDragging = false
      el.style.cursor = 'grab'
      app.ports.receivePinchZoomUpdate.send({
        zoom: state.zoom,
        panX: state.panX,
        panY: state.panY
      })
    }
  })

  // Touch handlers for pinch-zoom and pan
  el.addEventListener('touchstart', (e) => {
    if (e.touches.length === 2) {
      // Pinch start
      const dx = e.touches[0].clientX - e.touches[1].clientX
      const dy = e.touches[0].clientY - e.touches[1].clientY
      state.touchStartDistance = Math.hypot(dx, dy)
      state.touchStartZoom = state.zoom
    } else if (e.touches.length === 1) {
      // Single touch for pan
      state.isDragging = true
      state.lastX = e.touches[0].clientX
      state.lastY = e.touches[0].clientY
    }
  }, { passive: true })

  el.addEventListener('touchmove', (e) => {
    if (e.touches.length === 2) {
      // Pinch zoom
      e.preventDefault()
      const dx = e.touches[0].clientX - e.touches[1].clientX
      const dy = e.touches[0].clientY - e.touches[1].clientY
      const distance = Math.hypot(dx, dy)
      const scale = distance / state.touchStartDistance
      state.zoom = Math.max(0.25, Math.min(3.0, state.touchStartZoom * scale))
      updateTransform()
    } else if (e.touches.length === 1 && state.isDragging) {
      // Pan with single touch
      const dx = (e.touches[0].clientX - state.lastX) / state.zoom
      const dy = (e.touches[0].clientY - state.lastY) / state.zoom
      state.panX += dx
      state.panY += dy
      state.lastX = e.touches[0].clientX
      state.lastY = e.touches[0].clientY
      updateTransform()
    }
  }, { passive: false })

  el.addEventListener('touchend', () => {
    state.isDragging = false
    app.ports.receivePinchZoomUpdate.send({
      zoom: state.zoom,
      panX: state.panX,
      panY: state.panY
    })
  }, { passive: true })

  // Set initial cursor style
  el.style.cursor = 'grab'
}

app.ports.initPinchZoom.subscribe(({ elementId, initialZoom }) => {
  // Use requestAnimationFrame to ensure DOM is ready
  requestAnimationFrame(() => {
    initZoomHandler(elementId, initialZoom)
  })
})

app.ports.setPinchZoom.subscribe(({ elementId, zoom, panX, panY }) => {
  const state = zoomState[elementId]
  if (state) {
    state.zoom = zoom
    state.panX = panX
    state.panY = panY
    const el = document.getElementById(elementId)
    if (el) {
      const inner = el.querySelector('[data-zoom-target]')
      if (inner) {
        inner.style.transform = `scale(${zoom}) translate(${panX}px, ${panY}px)`
      }
    }
  }
})

// Register service worker for PWA (optional)
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    // Service worker registration can be added here for offline support
  })
}
