import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "essayist:theme"

// Syncs Tailwind's `dark` class on <html> with system preference + manual override.
export default class extends Controller {
  connect() {
    this._mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this._mediaHandler = () => { if (!localStorage.getItem(STORAGE_KEY)) this._applySystem() }
    this._mediaQuery.addEventListener("change", this._mediaHandler)
    this._applyStored()
  }

  disconnect() {
    this._mediaQuery?.removeEventListener("change", this._mediaHandler)
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    this._set(isDark ? "light" : "dark")
  }

  // ── Private ──────────────────────────────────────────────────────────────

  _applyStored() {
    const stored = localStorage.getItem(STORAGE_KEY)
    stored ? this._apply(stored) : this._applySystem()
  }

  _applySystem() {
    this._apply(this._mediaQuery.matches ? "dark" : "light")
  }

  _set(theme) {
    localStorage.setItem(STORAGE_KEY, theme)
    this._apply(theme)
  }

  _apply(theme) {
    document.documentElement.classList.toggle("dark", theme === "dark")
  }
}
