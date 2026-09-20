import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "container", "existing", "purgeInput", "requiredAsterisk"]
  static values = {
    storageKey: String
  }

  connect() {
    this.currentUrl = null
    this.boundSubmitSuccess = () => this.clearStorage()

    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("turbo:submit-success", this.boundSubmitSuccess)
    }

    this.restoreIfAvailable()
  }

  disconnect() {
    this.revokeUrl()
    const form = this.element.closest("form")
    if (form && this.boundSubmitSuccess) {
      form.removeEventListener("turbo:submit-success", this.boundSubmitSuccess)
    }
  }

  restoreIfAvailable() {
    // 1. If input already has files (e.g. preserved by browser), preview it
    if (this.hasInputTarget && this.inputTarget.files && this.inputTarget.files.length > 0) {
      this.preview()
      return
    }

    // 2. If sessionStorage has saved file and input has no files, restore preview and file
    if (this.hasStorageKeyValue && this.storageKeyValue) {
      try {
        const raw = sessionStorage.getItem(this.storageKeyValue)
        if (raw) {
          const saved = JSON.parse(raw)
          if (saved && saved.dataUrl) {
            if (this.hasPreviewTarget) {
              this.previewTarget.src = saved.dataUrl
            }
            if (this.hasContainerTarget) {
              this.containerTarget.classList.remove("d-none")
            }
            if (this.hasExistingTarget) {
              this.existingTarget.classList.add("d-none")
            }
            if (this.hasRequiredAsteriskTarget) {
              this.requiredAsteriskTarget.classList.add("d-none")
            }
            if (this.hasInputTarget) {
              this.inputTarget.required = false
              const arr = saved.dataUrl.split(",")
              const mime = arr[0].match(/:(.*?);/)[1]
              const bstr = atob(arr[1])
              let n = bstr.length
              const u8arr = new Uint8Array(n)
              while (n--) {
                u8arr[n] = bstr.charCodeAt(n)
              }
              const file = new File([u8arr], saved.fileName || "meter_photo.png", { type: mime })
              const dt = new DataTransfer()
              dt.items.add(file)
              this.inputTarget.files = dt.files
            }
          }
        }
      } catch (e) {
        console.warn("Could not restore file from sessionStorage", e)
      }
    }
  }

  preview() {
    const file = this.hasInputTarget && this.inputTarget.files && this.inputTarget.files[0]
    if (file && file.type.startsWith("image/")) {
      this.revokeUrl()
      this.currentUrl = URL.createObjectURL(file)

      if (this.hasPreviewTarget) {
        this.previewTarget.src = this.currentUrl
      }
      if (this.hasContainerTarget) {
        this.containerTarget.classList.remove("d-none")
      }
      if (this.hasExistingTarget) {
        this.existingTarget.classList.add("d-none")
      }
      if (this.hasPurgeInputTarget) {
        this.purgeInputTarget.value = "0"
      }
      if (this.hasRequiredAsteriskTarget) {
        this.requiredAsteriskTarget.classList.add("d-none")
      }

      if (this.hasStorageKeyValue && this.storageKeyValue) {
        const reader = new FileReader()
        reader.onload = (e) => {
          try {
            sessionStorage.setItem(this.storageKeyValue, JSON.stringify({
              fileName: file.name,
              dataUrl: e.target.result
            }))
          } catch (err) {
            console.warn("Storage limit exceeded or unavailable", err)
          }
        }
        reader.readAsDataURL(file)
      }
    }
  }

  clear() {
    this.clearStorage()
    this.revokeUrl()

    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.required = true
    }
    if (this.hasPreviewTarget) {
      this.previewTarget.src = ""
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("d-none")
    }
    if (this.hasExistingTarget) {
      this.existingTarget.classList.add("d-none")
    }
    if (this.hasPurgeInputTarget) {
      this.purgeInputTarget.value = "1"
    }
    if (this.hasRequiredAsteriskTarget) {
      this.requiredAsteriskTarget.classList.remove("d-none")
    }
  }

  clearStorage() {
    if (this.hasStorageKeyValue && this.storageKeyValue) {
      try {
        sessionStorage.removeItem(this.storageKeyValue)
      } catch (e) {
        // ignore
      }
    }
  }

  revokeUrl() {
    if (this.currentUrl) {
      URL.revokeObjectURL(this.currentUrl)
      this.currentUrl = null
    }
  }
}
