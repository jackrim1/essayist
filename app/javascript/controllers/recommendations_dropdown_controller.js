import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._outside = (e) => {
      if (!this.element.contains(e.target)) this.close()
    }
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    if (!this.menuTarget.classList.contains("hidden")) {
      document.addEventListener("click", this._outside, { capture: true, once: true })
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }
}
