import './main.css'
import { Elm } from './Main.elm'

// Font embedding for SVG to PNG conversion
let fontCache = null

async function loadFontAsBase64(url, mimeType) {
  const response = await fetch(url)
  const arrayBuffer = await response.arrayBuffer()
  const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))
  return `data:${mimeType};base64,${base64}`
}

async function ensureFontsLoaded() {
  if (fontCache) return fontCache

  const [regularData, boldData] = await Promise.all([
    loadFontAsBase64('https://fonts.gstatic.com/s/atkinsonhyperlegible/v12/9Bt23C1KxNDXMspQ1lPyU89-1h6ONRlW45GE5Q.ttf', 'font/ttf'),
    loadFontAsBase64('https://fonts.gstatic.com/s/atkinsonhyperlegible/v12/9Bt73C1KxNDXMspQ1lPyU89-1h6ONRlW45G8WbcNcw.ttf', 'font/ttf')
  ])

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
    currentDate: new Date().toISOString().split('T')[0]
  }
})

// Text measurement port for dynamic font sizing and word wrapping
app.ports.requestTextMeasure.subscribe(({
  requestId,
  text,
  fontFamily,
  maxFontSize,
  minFontSize,
  maxWidth,
  maxHeight
}) => {
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')

  // Helper function to word-wrap text
  const wrapText = (str, font) => {
    ctx.font = font
    const words = str.split(' ')
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

  // Helper to check if text fits vertically
  const fitsVertically = (fontSize, lines) => {
    if (maxHeight <= 0) return true
    const lineHeight = fontSize * 1.2
    const totalHeight = lineHeight * lines.length
    return totalHeight <= maxHeight
  }

  // Find fitted font size, then wrap if still needed
  let fittedSize = maxFontSize
  ctx.font = `bold ${fittedSize}px ${fontFamily}`

  // Shrink font until it fits width or reaches min size
  while (ctx.measureText(text).width > maxWidth && fittedSize > minFontSize) {
    fittedSize--
    ctx.font = `bold ${fittedSize}px ${fontFamily}`
  }

  // If at min size and still doesn't fit, wrap to multiple lines
  let lines = [text]
  if (ctx.measureText(text).width > maxWidth) {
    lines = wrapText(text, `bold ${fittedSize}px ${fontFamily}`)
  }

  // If maxHeight is set, shrink further if lines exceed vertical space
  if (maxHeight > 0 && !fitsVertically(fittedSize, lines)) {
    while (fittedSize > minFontSize && !fitsVertically(fittedSize, lines)) {
      fittedSize--
      ctx.font = `bold ${fittedSize}px ${fontFamily}`
      lines = wrapText(text, `bold ${fittedSize}px ${fontFamily}`)
    }
  }

  app.ports.receiveTextMeasureResult.send({
    requestId,
    fittedFontSize: fittedSize,
    lines
  })
})

// SVG to PNG conversion port
app.ports.requestSvgToPng.subscribe(async ({ svgId, requestId, width, height, rotate }) => {
  try {
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

    const svgClone = svgElement.cloneNode(true)

    const fonts = await ensureFontsLoaded()
    embedFontsInSvg(svgClone, fonts)

    const svgWidth = svgClone.getAttribute('width') || width
    const svgHeight = svgClone.getAttribute('height') || height
    svgClone.setAttribute('width', svgWidth)
    svgClone.setAttribute('height', svgHeight)
    svgClone.setAttribute('xmlns', 'http://www.w3.org/2000/svg')

    const serializer = new XMLSerializer()
    const svgString = serializer.serializeToString(svgClone)

    const base64 = btoa(unescape(encodeURIComponent(svgString)))
    const url = `data:image/svg+xml;base64,${base64}`

    const img = new Image()
    img.onload = () => {
      let dataUrl

      if (rotate) {
        const displayWidth = height
        const displayHeight = width

        const canvas = document.createElement('canvas')
        canvas.width = displayWidth
        canvas.height = displayHeight
        const ctx = canvas.getContext('2d')

        ctx.fillStyle = 'white'
        ctx.fillRect(0, 0, displayWidth, displayHeight)
        ctx.drawImage(img, 0, 0, displayWidth, displayHeight)

        const rotatedCanvas = document.createElement('canvas')
        rotatedCanvas.width = width
        rotatedCanvas.height = height
        const rotatedCtx = rotatedCanvas.getContext('2d')

        rotatedCtx.fillStyle = 'white'
        rotatedCtx.fillRect(0, 0, width, height)
        rotatedCtx.translate(width, 0)
        rotatedCtx.rotate(Math.PI / 2)
        rotatedCtx.drawImage(canvas, 0, 0)

        dataUrl = rotatedCanvas.toDataURL('image/png')
      } else {
        const canvas = document.createElement('canvas')
        canvas.width = width
        canvas.height = height
        const ctx = canvas.getContext('2d')

        ctx.fillStyle = 'white'
        ctx.fillRect(0, 0, width, height)
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

// Register service worker for PWA (optional)
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    // Service worker registration can be added here for offline support
  })
}
