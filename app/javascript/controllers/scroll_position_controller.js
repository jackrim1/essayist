import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    saveUrl:  String,
    position: Number,
  }

  connect() {
    this._restore()
    this._scrollHandler  = this._onScroll.bind(this)
    this._saveNowHandler = () => this._saveNow()
    this.element.addEventListener("scroll", this._scrollHandler, { passive: true })
    document.addEventListener("visibilitychange", this._saveNowHandler)
    window.addEventListener("pagehide", this._saveNowHandler)
  }

  disconnect() {
    this.element.removeEventListener("scroll", this._scrollHandler)
    document.removeEventListener("visibilitychange", this._saveNowHandler)
    window.removeEventListener("pagehide", this._saveNowHandler)
    clearTimeout(this._throttleTimer)
    this._saveNow()
  }

  // ── Private ──────────────────────────────────────────────────────────────

  // Retry scroll restore until layout has settled (scrollHeight > 0).
  _restore() {
    if (this.positionValue <= 0) return
    const attempt = (tries = 0) => {
      const el = this.element
      const scrollable = el.scrollHeight - el.clientHeight
      if (scrollable > 0) {
        el.scrollTop = this.positionValue * scrollable
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
    const el = this.element
    const scrollable = el.scrollHeight - el.clientHeight
    if (scrollable <= 0) return

    const position = el.scrollTop / scrollable
    this._updateProgressBar(position)
    this._persist(position)
  }

  // fetch + keepalive works during page unload; keepalive allows the request
  // to complete even after the page starts navigating away.
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
