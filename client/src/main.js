import './main.css'
import { Elm } from './Main.elm'

// Initialize Elm application
const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    currentDate: new Date().toISOString().split('T')[0]
  }
})

// Register service worker for PWA (optional)
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    // Service worker registration can be added here for offline support
  })
}
