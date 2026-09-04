import { Controller } from "@hotwired/stimulus"

/**
 * Controller: filter-floor-room
 * Purpose: Provides cascading Floor -> Room dropdown selection for filter toolbars.
 *
 * Where it is used:
 * - app/views/landlord_portal/service_usage_logs/index.html.erb (Service usage logs filter toolbar)
 *
 * Distinction from other floor/room controllers:
 * - dependent_rental_unit_controller.js: Used in modal forms (e.g., Bed creation) to cascade Floor -> Room -> Bed -> RentalUnit ID.
 * - room_selection_controller.js: Used for checkbox multi-selection grouped by floor in service variant assignment.
 * - filter_form_controller.js: Used for general filter forms (handling clear buttons, year/month changes).
 *
 * Targets:
 * - floor: The select element for choosing a floor.
 * - room: The select element for choosing a room.
 *
 * Values:
 * - rooms: Array of objects { id, name, floor_id } representing active rooms in the house.
 * - allRoomsLabel: Localized text for the default "all rooms" option (e.g., "Tất cả các phòng").
 */
export default class extends Controller {
  static targets = ["floor", "room"]
  static values = {
    rooms: Array,
    allRoomsLabel: { type: String, default: "Tất cả các phòng" }
  }

  floorChanged() {
    if (!this.hasRoomTarget) return

    const selectedFloorId = this.hasFloorTarget ? this.floorTarget.value : ""
    const currentRoomId = this.roomTarget.value

    // Filter rooms by selected floor, or show all rooms if no floor is selected
    const filteredRooms = selectedFloorId
      ? this.roomsValue.filter((room) => String(room.floor_id) === String(selectedFloorId))
      : this.roomsValue

    // Check if the currently selected room is part of the filtered list
    const keepCurrent = filteredRooms.some((room) => String(room.id) === String(currentRoomId))

    // Rebuild room select options cleanly
    this.roomTarget.replaceChildren()

    const defaultOption = new Option(this.allRoomsLabelValue, "")
    this.roomTarget.add(defaultOption)

    filteredRooms.forEach((room) => {
      const option = new Option(room.name, room.id)
      if (keepCurrent && String(room.id) === String(currentRoomId)) {
        option.selected = true
      }
      this.roomTarget.add(option)
    })

    if (!keepCurrent) {
      this.roomTarget.value = ""
    }

    // Submit the form to update Turbo Frame logs_table
    this.element.requestSubmit()
  }

  roomChanged() {
    this.element.requestSubmit()
  }
}
