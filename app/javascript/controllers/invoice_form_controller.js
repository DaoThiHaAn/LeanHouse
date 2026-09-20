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
    selectTenantPrompt: String,
    previewErrorText: String,
    retryText: String
  }

  connect() {
    this.syncFormStateAndPreview()
    setTimeout(() => this.syncFormStateAndPreview(), 50)
  }

  disconnect() {
    if (this.previewAbortController) {
      this.previewAbortController.abort()
    }
    this.lastFetchKey = null
  }

  syncFormStateAndPreview() {
    this.toggleIndividualNotice()

    if (!this.hasRoomSelectTarget) return

    const roomId = this.roomSelectTarget.value
    if (!roomId) return

    const room = this.findRoom(roomId)
    if (room && this.hasFloorSelectTarget && !this.floorSelectTarget.value) {
      this.floorSelectTarget.value = room.floor_id
    }

    if (this.hasFloorSelectTarget && this.floorSelectTarget.value) {
      this.filterRoomsByFloor(this.floorSelectTarget.value)
    }

    const frame = document.querySelector("turbo-frame#draft_items_form")
    const loadedRoomId = frame ? frame.dataset.currentRoomId : null
    const hasTable = frame ? !!frame.querySelector("#invoice_items_table") : false

    if (!hasTable || String(loadedRoomId) !== String(roomId)) {
      this.updatePreview()
    } else {
      const month = this.hasMonthInputTarget ? this.monthInputTarget.value : ""
      const invoiceType = this.hasInvoiceTypeSelectTarget ? this.invoiceTypeSelectTarget.value : "room"
      this.lastFetchKey = `${roomId}_${month}_${invoiceType}`
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

    // Synchronize browser URL query parameters so page reload (F5) retains selected room, month, and mode
    try {
      const currentUrl = new URL(window.location.href)
      if (roomId) {
        currentUrl.searchParams.set("room_id", roomId)
      } else {
        currentUrl.searchParams.delete("room_id")
      }
      if (month) {
        currentUrl.searchParams.set("month", month)
      }
      if (invoiceType) {
        currentUrl.searchParams.set("invoice_type", invoiceType)
      }
      window.history.replaceState({}, "", currentUrl.toString())
    } catch (e) {
      // Ignore if URL modification is not permitted
    }

    if (!this.previewUrlValue) return

    const fetchKey = `${roomId}_${month}_${invoiceType}`
    if (this.lastFetchKey === fetchKey) {
      const activeFrame = document.querySelector("turbo-frame#draft_items_form")
      const hasTable = activeFrame ? !!activeFrame.querySelector("#invoice_items_table") : false
      if (hasTable) return
    }
    this.lastFetchKey = fetchKey

    if (this.previewAbortController) {
      this.previewAbortController.abort()
    }
    this.previewAbortController = new AbortController()

    const currentFrame = document.querySelector("turbo-frame#draft_items_form")
    if (currentFrame && roomId) {
      currentFrame.innerHTML = this.renderSkeletonHtml()
    }

    const url = new URL(this.previewUrlValue, window.location.origin)
    url.searchParams.set("room_id", roomId)
    url.searchParams.set("month", month)
    url.searchParams.set("invoice_type", invoiceType)

    fetch(url.toString(), {
      signal: this.previewAbortController.signal,
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then(res => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.text()
      })
      .then(html => {
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, "text/html")
        const newFrame = doc.querySelector("turbo-frame#draft_items_form")
        const activeFrame = document.querySelector("turbo-frame#draft_items_form")

        if (newFrame && activeFrame) {
          activeFrame.replaceWith(newFrame)
          setTimeout(() => {
            if (typeof window.recalculateInvoiceTotals === "function") {
              window.recalculateInvoiceTotals()
            }
          }, 50)
        } else if (activeFrame) {
          throw new Error("Frame not found in response")
        }
      })
      .catch(error => {
        if (error.name === "AbortError") return
        this.lastFetchKey = null
        console.error("Failed to update draft invoice preview:", error)
        const activeFrame = document.querySelector("turbo-frame#draft_items_form")
        if (activeFrame) {
          const errorMsg = this.previewErrorTextValue || "Không thể tải danh sách dịch vụ. Vui lòng thử lại."
          const retryBtn = this.retryTextValue || "Thử lại"
          activeFrame.innerHTML = `
            <div class="card invoice-card mb-4 border-danger-subtle shadow-sm">
              <div class="card-body p-4 text-center">
                <div class="d-inline-flex align-items-center justify-content-center p-3 rounded-circle bg-danger-subtle text-danger mb-3">
                  <span class="material-symbols-outlined fs-2">error</span>
                </div>
                <h5 class="fw-bold text-danger mb-2">${errorMsg}</h5>
                <button type="button" class="btn btn-sm btn-outline-danger d-inline-flex align-items-center gap-1 px-3 py-2 mt-2" data-action="click->invoice-form#updatePreview">
                  <span class="material-symbols-outlined fs-6">refresh</span>
                  <span>${retryBtn}</span>
                </button>
              </div>
            </div>
          `
        }
      })
  }

  // Skeleton table while fetching data
  renderSkeletonHtml() {
    return `
      <div class="card invoice-card mb-4 placeholder-glow">
        <div class="card-header bg-body-secondary py-3 border-bottom d-flex justify-content-between align-items-center">
          <div class="w-50">
            <span class="placeholder col-6 rounded py-2 d-block"></span>
            <span class="placeholder col-9 rounded d-block mt-2"></span>
          </div>
          <span class="placeholder col-3 rounded py-3"></span>
        </div>

        <div class="table-responsive">
          <table class="table invoice-table align-middle mb-0">
            <thead>
              <tr>
                <th class="ps-3 text-center th-check"><span class="placeholder col-6"></span></th>
                <th><span class="placeholder col-7"></span></th>
                <th class="th-unit text-center"><span class="placeholder col-6"></span></th>
                <th class="th-price text-end"><span class="placeholder col-6"></span></th>
                <th class="th-reading"><span class="placeholder col-8"></span></th>
                <th class="text-end th-amount"><span class="placeholder col-6"></span></th>
                <th class="text-center pe-3 th-action">-</th>
              </tr>
            </thead>

            <tbody>
              ${[1, 2, 3, 4].map(() => `
                <tr class="item-row align-middle">
                  <td class="ps-3 text-center"><span class="placeholder col-6 rounded py-2"></span></td>
                  <td>
                    <span class="placeholder col-7 rounded py-2 d-block mb-1"></span>
                    <span class="placeholder col-4 rounded small"></span>
                  </td>
                  <td><span class="placeholder col-6 rounded py-2 d-block mx-auto"></span></td>
                  <td><span class="placeholder col-6 rounded py-2 d-block ms-auto"></span></td>
                  <td>
                    <span class="placeholder col-10 rounded py-2 d-block mb-1"></span>
                    <span class="placeholder col-10 rounded py-2 d-block"></span>
                  </td>
                  <td class="text-end"><span class="placeholder col-7 rounded py-2 d-block ms-auto"></span></td>
                  <td class="text-center pe-3 text-secondary">-</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
        </div>

        <div class="card-footer bg-light p-3 border-top">
          <div class="row g-3 align-items-center justify-content-between">
            <div class="col-md-7">
              <span class="placeholder col-5 rounded d-block mb-2"></span>
              <span class="placeholder col-4 rounded d-block mb-2"></span>
              <span class="placeholder col-4 rounded d-block"></span>
            </div>
            <div class="col-md-5 text-md-end">
              <span class="placeholder col-4 rounded d-block ms-md-auto mb-1"></span>
              <span class="placeholder col-6 rounded py-3 d-block ms-md-auto"></span>
            </div>
          </div>
        </div>
      </div>
    `
  }
}
