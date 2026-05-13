import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label"]

  fileSelected() {
    const file = this.inputTarget.files[0]
    this.labelTarget.textContent = file ? file.name : "Drop a PDF or tap to browse"
  }
}
