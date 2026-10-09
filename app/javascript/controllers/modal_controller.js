import { Controller } from "@hotwired/stimulus"

// Defensive patch for Bootstrap Modal to prevent race conditions during asynchronous transitions.
// When Turbo replaces a Turbo Frame or navigates, a modal may be disconnected and disposed while
// backdrop or hide animation timers are still queued in the browser event loop.
// When those timers fire, Bootstrap attempts to access `this._element.style`, which causes
// `Uncaught TypeError: can't access property "style", this._element is null` if disposed.
function patchBootstrapModal() {
  const bootstrapModal = window.bootstrap?.Modal
  if (!bootstrapModal) return

  const proto = bootstrapModal.prototype
  if (proto._turboPatched) return
  proto._turboPatched = true

  const origShowElement = proto._showElement
  proto._showElement = function(...args) {
    if (!this._element) return
    return origShowElement.apply(this, args)
  }

  const origHideModal = proto._hideModal
  proto._hideModal = function(...args) {
    if (!this._element) return
    return origHideModal.apply(this, args)
  }

  const origAdjustDialog = proto._adjustDialog
  proto._adjustDialog = function(...args) {
    if (!this._element) return
    return origAdjustDialog.apply(this, args)
  }

  const origResetAdjustments = proto._resetAdjustments
  proto._resetAdjustments = function(...args) {
    if (!this._element) return
    return origResetAdjustments.apply(this, args)
  }
}

// Clean up any lingering backdrops before Turbo saves a snapshot to its page cache
if (typeof document !== "undefined") {
  document.addEventListener("turbo:before-cache", () => {
    document.querySelectorAll(".modal.show").forEach(el => {
      const modal = window.bootstrap?.Modal?.getInstance(el)
      if (modal) {
        try {
          modal.hide()
        } catch (_) {}
      }
    })
    document.querySelectorAll(".modal-backdrop").forEach(el => el.remove())
    document.body.classList.remove("modal-open")
    document.body.style.removeProperty("overflow")
    document.body.style.removeProperty("padding-right")
  })
}

export default class extends Controller {
  static values = {
    autoOpen: Boolean // default is false, set to true to make modal auto-opened
  }

  connect() {
    patchBootstrapModal()

    const bootstrapModal = window.bootstrap?.Modal || (typeof bootstrap !== "undefined" ? bootstrap.Modal : null)
    if (bootstrapModal) {
      this.modal = bootstrapModal.getOrCreateInstance(this.element)
      if (this.autoOpenValue) {
        this.modal.show()
      }
    }

    this.closeHandler = () => this.close()
    window.addEventListener("close-modal", this.closeHandler)
  }

  disconnect() {
    window.removeEventListener("close-modal", this.closeHandler)

    const bootstrapModal = window.bootstrap?.Modal || (typeof bootstrap !== "undefined" ? bootstrap.Modal : null)
    const instance = this.modal || (bootstrapModal ? bootstrapModal.getInstance(this.element) : null)

    if (instance) {
      try {
        instance.hide()
      } catch (_) {}
      try {
        instance.dispose()
      } catch (_) {}
      this.modal = null
    }

    // Only clean up backdrops and restore body scrolling if no other modals remain open
    const otherOpenModals = Array.from(document.querySelectorAll(".modal.show")).filter(el => el !== this.element)
    if (otherOpenModals.length === 0) {
      document.querySelectorAll(".modal-backdrop").forEach(el => el.remove())
      document.body.classList.remove("modal-open")
      document.body.style.removeProperty("overflow")
      document.body.style.removeProperty("padding-right")
    }
  }

  close() {
    const bootstrapModal = window.bootstrap?.Modal || (typeof bootstrap !== "undefined" ? bootstrap.Modal : null)
    const instance = this.modal || (bootstrapModal ? bootstrapModal.getInstance(this.element) : null)
    if (instance) {
      try {
        instance.hide()
      } catch (_) {}
    }
  }
}