import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["province", "commune"]
  static values = {
    provinces: Array,
    communes: Array,
    selectedProvince: String, // for edit form
    selectedCommune: String
  }

  connect() {
    console.log("Location controller connected!")

    this.populateProvinces()
    
    if (this.hasSelectedProvinceValue) {
      this.provinceTarget.value = this.selectedProvinceValue
      this.provinceChanged()
    }

    if (this.hasSelectedCommuneValue) {
      this.communeTarget.value = this.selectedCommuneValue
    }
  }

  populateProvinces() {
    this.provincesValue.forEach(p => {
      const option = new Option(p.name, p.name)
      option.dataset.id = p.idProvince
      this.provinceTarget.add(option)
    })
  }

  provinceChanged() {
    const selected = this.provinceTarget.selectedOptions[0]

    if (!selected || !selected.dataset.id) {
      this.communeTarget.length = 1
      this.communeTarget.disabled = true
      return
    }

    const provinceId = selected.dataset.id

    this.communeTarget.length = 1

    this.communesValue
      .filter(c => c.idProvince === provinceId)
      .forEach(c => {
        const option = new Option(c.name, c.name)
        option.dataset.id = c.idCommune
        this.communeTarget.add(option)
      })

    this.communeTarget.disabled = false

    if (this.hasSelectedCommuneValue) {
      this.communeTarget.value = this.selectedCommuneValue
    }
  }
}
