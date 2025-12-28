// app/javascript/controllers/location_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["province", "commune"]
  static values = {
    provinces: Array,
    communes: Array
  }

  connect() {
    console.log("Location controller connected!")
    this.populateProvinces()
  }

  populateProvinces() {
    this.provincesValue.forEach(p => {
      const option = new Option(p.name, p.idProvince)
      this.provinceTarget.add(option)
    })
  }

  provinceChanged() {
    const provinceId = this.provinceTarget.value

    this.communeTarget.length = 1 // keep prompt

    if (!provinceId) {
      this.communeTarget.disabled = true
      return
    }

    this.communesValue
      .filter(c => c.idProvince === provinceId)
      .forEach(c => {
        this.communeTarget.add(new Option(c.name, c.idCommune))
      })

    this.communeTarget.disabled = false
  }
}
