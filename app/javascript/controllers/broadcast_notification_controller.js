import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "modal",
    "titleInput",
    "messageInput",
    "urlInput",
    "audienceRadio",
    "levelRadio",
    "previewTitle",
    "previewMessage",
    "previewBtnLink",
    "previewLevelBadge",
    "modalTitle",
    "modalAudience",
    "modalLevelBadge",
    "submitBtn"
  ]

  static values = {
    defaultTitle: String,
    defaultMessage: String,
    audienceAllText: String,
    audienceLandlordsText: String,
    audienceTenantsText: String,
    levelInfoText: String,
    levelWarningText: String,
    levelUrgentText: String
  }

  connect() {
    this.updateTextPreview()
    this.updateAudience()
    this.updateLevel()
  }

  updateTextPreview() {
    const titleVal = (this.hasTitleInputTarget && this.titleInputTarget.value.trim()) || this.defaultTitleValue
    const msgVal = (this.hasMessageInputTarget && this.messageInputTarget.value.trim()) || this.defaultMessageValue

    if (this.hasPreviewTitleTarget) {
      this.previewTitleTarget.textContent = titleVal
    }
    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = titleVal
    }
    if (this.hasPreviewMessageTarget) {
      this.previewMessageTarget.textContent = msgVal
    }

    if (this.hasPreviewBtnLinkTarget && this.hasUrlInputTarget) {
      if (this.urlInputTarget.value.trim()) {
        this.previewBtnLinkTarget.classList.remove("d-none")
      } else {
        this.previewBtnLinkTarget.classList.add("d-none")
      }
    }
  }

  updateAudience() {
    if (!this.hasModalAudienceTarget) return

    const selected = this.audienceRadioTargets.find(radio => radio.checked)
    const val = selected ? selected.value : "all"

    if (val === "landlords") {
      this.modalAudienceTarget.textContent = this.audienceLandlordsTextValue
    } else if (val === "tenants") {
      this.modalAudienceTarget.textContent = this.audienceTenantsTextValue
    } else {
      this.modalAudienceTarget.textContent = this.audienceAllTextValue
    }
  }

  updateLevel() {
    const selected = this.levelRadioTargets.find(radio => radio.checked)
    const val = selected ? selected.value : "info"

    const levelClasses = {
      info: "badge bg-info-subtle text-info-emphasis border border-info-subtle",
      warning: "badge bg-warning-subtle text-warning-emphasis border border-warning-subtle",
      urgent: "badge bg-danger-subtle text-danger border border-danger-subtle"
    }

    const levelTexts = {
      info: this.levelInfoTextValue,
      warning: this.levelWarningTextValue,
      urgent: this.levelUrgentTextValue
    }

    const badgeClass = levelClasses[val] || levelClasses.info
    const text = levelTexts[val] || levelTexts.info

    if (this.hasPreviewLevelBadgeTarget) {
      this.previewLevelBadgeTarget.className = badgeClass
      this.previewLevelBadgeTarget.textContent = text
    }

    if (this.hasModalLevelBadgeTarget) {
      this.modalLevelBadgeTarget.className = badgeClass
      this.modalLevelBadgeTarget.textContent = text
    }
  }

  openConfirmModal(event) {
    if (this.hasFormTarget && !this.formTarget.reportValidity()) {
      if (event) event.preventDefault()
      return
    }

    if (this.hasModalTarget && typeof bootstrap !== "undefined") {
      const modalInstance = bootstrap.Modal.getOrCreateInstance(this.modalTarget)
      modalInstance.show()
    }
  }

  submit(event) {
    if (this.submitting) {
      if (event) event.preventDefault()
      return
    }

    this.submitting = true

    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.classList.add("disabled")
    }

    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }
}
