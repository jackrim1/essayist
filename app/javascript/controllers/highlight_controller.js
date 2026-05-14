import { Controller } from "@hotwired/stimulus"

// Text highlighting engine using the native Selection API.
// Shows a floating toolbar on selection; saves via Turbo; marks text in-place.
export default class extends Controller {
  static values = {
    createUrl:  String,   // POST /essays/:id/highlights
    essayId:    Number,
    highlights: Array,    // [{ id, color, anchor }] serialised on page render
  }

  static targets = ["toolbar", "selectedText", "colorInput", "anchorInput"]

  connect() {
    this._selectionHandler   = this._onSelectionChange.bind(this)
    this._submitEndHandler   = this._onSubmitEnd.bind(this)
    this._streamRenderHandler = this._onBeforeStreamRender.bind(this)
    this._markClickHandler   = this._onMarkClick.bind(this)
    this._docClickHandler    = this._onDocClick.bind(this)

    document.addEventListener("selectionchange",             this._selectionHandler)
    document.addEventListener("turbo:submit-end",            this._submitEndHandler)
    document.addEventListener("turbo:before-stream-render",  this._streamRenderHandler)
    document.addEventListener("click",                       this._docClickHandler)
    this.element.addEventListener("click",                   this._markClickHandler)

    // Re-apply all marks cleanly (handles Turbo cache restoration too)
    this._clearHighlightMarks()
    this._applyAllHighlights()
  }

  disconnect() {
    document.removeEventListener("selectionchange",             this._selectionHandler)
    document.removeEventListener("turbo:submit-end",            this._submitEndHandler)
    document.removeEventListener("turbo:before-stream-render",  this._streamRenderHandler)
    document.removeEventListener("click",         this._docClickHandler)
    this.element.removeEventListener("click",     this._markClickHandler)
    this._hideTagPopover()
    this._hideToolbar()
  }

  // Re-apply whenever the server pushes an updated highlights array
  highlightsValueChanged() {
    this._clearHighlightMarks()
    this._applyAllHighlights()
  }

  // ── Toolbar guards ────────────────────────────────────────────────────────

  // Prevent mousedown/touchstart on the toolbar from collapsing the active
  // text selection. Submit buttons are exempt: suppressing their events blocks
  // form activation (Chrome fires no click after a prevented mousedown on a
  // submit; iOS does the same for touchstart).
  toolbarTargetConnected(el) {
    const guard = (e) => {
      if (e.target.closest("[data-toolbar-submit]")) return
      e.preventDefault()
    }
    el.addEventListener("mousedown",  guard)
    el.addEventListener("touchstart", guard, { passive: false })
  }

  // ── Toolbar actions ───────────────────────────────────────────────────────

  setColor(event) {
    const color = event.currentTarget.dataset.color
    if (this.hasColorInputTarget) this.colorInputTarget.value = color
    this.element.querySelectorAll("[data-color]").forEach(btn => {
      btn.classList.toggle("ring-2", btn.dataset.color === color)
    })
  }

  // Optimistically mark the text immediately, then tag the mark with the real
  // server-assigned id once turbo:submit-end fires.  This avoids any dependency
  // on turbo:submit-end timing for the visual update.
  saveHighlight(event) {
    const anchor = this._parseAnchor()
    const color  = this.hasColorInputTarget ? this.colorInputTarget.value : "yellow"

    window.getSelection()?.removeAllRanges()

    if (anchor) this._applyHighlightMark("pending", color, anchor)
  }

  // ── Private: mark application ─────────────────────────────────────────────

  _applyAllHighlights() {
    if (!this.hasHighlightsValue) return
    this.highlightsValue.forEach(h => {
      if (h.anchor && h.anchor.startPara != null) {
        this._applyHighlightMark(h.id, h.color, h.anchor)
      }
    })
  }

  _applyHighlightMark(id, color, anchor) {
    const range = this._rangeFromAnchor(anchor)
    if (!range || range.collapsed) return

    const mark = document.createElement("mark")
    mark.dataset.hlId = String(id)
    mark.style.cssText = [
      `background-color: ${this._bgColor(color)}`,
      "color: inherit",
      "border-radius: 2px",
      "padding: 0 1px",
    ].join(";")

    try {
      range.surroundContents(mark)
    } catch {
      // Range partially selects an element node (e.g. spans inline formatting).
      // extractContents + insertNode handles this without throwing.
      mark.appendChild(range.extractContents())
      range.insertNode(mark)
    }
  }

  _clearHighlightMarks() {
    this.element.querySelectorAll("mark[data-hl-id]").forEach(mark => {
      const parent = mark.parentNode
      if (!parent) return
      while (mark.firstChild) parent.insertBefore(mark.firstChild, mark)
      parent.removeChild(mark)
      parent.normalize()
    })
  }

  _removeHighlightMark(id) {
    this.element.querySelectorAll(`mark[data-hl-id="${id}"]`).forEach(mark => {
      const parent = mark.parentNode
      if (!parent) return
      while (mark.firstChild) parent.insertBefore(mark.firstChild, mark)
      parent.removeChild(mark)
      parent.normalize()
    })
  }

  // ── Private: tag popover (click-triggered on marks) ─────────────────────

  _onMarkClick(event) {
    const mark = event.target.closest("mark[data-hl-id]")
    if (!mark) return
    // Don't open while user has text selected (they may be re-selecting)
    const sel = window.getSelection()
    if (sel && !sel.isCollapsed) return

    event.stopPropagation()

    const tip = this._tagTip()
    if (this._popoverMark === mark && !tip.classList.contains("hidden")) {
      this._hideTagPopover()
      return
    }
    this._popoverMark = mark
    this._renderTagPopover(mark)
  }

  _onDocClick(event) {
    const tip = this._tagTip()
    if (!tip.classList.contains("hidden") &&
        !tip.contains(event.target) &&
        !event.target.closest("mark[data-hl-id]")) {
      this._hideTagPopover()
    }
  }

  _renderTagPopover(mark) {
    const hlId = mark.dataset.hlId
    const card = document.querySelector(`#highlight_${hlId}`)

    // Snapshot current chips from the sidebar card so we can mirror them
    const chips = card ? Array.from(card.querySelectorAll("[data-tag-name]")).map(el => ({
      htId:        el.id.replace("hl_tag_", ""),
      name:        el.dataset.tagName,
      removeHref:  el.querySelector("a[data-turbo-method]")?.href ?? "",
    })) : []

    const chipsHtml = chips.map(c =>
      `<span id="mark_hl_tag_${c.htId}" data-tag-name="${c.name}"
             class="inline-flex items-center gap-0.5 text-[10px] px-1 py-px rounded
                    bg-zinc-100 dark:bg-zinc-800 text-zinc-500 dark:text-zinc-400">
         <a href="/tags/${c.name}" class="hover:text-zinc-700 dark:hover:text-zinc-200">#${c.name}</a>
         <a href="${c.removeHref}" data-turbo-method="delete"
            class="leading-none text-zinc-300 hover:text-zinc-500 dark:text-zinc-600 dark:hover:text-zinc-400">×</a>
       </span>`
    ).join("")

    const tip = this._tagTip()
    tip.innerHTML =
      `<div class="p-2">
         <div id="mark_tags_${hlId}" class="flex flex-wrap gap-1 ${chips.length ? "mb-1.5" : ""}">${chipsHtml}</div>
         <div class="relative"
              data-controller="tag-input"
              data-tag-input-highlight-id-value="${hlId}"
              data-tag-input-add-url-value="/highlights/${hlId}/tags">
           <input type="text"
                  data-tag-input-target="input"
                  data-action="input->tag-input#suggest keydown->tag-input#keydown focus->tag-input#open"
                  placeholder="add tag…" autocomplete="off" maxlength="40"
                  class="text-[10px] bg-transparent w-24 text-zinc-600 dark:text-zinc-300 placeholder-zinc-300 dark:placeholder-zinc-600"
                  style="border:none;outline:none;box-shadow:none">
           <ul data-tag-input-target="dropdown"
               class="absolute top-full left-0 mt-1 z-50 hidden w-44 py-1
                      bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-700 rounded-lg shadow-lg">
           </ul>
         </div>
       </div>`

    this._positionPopover(mark)
    requestAnimationFrame(() => tip.querySelector("[data-tag-input-target='input']")?.focus())
  }

  _positionPopover(mark) {
    const tip = this._tagTip()
    tip.style.top  = "-9999px"
    tip.style.left = "-9999px"
    tip.classList.remove("hidden")
    const rect = mark.getBoundingClientRect()
    tip.style.top  = `${rect.bottom + window.scrollY + 6}px`
    tip.style.left = `${Math.max(8, rect.left + window.scrollX + rect.width / 2 - tip.offsetWidth / 2)}px`
  }

  _hideTagPopover() {
    this._popoverMark = null
    this._tip?.classList.add("hidden")
  }

  _tagTip() {
    if (!this._tip) {
      this._tip = document.createElement("div")
      this._tip.className = [
        "absolute z-50 hidden",
        "bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-700",
        "rounded-xl shadow-xl",
      ].join(" ")
      document.body.appendChild(this._tip)
    }
    return this._tip
  }

  _bgColor(color) {
    return {
      yellow: "rgba(253,224,71,0.45)",
      green:  "rgba(134,239,172,0.45)",
      blue:   "rgba(147,197,253,0.45)",
      pink:   "rgba(249,168,212,0.45)",
      purple: "rgba(216,180,254,0.45)",
    }[color] ?? "rgba(253,224,71,0.45)"
  }

  // ── Private: event handlers ───────────────────────────────────────────────

  // Replace the "pending" mark's id with the real server-assigned id, or roll
  // back the optimistic mark if the save failed.
  _onSubmitEnd(event) {
    if (!this.element.contains(event.target)) return

    requestAnimationFrame(() => {
      if (!event.detail.success) {
        this._removeHighlightMark("pending")
        return
      }
      const firstLi = document.querySelector("#highlights-list li")
      const id = firstLi?.id?.replace("highlight_", "")
      if (!id) {
        this._removeHighlightMark("pending")
        return
      }
      this.element.querySelectorAll('mark[data-hl-id="pending"]').forEach(m => {
        m.dataset.hlId = id
      })
    })
  }

  // When Turbo removes a sidebar <li id="highlight_N">, mirror by removing
  // the corresponding <mark> from the essay text.
  _onBeforeStreamRender(event) {
    const stream = event.detail.newStream
    if (stream.action !== "remove") return
    const target = stream.target || ""
    if (!target.startsWith("highlight_")) return
    this._removeHighlightMark(target.replace("highlight_", ""))
  }

  _parseAnchor() {
    if (!this.hasAnchorInputTarget) return null
    try {
      const a = JSON.parse(this.anchorInputTarget.value || "{}")
      return a.startPara != null ? a : null
    } catch { return null }
  }

  // ── Private: selection toolbar ────────────────────────────────────────────

  _onSelectionChange() {
    const sel = window.getSelection()

    if (!sel || sel.isCollapsed || !sel.toString().trim()) {
      if (this._toolbarVisible) {
        this._hideDelay = setTimeout(() => this._hideToolbar(), 200)
      }
      return
    }

    if (!this.element.contains(sel.anchorNode)) return

    if (this.hasSelectedTextTarget) this.selectedTextTarget.value = sel.toString().trim()
    if (this.hasAnchorInputTarget)  this.anchorInputTarget.value  = JSON.stringify(this._anchor(sel))

    clearTimeout(this._hideDelay)
    this._showToolbar(sel.getRangeAt(0).getBoundingClientRect())
  }

  _showToolbar(rect) {
    if (!this.hasToolbarTarget) return
    this._toolbarVisible = true
    const toolbar = this.toolbarTarget
    toolbar.classList.remove("hidden")
    const top  = rect.top  - toolbar.offsetHeight - 12
    const left = rect.left + rect.width / 2 - toolbar.offsetWidth / 2
    toolbar.style.top  = `${Math.max(8, top)}px`
    toolbar.style.left = `${Math.max(8, left)}px`
  }

  _hideToolbar() {
    if (!this.hasToolbarTarget) return
    this._toolbarVisible = false
    this.toolbarTarget.classList.add("hidden")
  }

  // ── Private: anchor serialisation / range restoration ────────────────────

  // Builds an anchor using cumulative character offsets within each paragraph's
  // textContent, so the position survives DOM changes (e.g. added <mark> nodes).
  _anchor(sel) {
    const range = sel.getRangeAt(0)
    const paras = Array.from(this.element.querySelectorAll("p, h1, h2, h3, h4"))

    const paraIndex = (node) => paras.findIndex(p => p.contains(node))

    // Walk text nodes to convert (container, rawOffset) → cumulative char offset
    const cumOffset = (para, container, rawOffset) => {
      if (!para) return rawOffset
      let total = 0
      const walker = document.createTreeWalker(para, NodeFilter.SHOW_TEXT)
      let node
      while ((node = walker.nextNode())) {
        if (node === container) return total + rawOffset
        total += node.length
      }
      return total
    }

    const spi = paraIndex(range.startContainer)
    const epi = paraIndex(range.endContainer)

    return {
      startPara:   spi,
      startOffset: cumOffset(paras[spi], range.startContainer, range.startOffset),
      endPara:     epi,
      endOffset:   cumOffset(paras[epi], range.endContainer,   range.endOffset),
      text:        sel.toString().trim(),
    }
  }

  // Reconstructs a DOM Range from a stored anchor using cumulative char offsets.
  _rangeFromAnchor({ startPara, startOffset, endPara, endOffset }) {
    const paras   = Array.from(this.element.querySelectorAll("p, h1, h2, h3, h4"))
    const startEl = paras[startPara]
    const endEl   = paras[endPara]
    if (!startEl || !endEl) return null

    const nodeAt = (el, offset) => {
      let remaining = offset
      const walker  = document.createTreeWalker(el, NodeFilter.SHOW_TEXT)
      let node
      while ((node = walker.nextNode())) {
        if (remaining <= node.length) return { node, offset: remaining }
        remaining -= node.length
      }
      // Clamp to end of last text node
      return node ? { node, offset: node.length } : null
    }

    const start = nodeAt(startEl, startOffset)
    const end   = nodeAt(endEl,   endOffset)
    if (!start || !end) return null

    const range = document.createRange()
    range.setStart(start.node, start.offset)
    range.setEnd(end.node,     end.offset)
    return range
  }
}
