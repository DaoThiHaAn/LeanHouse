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
    console.log("Pagination controller connected")
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
      const value = frameUrl.searchParams.get(name)
      const defaultValue = this.defaultParamsValue[name]

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

    window.history.replaceState(window.history.state, "", canonicalUrl)

    console.log("Update url")
  }
}
