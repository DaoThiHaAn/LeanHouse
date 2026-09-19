import { Controller } from "@hotwired/stimulus"

// Stimulus controller to dynamically toggle the required state and asterisk
// of latest_reading based on the confirmation mode radio selection (confirm now vs await tenant submission),
// and dynamically constrain latest_reading to be greater than or equal to prev_reading.
export default class extends Controller {
  static targets = ["latestReadingInput", "latestReadingAsterisk", "prevReadingInput", "photoUploadWrapper"]

  connect() {
    this.updateRequirement()
    this.updateMinReading()
  }

  // Triggered when switching between "Xác nhận & chốt số ngay" and "Chờ người thuê chụp ảnh / nộp số"
  toggleConfirmation() {
    this.updateRequirement()
  }

  // If is_confirmed: true -> latest_reading is required, asterisk is shown, and photo upload is visible.
  // If is_confirmed: false -> latest_reading is optional (tenant will submit), asterisk is hidden, and photo upload is hidden (d-none).
  updateRequirement() {
    const checkedRadio = this.element.querySelector('input[name="service_usage_log[is_confirmed]"]:checked')
    const isConfirmed = checkedRadio ? checkedRadio.value === "true" : true

    if (this.hasLatestReadingInputTarget) {
      this.latestReadingInputTarget.required = isConfirmed
    }

    if (this.hasLatestReadingAsteriskTarget) {
      this.latestReadingAsteriskTarget.classList.toggle("d-none", !isConfirmed)
    }

    if (this.hasPhotoUploadWrapperTarget) {
      this.photoUploadWrapperTarget.classList.toggle("d-none", !isConfirmed)
      const fileInput = this.photoUploadWrapperTarget.querySelector('input[type="file"]')
      if (fileInput) {
        fileInput.disabled = !isConfirmed
      }
    }
  }

  // Ensures latest_reading input has its HTML5 min attribute set to current prev_reading value
  updateMinReading() {
    if (this.hasPrevReadingInputTarget && this.hasLatestReadingInputTarget) {
      const prevVal = this.prevReadingInputTarget.value
      if (prevVal !== "" && !isNaN(prevVal)) {
        this.latestReadingInputTarget.min = prevVal
      } else {
        this.latestReadingInputTarget.removeAttribute("min")
      }
    }
  }
}
