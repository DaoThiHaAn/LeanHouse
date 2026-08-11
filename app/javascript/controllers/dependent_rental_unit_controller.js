import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["floor", "room", "bed", "rentalUnit"]
  static values = { rooms: Array, beds: Array, bedMode: Boolean }

  connect() {
    this.floorChanged()
  }

  floorChanged() {
    const rooms = this.roomsValue.filter((room) => String(room.floorId) === this.floorTarget.value)
    this.replaceOptions(this.roomTarget, rooms, "Phòng")

    if (this.bedModeValue) {
      this.roomChanged()
    } else {
      this.rentalUnitTarget.value = this.roomTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
    }
  }

  roomChanged() {
    if (!this.bedModeValue) {
      this.rentalUnitTarget.value = this.roomTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
      return
    }

    const beds = this.bedsValue.filter((bed) => String(bed.roomId) === this.roomTarget.value)
    this.replaceOptions(this.bedTarget, beds, "Giường")
    this.rentalUnitTarget.value = this.bedTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
  }

  bedChanged() {
    this.rentalUnitTarget.value = this.bedTarget.selectedOptions[0]?.dataset.rentalUnitId || ""
  }

  replaceOptions(select, options, label) {
    select.replaceChildren(new Option(`Chọn ${label}`, ""))

    options.forEach((option) => {
      const element = new Option(option.name, option.id)
      element.dataset.rentalUnitId = option.rentalUnitId
      select.add(element)
    })

    select.disabled = options.length === 0
  }
}
