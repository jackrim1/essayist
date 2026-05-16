import { Controller } from "@hotwired/stimulus"

// Tracks reading progress via window scroll.
//
// UI updates (progress bar) happen on every scroll frame — immediate feedback.
// DB persistence is throttled to at most one request every 2 s so we don't
// flood the server while the reader is actively scrolling.
export default class extends Controller {
  static values = {
    saveUrl:  String,
    position: Number,
  }

  connect() {
    history.scrollRestoration = "manual"

    this._scrollHandler  = this._onScroll.bind(this)
    this._saveNowHandler = () => this._persistCurrent()

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
    this._persistCurrent()
    history.scrollRestoration = "auto"
  }

  // ── Private ──────────────────────────────────────────────────────────────

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
    // Immediate: update all UI on every scroll event.
    this._updateUI()

    // Throttled: persist to DB at most once every 2 s.
    if (this._throttleTimer) return
    this._throttleTimer = setTimeout(() => {
      this._throttleTimer = null
      this._persistCurrent()
    }, 2000)
  }

  _position() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight
    if (scrollable <= 0) return null
    return Math.min(window.scrollY / scrollable, 1)
  }

  _updateUI() {
    const pos = this._position()
    if (pos === null) return
    const bar = document.getElementById("reading-progress")
    if (bar) bar.style.width = `${(pos * 100).toFixed(1)}%`
  }

  _persistCurrent() {
    const pos = this._position()
    if (pos === null) return
    fetch(this.saveUrlValue, {
      method: "PATCH",
      keepalive: true,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ position: pos }),
    })
  }
}
