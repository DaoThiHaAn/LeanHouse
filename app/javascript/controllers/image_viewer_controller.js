import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "mainImage", "mainCaption", "thumbnail", "counter"]
  static values = {
    currentIndex: { type: Number, default: 0 },
    images: Array
  }

  connect() {
    this.keyHandler = this.handleKeydown.bind(this)
  }

  disconnect() {
    window.removeEventListener("keydown", this.keyHandler)
    document.body.classList.remove("overflow-hidden")
  }

  open(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.currentIndexValue = isNaN(index) ? 0 : index
    this.modalTarget.classList.remove("d-none")
    document.body.classList.add("overflow-hidden")
    window.addEventListener("keydown", this.keyHandler)
    this.updateViewer()
  }

  close() {
    this.modalTarget.classList.add("d-none")
    document.body.classList.remove("overflow-hidden")
    window.removeEventListener("keydown", this.keyHandler)
  }

  next(event) {
    if (event) event.stopPropagation()
    if (!this.imagesValue || this.imagesValue.length <= 1) return
    this.currentIndexValue = (this.currentIndexValue + 1) % this.imagesValue.length
    this.updateViewer()
  }

  prev(event) {
    if (event) event.stopPropagation()
    if (!this.imagesValue || this.imagesValue.length <= 1) return
    this.currentIndexValue = (this.currentIndexValue - 1 + this.imagesValue.length) % this.imagesValue.length
    this.updateViewer()
  }

  select(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (!isNaN(index)) {
      this.currentIndexValue = index
      this.updateViewer()
    }
  }

  updateViewer() {
    const current = this.imagesValue[this.currentIndexValue]
    if (!current) return

    this.mainImageTarget.src = current.url
    this.mainImageTarget.alt = current.name || ""

    if (this.hasMainCaptionTarget) {
      this.mainCaptionTarget.textContent = current.name || ""
    }

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.currentIndexValue + 1} / ${this.imagesValue.length}`
    }

    if (this.hasThumbnailTargets) {
      this.thumbnailTargets.forEach((thumb, idx) => {
        if (idx === this.currentIndexValue) {
          thumb.classList.add("active-thumbnail")
          thumb.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" })
        } else {
          thumb.classList.remove("active-thumbnail")
        }
      })
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    } else if (event.key === "ArrowRight") {
      this.next()
    } else if (event.key === "ArrowLeft") {
      this.prev()
    }
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}
