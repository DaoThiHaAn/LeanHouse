import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden", "form", "copyLabel"]
  static values = { length: Number }

  connect() {
    const firstEmpty = this.digitTargets.find(i => !i.value)
    if (firstEmpty) firstEmpty.focus()
  }

  input(e) {
    const input = e.target

    // Allow only 1 digit
    input.value = input.value.replace(/\D/g, "").slice(0, 1)

    this.updateHidden()

    if (input.value) {
      const next = this.next(input)
      if (next) {
        setTimeout(() => next.focus(), 0) // Firefox-safe
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
        if (index < this.digitTargets.length - 1) {
          this.digitTargets[index + 1].focus()
        }
        e.preventDefault()
        break
    }

    this.updateHidden()
  }

  paste(e) {
    e.preventDefault()
    const paste = e.clipboardData.getData("text").replace(/\D/g, "")

    this.digitTargets.forEach((input, i) => {
      input.value = paste[i] || ""
    })

    this.updateHidden()

    const firstEmpty = this.digitTargets.find(i => !i.value)
    if (firstEmpty) firstEmpty.focus()
  }

  updateHidden() {
    const code = this.digitTargets.map(i => i.value).join("")
    this.hiddenTarget.value = code
    console.log("Completed code: ", code)
  }

  next(input) {
    const i = this.digitTargets.indexOf(input)
    return i < this.digitTargets.length - 1 ? this.digitTargets[i + 1] : null
  }

  fillDemo(e) {
    const code = e.currentTarget.dataset.otpCode || ""
    if (!code) return

    this.digitTargets.forEach((input, i) => {
      input.value = code[i] || ""
    })

    this.updateHidden()

    const last = this.digitTargets[this.digitTargets.length - 1]
    if (last) last.focus()
  }

  copyDemo(e) {
    const code = e.currentTarget.dataset.otpCode || ""
    if (!code) return

    const btn = e.currentTarget
    const labelSpan = btn.querySelector("[data-otp-target='copyLabel']") || btn
    const originalText = labelSpan.innerText

    navigator.clipboard.writeText(code).then(() => {
      labelSpan.innerText = btn.dataset.copiedText || "Đã chép!"
      setTimeout(() => {
        labelSpan.innerText = originalText
      }, 2000)
    }).catch(err => {
      console.warn("Clipboard write failed:", err)
    })
  }
}
