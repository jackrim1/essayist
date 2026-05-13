import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash toasts after 3 s; clicking dismisses immediately.
export default class extends Controller {
  connect() {
    this._timer = setTimeout(() => this._remove(), 3000)
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  dismiss() {
    this._remove()
  }

  _remove() {
    this.element.classList.add("opacity-0", "transition-opacity", "duration-300")
    setTimeout(() => this.element.remove(), 300)
  }
}
