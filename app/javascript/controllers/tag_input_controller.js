import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { highlightId: Number, addUrl: String }
  static targets = ["input", "dropdown"]

  connect() {
    this._debounce   = null
    this._cursor     = -1
    this._docClick   = this._onDocClick.bind(this)
    document.addEventListener("click", this._docClick)
  }

  disconnect() {
    document.removeEventListener("click", this._docClick)
    clearTimeout(this._debounce)
  }

  open() {
    this._fetch(this._sanitize(this.inputTarget.value))
  }

  suggest() {
    clearTimeout(this._debounce)
    const q = this._sanitize(this.inputTarget.value)
    this._debounce = setTimeout(() => this._fetch(q), 180)
  }

  keydown(event) {
    const items = Array.from(this.dropdownTarget.querySelectorAll("li[data-name]"))
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this._cursor = Math.min(this._cursor + 1, items.length - 1)
      this._highlightItem(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this._cursor = Math.max(this._cursor - 1, -1)
      this._highlightItem(items)
    } else if (event.key === "Enter") {
      event.preventDefault()
      const selected = items[this._cursor]
      const name = selected ? selected.dataset.name : this._sanitize(this.inputTarget.value)
      if (name) this._submit(name)
    } else if (event.key === "Escape") {
      this._close()
    } else if (event.key === "," || event.key === " ") {
      // comma or space commits the current input
      event.preventDefault()
      const name = this._sanitize(this.inputTarget.value)
      if (name) this._submit(name)
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  _sanitize(val) {
    return val.trim().toLowerCase().replace(/[^a-z0-9-]/g, "")
  }

  async _fetch(q) {
    const url = `/tags?q=${encodeURIComponent(q)}`
    let tags
    try {
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      tags = await res.json()
    } catch { return }
    this._render(tags, q)
  }

  _render(tags, q) {
    if (!tags.length) { this._close(); return }
    this.dropdownTarget.innerHTML = tags.map((t, i) =>
      `<li data-index="${i}" data-name="${t.name}"
           class="px-2.5 py-1 flex items-center gap-2 cursor-pointer select-none
                  hover:bg-zinc-50 dark:hover:bg-zinc-800 text-zinc-600 dark:text-zinc-300">
         <span class="text-[10px] truncate min-w-0 flex-1">${t.name}</span>
         <span class="text-[10px] text-zinc-400 flex-shrink-0 tabular-nums">${t.count}</span>
       </li>`
    ).join("")
    this.dropdownTarget.querySelectorAll("li").forEach(li => {
      li.addEventListener("mousedown", e => { e.preventDefault(); this._submit(li.dataset.name) })
    })
    this._cursor = -1
    this.dropdownTarget.classList.remove("hidden")
  }

  _highlightItem(items) {
    items.forEach((li, i) => li.classList.toggle("bg-zinc-50", i === this._cursor))
  }

  async _submit(name) {
    name = this._sanitize(name)
    if (!name) return
    this._close()
    this.inputTarget.value = ""

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    let res
    try {
      res = await fetch(this.addUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept":        "text/vnd.turbo-stream.html",
          "X-CSRF-Token":  csrf,
        },
        body: JSON.stringify({ name }),
      })
    } catch { return }

    if (res.ok) {
      const html = await res.text()
      window.Turbo?.renderStreamMessage(html)
    }
  }

  _close() {
    this.dropdownTarget.classList.add("hidden")
    this._cursor = -1
  }

  _onDocClick(e) {
    if (!this.element.contains(e.target)) this._close()
  }
}
