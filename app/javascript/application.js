import "@hotwired/turbo-rails"
import "controllers"

// Custom Turbo Stream action: syncs data-highlight-highlights-value on the
// reader element so Stimulus reapplies marks without a full page reload.
Turbo.StreamActions.updateHighlightsData = function () {
  const el = document.getElementById(this.target)
  if (!el) return
  const json = this.templateContent.textContent.trim()
  el.dataset.highlightHighlightsValue = json
}
