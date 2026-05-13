import { Controller } from "@hotwired/stimulus"

// Tracks reading progress: persists scroll position to the server and
// restores it on page load. Throttled to avoid request floods.
export default class extends Controller {
  static values = {
    saveUrl:  String,   // PATCH /essays/:id/position
    position: Number,   // 0.0–1.0 fractional scroll depth
  }

  connect() {
    this._restore()
    this._scrollHandler = this._onScroll.bind(this)
    this.element.addEventListener("scroll", this._scrollHandler, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("scroll", this._scrollHandler)
    clearTimeout(this._throttleTimer)
  }

  // ── Private ──────────────────────────────────────────────────────────────

  _restore() {
    if (this.positionValue <= 0) return
    requestAnimationFrame(() => {
      const el = this.element
      el.scrollTop = this.positionValue * (el.scrollHeight - el.clientHeight)
    })
  }

  _onScroll() {
    if (this._throttleTimer) return

    // Throttle: fire at most once every 2 s while scrolling
    this._throttleTimer = setTimeout(() => {
      this._throttleTimer = null
      this._save()
    }, 2000)
  }

  _save() {
    const el = this.element
    const scrollable = el.scrollHeight - el.clientHeight
    if (scrollable <= 0) return

    const position = el.scrollTop / scrollable

    // Also update the visual progress bar if present
    this._updateProgressBar(position)

    // Fire-and-forget — we don't need the response
    navigator.sendBeacon(
      this.saveUrlValue,
      new Blob(
        [JSON.stringify({ position })],
        { type: "application/json" }
      )
    )
  }

  _updateProgressBar(position) {
    const bar = document.getElementById("reading-progress")
    if (bar) bar.style.width = `${(position * 100).toFixed(1)}%`
  }
}
