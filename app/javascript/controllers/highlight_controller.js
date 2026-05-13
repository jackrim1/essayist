import { Controller } from "@hotwired/stimulus"

// Text highlighting engine using the native Selection API.
// Shows a floating toolbar on selection; saves via Turbo.
export default class extends Controller {
  static values = {
    createUrl: String,  // POST /essays/:id/highlights
    essayId:   Number,
  }

  static targets = ["toolbar", "selectedText", "colorInput", "anchorInput"]

  connect() {
    this._selectionHandler = this._onSelectionChange.bind(this)
    document.addEventListener("selectionchange", this._selectionHandler)
    document.addEventListener("click", this._onDocClick.bind(this))
  }

  disconnect() {
    document.removeEventListener("selectionchange", this._selectionHandler)
    this._hideToolbar()
  }

  // Called by toolbar color buttons via data-action
  setColor(event) {
    const color = event.currentTarget.dataset.color
    if (this.hasColorInputTarget) this.colorInputTarget.value = color

    // Update active state on color swatches
    this.element.querySelectorAll("[data-color]").forEach(btn => {
      btn.classList.toggle("ring-2", btn.dataset.color === color)
    })
  }

  // Called when the form inside the toolbar submits
  saveHighlight(event) {
    // Populate hidden fields before Turbo submits
    const sel = window.getSelection()
    if (sel && !sel.isCollapsed) {
      if (this.hasSelectedTextTarget) this.selectedTextTarget.value = sel.toString().trim()
      if (this.hasAnchorInputTarget) this.anchorInputTarget.value = JSON.stringify(this._anchor(sel))
    }
    this._hideToolbar()
    window.getSelection()?.removeAllRanges()
  }

  // ── Private ──────────────────────────────────────────────────────────────

  _onSelectionChange() {
    const sel = window.getSelection()

    if (!sel || sel.isCollapsed || !sel.toString().trim()) {
      // Small delay so toolbar clicks don't dismiss before firing
      this._hideDelay = setTimeout(() => this._hideToolbar(), 200)
      return
    }

    // Only act on selections within this controller's element
    if (!this.element.contains(sel.anchorNode)) return

    clearTimeout(this._hideDelay)
    this._showToolbar(sel.getRangeAt(0).getBoundingClientRect())
  }

  _onDocClick(event) {
    if (!this._toolbarVisible) return
    if (!this.toolbarTarget.contains(event.target)) {
      this._hideToolbar()
    }
  }

  _showToolbar(rect) {
    if (!this.hasToolbarTarget) return
    this._toolbarVisible = true

    const toolbar = this.toolbarTarget
    toolbar.classList.remove("hidden")

    // Position above the selection, centered
    const top  = rect.top + window.scrollY - toolbar.offsetHeight - 12
    const left = rect.left + rect.width / 2 - toolbar.offsetWidth / 2
    toolbar.style.top  = `${Math.max(8, top)}px`
    toolbar.style.left = `${Math.max(8, left)}px`
  }

  _hideToolbar() {
    if (!this.hasToolbarTarget) return
    this._toolbarVisible = false
    this.toolbarTarget.classList.add("hidden")
  }

  // Build a minimal anchor: paragraph index + char offsets for re-location
  _anchor(sel) {
    const range  = sel.getRangeAt(0)
    const paras  = Array.from(this.element.querySelectorAll("p, h1, h2, h3, h4"))
    const anchor = (node) => {
      const para = paras.findIndex(p => p.contains(node))
      return para
    }

    return {
      startPara:   anchor(range.startContainer),
      startOffset: range.startOffset,
      endPara:     anchor(range.endContainer),
      endOffset:   range.endOffset,
      text:        sel.toString().trim(),
    }
  }
}
