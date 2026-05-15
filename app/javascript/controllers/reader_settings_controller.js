import { Controller } from "@hotwired/stimulus"

const FONT_SIZES  = ["text-sm", "text-base", "text-lg", "text-xl", "text-2xl"]
const STORAGE_KEY = "essayist:reader"

export default class extends Controller {
  static values  = { syncUrl: String }
  static targets = ["content", "drawer", "scrim"]

  connect() {
    this._apply(this._load())
  }

  openDrawer() {
    this.scrimTarget.classList.remove("opacity-0", "pointer-events-none")
    this.drawerTarget.classList.remove("translate-y-full")
  }

  closeDrawer() {
    this.drawerTarget.classList.add("translate-y-full")
    this.scrimTarget.classList.add("opacity-0", "pointer-events-none")
  }

  increaseFontSize() { this._stepFont(1) }
  decreaseFontSize() { this._stepFont(-1) }

  // ── Private ──────────────────────────────────────────────────────────────

  _stepFont(delta) {
    const prefs  = this._load()
    const idx    = FONT_SIZES.indexOf(prefs.font_size || "text-base")
    const newIdx = Math.min(Math.max(idx + delta, 0), FONT_SIZES.length - 1)
    this._save({ font_size: FONT_SIZES[newIdx] })
    this._applyFontSize(FONT_SIZES[newIdx])
    this._syncServer()
  }

  _apply(prefs) {
    this._applyFontSize(prefs.font_size || "text-base")
  }

  _applyFontSize(size) {
    if (!this.hasContentTarget) return
    FONT_SIZES.forEach(s => this.contentTarget.classList.remove(s))
    this.contentTarget.classList.add(size)
  }

  _load() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}") }
    catch { return {} }
  }

  _save(patch) {
    const prefs = { ...this._load(), ...patch }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs))
  }

  _syncServer() {
    if (!this.hasSyncUrlValue) return
    const prefs = this._load()
    fetch(this.syncUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ user: { preferences: prefs } }),
    })
  }
}
