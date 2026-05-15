import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileSection", "urlSection", "fileTab", "urlTab", "urlInput"]

  connect() {
    this.showFile()
  }

  showFile() {
    this.fileSectionTarget.hidden = false
    this.urlSectionTarget.hidden = true
    this.#setActive(this.fileTabTarget, this.urlTabTarget)
    if (this.hasUrlInputTarget) this.urlInputTarget.value = ""
    this.#setHints(false)
  }

  showUrl() {
    this.fileSectionTarget.hidden = true
    this.urlSectionTarget.hidden = false
    this.#setActive(this.urlTabTarget, this.fileTabTarget)
    this.#setHints(true)
  }

  #setActive(active, inactive) {
    active.dataset.active = "true"
    inactive.dataset.active = "false"
  }

  #setHints(visible) {
    document.querySelectorAll("[data-essay-source-hint]").forEach(el => {
      el.classList.toggle("hidden", !visible)
    })
  }
}
