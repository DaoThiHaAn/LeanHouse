import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "monthInput",
    "floorSelect",
    "roomSelect",
    "invoiceTypeSelect",
    "individualNotice",
    "individualNoticeText",
    "tenantWrapper",
    "tenantSelect"
  ]

  static values = {
    previewUrl: String,
    rooms: Array,
    selectRoomPrompt: String,
    selectTenantPrompt: String
  }

  connect() {
    this.toggleIndividualNotice()
    if (this.hasRoomSelectTarget && this.roomSelectTarget.value) {
      const room = this.findRoom(this.roomSelectTarget.value)
      if (room && this.hasFloorSelectTarget && !this.floorSelectTarget.value) {
        this.floorSelectTarget.value = room.floor_id
      }
    }
  }

  toggleIndividualNotice() {
    if (!this.hasInvoiceTypeSelectTarget || !this.hasIndividualNoticeTarget) return
    const isIndividual = this.invoiceTypeSelectTarget.value === "individual"
    this.individualNoticeTarget.classList.toggle("d-none", !isIndividual)

    if (isIndividual && this.hasIndividualNoticeTextTarget && this.hasRoomSelectTarget) {
      const room = this.findRoom(this.roomSelectTarget.value)
      if (room && room.tenants_count) {
        this.individualNoticeTextTarget.textContent = `Hệ thống sẽ tự động chia đều tiền phòng và các dịch vụ chung theo số người đang ở trong phòng (${room.tenants_count} người), và xuất hóa đơn riêng cho từng người thuê.`
      }
    }
  }

  floorChanged() {
    if (!this.hasFloorSelectTarget || !this.hasRoomSelectTarget) return
    const floorId = this.floorSelectTarget.value
    this.filterRoomsByFloor(floorId)
    this.roomSelectTarget.value = ""
    this.toggleIndividualNotice()
    this.updatePreview()
  }

  roomChanged() {
    if (!this.hasRoomSelectTarget) return
    const roomId = this.roomSelectTarget.value
    const room = this.findRoom(roomId)
    if (room && this.hasFloorSelectTarget && !this.floorSelectTarget.value) {
      this.floorSelectTarget.value = room.floor_id
    }
    this.toggleIndividualNotice()
    this.updatePreview()
  }

  invoiceTypeChanged() {
    this.toggleIndividualNotice()
    this.updatePreview()
  }

  tenantChanged() {
    this.updatePreview()
  }

  monthChanged() {
    this.updatePreview()
  }

  filterRoomsByFloor(floorId) {
    if (!this.hasRoomSelectTarget) return
    const select = this.roomSelectTarget
    const currentVal = select.value
    select.innerHTML = ""

    const promptOption = document.createElement("option")
    promptOption.value = ""
    promptOption.textContent = this.selectRoomPromptValue || "-- Chọn phòng --"
    select.appendChild(promptOption)

    const rooms = this.roomsValue || []
    const filteredRooms = floorId
      ? rooms.filter(r => String(r.floor_id) === String(floorId))
      : rooms

    filteredRooms.forEach(room => {
      const opt = document.createElement("option")
      opt.value = room.id
      opt.textContent = floorId ? room.name : `${room.name} (${room.floor_name})`
      select.appendChild(opt)
    })

    if (filteredRooms.some(r => String(r.id) === String(currentVal))) {
      select.value = currentVal
    } else {
      select.value = ""
    }
  }

  populateTenantsForRoom(room) {
    if (!this.hasTenantSelectTarget) return
    const select = this.tenantSelectTarget
    const currentVal = select.value
    select.innerHTML = ""

    if (!room || !room.tenants || room.tenants.length === 0) {
      const opt = document.createElement("option")
      opt.value = ""
      opt.textContent = this.selectTenantPromptValue || "-- Chọn người thuê --"
      select.appendChild(opt)
      select.value = ""
      return
    }

    room.tenants.forEach(t => {
      const opt = document.createElement("option")
      opt.value = t.id
      opt.textContent = t.name
      select.appendChild(opt)
    })

    if (room.tenants.some(t => String(t.id) === String(currentVal))) {
      select.value = currentVal
    } else {
      select.value = room.tenants[0].id
    }
  }

  findRoom(roomId) {
    if (!this.roomsValue || !roomId) return null
    return this.roomsValue.find(r => String(r.id) === String(roomId))
  }

  updatePreview() {
    this.toggleIndividualNotice()

    const month = this.hasMonthInputTarget ? this.monthInputTarget.value : ""
    const roomId = this.hasRoomSelectTarget ? this.roomSelectTarget.value : ""
    const invoiceType = this.hasInvoiceTypeSelectTarget ? this.invoiceTypeSelectTarget.value : "room"

    if (!this.previewUrlValue) return

    const url = new URL(this.previewUrlValue, window.location.origin)
    url.searchParams.set("room_id", roomId)
    url.searchParams.set("month", month)
    url.searchParams.set("invoice_type", invoiceType)

    fetch(url.toString(), {
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then(res => res.text())
      .then(html => {
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, "text/html")
        const newFrame = doc.querySelector("turbo-frame#draft_items_form")
        const currentFrame = document.querySelector("turbo-frame#draft_items_form")
        if (newFrame && currentFrame) {
          currentFrame.replaceWith(newFrame)
          setTimeout(() => {
            if (typeof window.recalculateInvoiceTotals === "function") {
              window.recalculateInvoiceTotals()
            }
          }, 50)
        }
      })
      .catch(error => {
        console.error("Failed to update draft invoice preview:", error)
      })
  }
}
