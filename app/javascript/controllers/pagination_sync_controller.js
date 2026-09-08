import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    canonicalUrl: String, // URL to display in the browser
    defaultParams: Object, // fixed default
    queryParams: Array, // request params to preserve
    pageParam: { type: String, default: "page" }, // optional, defaults to "page"
    totalPagesSelector: String // data-pagination-total-pages
  }

  connect() {
    this.syncInitialUrl()
  }

  syncInitialUrl() {
    if (!this.hasCanonicalUrlValue) return

    const currentUrl = new URL(window.location.href)
    const canonicalBaseUrl = new URL(this.canonicalUrlValue, window.location.origin)

    if (currentUrl.pathname !== canonicalBaseUrl.pathname) return

    let urlChanged = false

    if (this.hasDefaultParamsValue) {
      for (const [key, defaultValue] of Object.entries(this.defaultParamsValue)) {
        if (!currentUrl.searchParams.has(key) && defaultValue) {
          currentUrl.searchParams.set(key, defaultValue)
          urlChanged = true
        }
      }
    }

    const monthVal = currentUrl.searchParams.get("month")
    if (monthVal) {
      const match = monthVal.match(/^(\d{4})[-./](\d{1,2})$/)
      if (match) {
        const normalized = `${match[1]}-${match[2].padStart(2, "0")}`
        if (normalized !== monthVal) {
          currentUrl.searchParams.set("month", normalized)
          urlChanged = true
        }
      }
    }

    if (urlChanged) {
      window.history.replaceState(window.history.state, "", currentUrl.href)
    }
  }

  updateUrl(event) {
    const frame = event.target
    const responseUrl = event.detail?.fetchResponse?.response?.url || frame.src
    if (!responseUrl) return

    const frameUrl = new URL(responseUrl, window.location.origin)
    const canonicalUrl = new URL(this.canonicalUrlValue, window.location.origin)
    const totalPagesElement = this.hasTotalPagesSelectorValue && frame.querySelector(this.totalPagesSelectorValue)
    const totalPages = Number(totalPagesElement?.dataset.paginationTotalPages)

    const parameterNames = new Set([
      ...this.queryParamsValue,
      ...Object.keys(this.defaultParamsValue)
    ])

    parameterNames.forEach((name) => {
      const values = frameUrl.searchParams.getAll(name)
      let value = values.length > 0 ? values[values.length - 1] : null
      const defaultValue = this.defaultParamsValue[name]

      if (value && name === "month") {
        const match = value.match(/^(\d{4})[-./](\d{1,2})$/)
        if (match) {
          value = `${match[1]}-${match[2].padStart(2, "0")}`
        }
      }

      if (value) {
        canonicalUrl.searchParams.set(name, value)
      } else if (Object.hasOwn(this.defaultParamsValue, name)) {
        canonicalUrl.searchParams.set(name, defaultValue)
      }
    })

    const page = frameUrl.searchParams.get(this.pageParamValue)
    if (totalPages > 1) {
      canonicalUrl.searchParams.set(this.pageParamValue, page || "1")
    }

    window.history.replaceState(window.history.state, "", canonicalUrl.href)

    console.log("Update url", canonicalUrl.href)
  }
}
