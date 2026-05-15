import { Controller } from "@hotwired/stimulus"

// Tracks reading progress against window scroll (not an overflow element).
// The essay layout uses min-h-screen so the outer div expands with content
// and the window is what actually scrolls.
export default class extends Controller {
  static values = {
    saveUrl:  String,
    position: Number,
  }

  connect() {
    // Take over scroll restoration so Turbo/browser don't fight our restore.
    history.scrollRestoration = "manual"

    this._scrollHandler  = this._onScroll.bind(this)
    this._saveNowHandler = () => this._saveNow()

    window.addEventListener("scroll", this._scrollHandler, { passive: true })
    document.addEventListener("visibilitychange", this._saveNowHandler)
    window.addEventListener("pagehide", this._saveNowHandler)

    this._restore()
  }

  disconnect() {
    window.removeEventListener("scroll", this._scrollHandler)
    document.removeEventListener("visibilitychange", this._saveNowHandler)
    window.removeEventListener("pagehide", this._saveNowHandler)
    clearTimeout(this._throttleTimer)
    this._saveNow()
    history.scrollRestoration = "auto"
  }

  // ── Private ──────────────────────────────────────────────────────────────

  // Retry until page has rendered enough content to have a scrollable range.
  _restore() {
    if (this.positionValue <= 0) return
    const attempt = (tries = 0) => {
      const scrollable = document.documentElement.scrollHeight - window.innerHeight
      if (scrollable > 0) {
        window.scrollTo({ top: this.positionValue * scrollable, behavior: "instant" })
      } else if (tries < 20) {
        requestAnimationFrame(() => attempt(tries + 1))
      }
    }
    requestAnimationFrame(() => attempt())
  }

  _onScroll() {
    if (this._throttleTimer) return
    this._throttleTimer = setTimeout(() => {
      this._throttleTimer = null
      this._saveNow()
    }, 2000)
  }

  _saveNow() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight
    if (scrollable <= 0) return

    const position = Math.min(window.scrollY / scrollable, 1)
    this._updateProgressBar(position)
    this._persist(position)
  }

  _persist(position) {
    fetch(this.saveUrlValue, {
      method: "PATCH",
      keepalive: true,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ position }),
    })
  }

  _updateProgressBar(position) {
    const bar = document.getElementById("reading-progress")
    if (bar) bar.style.width = `${(position * 100).toFixed(1)}%`
  }
}
