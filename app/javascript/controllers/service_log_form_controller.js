import { Controller } from "@hotwired/stimulus"

// Stimulus controller to dynamically toggle the required state and asterisk
// of latest_reading based on the confirmation mode radio selection (confirm now vs await tenant submission),
// and dynamically constrain latest_reading to be greater than or equal to prev_reading.
// Also shows a warning when the selected room has no real-time service variant assigned.
export default class extends Controller {
  static targets = ["latestReadingInput", "latestReadingAsterisk", "prevReadingInput", "photoUploadWrapper", "noVariantWarning", "vacantRoomWarning", "awaitTenantOption", "awaitTenantCard"]
  static values = { roomVariantMap: Object, roomOccupancyMap: Object }

  connect() {
    this.updateRequirement()
    this.updateMinReading()
    this.checkRoomVariants()
    this.checkRoomOccupancy()

    // The nested dependent-rental-unit controller populates and preselects the
    // room during its own connect callback. Recheck on the next turn so the
    // initial room gets the same warnings as a manually selected one.
    setTimeout(() => {
      this.checkRoomVariants()
      this.checkRoomOccupancy()
    }, 0)
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

  // Shows a warning below the variant select when the selected room has no real-time service variant assigned.
  checkRoomVariants() {
    if (!this.hasNoVariantWarningTarget) return

    const roomSelect = this.element.querySelector('[data-dependent-rental-unit-target="room"]')
    const roomId = roomSelect?.value

    const variantIds = roomId ? (this.roomVariantMapValue[roomId] ?? []) : []
    const hasNoVariant = roomId && variantIds.length === 0

    this.noVariantWarningTarget.classList.toggle("d-none", !hasNoVariant)
  }

  checkRoomOccupancy() {
    if (!this.hasVacantRoomWarningTarget) return

    const roomId = this.element.querySelector('[data-dependent-rental-unit-target="room"]')?.value
    const isVacant = roomId && this.roomOccupancyMapValue[roomId] === false
    this.vacantRoomWarningTarget.classList.toggle("d-none", !isVacant)
    this.vacantRoomWarningTarget.classList.toggle("d-flex", isVacant)

    if (this.hasAwaitTenantOptionTarget) {
      this.awaitTenantOptionTarget.disabled = isVacant
      this.awaitTenantCardTarget?.classList.toggle("opacity-50", isVacant)
      this.awaitTenantCardTarget?.classList.toggle("cursor-not-allowed", isVacant)

      if (isVacant) {
        this.element.querySelector("#is_confirmed_true").checked = true
        this.updateRequirement()
      }
    }
  }
}
