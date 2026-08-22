import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["floor", "room", "bed", "rentalUnit"]
  static values = { rooms: Array, beds: Array, bedMode: Boolean }

  connect() {
    if (this.hasFloorTarget) {
      this.floorChanged()
    }
  }

  floorChanged() {
    if (!this.hasRoomTarget) return

    const rooms = this.roomsValue.filter((room) => String(room.floorId) === this.floorTarget.value)
    this.replaceOptions(this.roomTarget, rooms, "Phòng")

    if (this.bedModeValue) {
      if (this.hasRentalUnitTarget) {
        this.rentalUnitTarget.value = ""
      }
      return
    }

    if (this.hasRentalUnitTarget) {
      this.rentalUnitTarget.value = this.roomTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
    }
  }

  roomChanged() {
    if (!this.hasRoomTarget) return

    if (!this.bedModeValue) {
      if (this.hasRentalUnitTarget) {
        this.rentalUnitTarget.value = this.roomTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
      }
      return
    }

    if (!this.hasBedTarget) {
      if (this.hasRentalUnitTarget) {
        this.rentalUnitTarget.value = ""
      }
      return
    }

    const beds = this.bedsValue.filter((bed) => String(bed.roomId) === this.roomTarget.value)
    this.replaceOptions(this.bedTarget, beds, "Giường")
    this.rentalUnitTarget.value = this.bedTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
  }

  bedChanged() {
    if (!this.hasBedTarget || !this.hasRentalUnitTarget) return
    this.rentalUnitTarget.value = this.bedTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
  }

  replaceOptions(select, options, label) {
    // Lấy giá trị đã chọn sẵn từ dataset hoặc giá trị hiện tại của select
    const selectedValue = select.dataset.selectedValue || select.value
    select.replaceChildren(new Option(`Chọn ${label}`, ""))
    options.forEach((option) => {
      const element = new Option(option.name, option.id)
      element.dataset.rentalUnitId = option.rentalUnitId || ""
      select.add(element)
    })
    // Chọn lại option tương ứng
    if (selectedValue) {
      select.value = selectedValue
      delete select.dataset.selectedValue // Xóa dataset sau lần đầu để các lần đổi tầng tiếp theo hoạt động bình thường
    }
    select.disabled = options.length === 0
  }
}
