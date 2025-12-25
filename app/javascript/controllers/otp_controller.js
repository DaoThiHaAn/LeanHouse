import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden", "form"]
  static values = { length: Number }

  connect() {
    // Focus the first empty input
    const firstEmpty = this.digitTargets.find(i => !i.value)
    if (firstEmpty) firstEmpty.focus()
  }

  input(e) {
    const input = e.target

    // Only digits
    input.value = input.value.replace(/\D/g, "").slice(0, 1)

    this.updateHidden()

    if (input.value) {
      const nextInput = this.next(input)
      if (nextInput) {
        // Slight timeout helps Firefox focus reliably
        setTimeout(() => nextInput.focus(), 0)
      }
    }
}


  keydown(e) {
    const input = e.target
    const index = this.digitTargets.indexOf(input)

    switch (e.key) {
      case "Backspace":
        if (!input.value && index > 0) {
          this.digitTargets[index - 1].focus()
        } else {
          input.value = ""
        }
        e.preventDefault()
        break
      case "ArrowLeft":
        if (index > 0) this.digitTargets[index - 1].focus()
        e.preventDefault()
        break
      case "ArrowRight":
        if (index < this.digitTargets.length - 1) this.digitTargets[index + 1].focus()
        e.preventDefault()
        break
    }
  }

  paste(e) {
    e.preventDefault()
    const paste = e.clipboardData.getData("text").replace(/\D/g, "")
    this.digitTargets.forEach((input, i) => {
      input.value = paste[i] || ""
    })
    this.updateHidden()

    // Focus first empty box
    const firstEmpty = this.digitTargets.find(i => !i.value)
    if (firstEmpty) firstEmpty.focus()
  }

  upupdateHidden() {
    const code = this.digitTargets.map(i => i.value).join("")
    this.hiddenTarget.value = code

    // Auto-submit when full
    if (code.length === this.lengthValue && this.formTarget) {
      // Delay to ensure this runs after focus changes
      setTimeout(() => {
        this.formTarget.requestSubmit()
      }, 0)
    }
  }


  next(input) {
    const i = this.digitTargets.indexOf(input)
    return i < this.digitTargets.length - 1 ? this.digitTargets[i + 1] : null
  }

  previous(input) {
    const i = this.digitTargets.indexOf(input)
    return i > 0 ? this.digitTargets[i - 1] : null
  }
}

