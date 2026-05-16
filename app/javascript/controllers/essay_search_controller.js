import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values  = { url: String }

  connect() {
    this._timer = null
    document.addEventListener("click", this._onDocumentClick.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this._onDocumentClick.bind(this))
    clearTimeout(this._timer)
  }

  search() {
    clearTimeout(this._timer)
    const q = this.inputTarget.value.trim()
    if (q.length < 2) { this._hide(); return }
    this._timer = setTimeout(() => this._fetch(q), 200)
  }

  _fetch(q) {
    fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
      headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.json())
      .then(essays => this._render(essays))
      .catch(() => this._hide())
  }

  _render(essays) {
    if (!essays.length) { this._hide(); return }

    this.resultsTarget.innerHTML = essays.map(e => `
      <li>
        <a href="${e.path}" class="flex flex-col px-4 py-2.5 hover:bg-zinc-50 dark:hover:bg-zinc-800 transition-colors">
          <span class="text-sm font-medium text-zinc-800 dark:text-zinc-200 truncate">${e.title}</span>
          ${e.author_name ? `<span class="text-xs text-zinc-400 truncate">${e.author_name}</span>` : ""}
        </a>
      </li>`).join("")
    this.resultsTarget.classList.remove("hidden")
  }

  _hide() {
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
  }

  _onDocumentClick(event) {
    if (!this.element.contains(event.target)) this._hide()
  }
}
