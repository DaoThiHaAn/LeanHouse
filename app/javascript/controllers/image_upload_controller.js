import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "previewContainer", "errorMessage"]
  static values = {
    maxFiles: { type: Number, default: 10 },
    maxSizeMb: { type: Number, default: 20 }
  }

  connect() {
    this.files = []
  }

  triggerUpload() {
    this.inputTarget.click()
  }

  handleFiles(event) {
    const selectedFiles = Array.from(event.target.files)
    this.clearError()

    // 1. Kiểm tra tổng số lượng ảnh
    if (this.files.length + selectedFiles.length > this.maxFilesValue) {
      this.showError(`Tối đa chỉ được tải lên ${this.maxFilesValue} ảnh!`)
      return
    }

    // 2. Kiểm tra dung lượng từng ảnh
    const maxSizeBytes = this.maxSizeMbValue * 1024 * 1024
    for (const file of selectedFiles) {
      if (file.size > maxSizeBytes) {
        this.showError(`Ảnh "${file.name}" vượt quá dung lượng tối đa ${this.maxSizeMbValue}MB!`)
        return
      }
    }

    // Cộng dồn danh sách file
    this.files = this.files.concat(selectedFiles)
    this.syncInputFiles()
    this.renderPreviews()
  }

  removeFile(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.files.splice(index, 1)
    this.syncInputFiles()
    this.renderPreviews()
    this.clearError()
  }

  syncInputFiles() {
    const dt = new DataTransfer()
    this.files.forEach((file) => dt.items.add(file))
    this.inputTarget.files = dt.files
  }

  renderPreviews() {
    this.previewContainerTarget.innerHTML = ""

    this.files.forEach((file, index) => {
      const wrapper = document.createElement("div")
      wrapper.className = "position-relative d-inline-block"
      wrapper.style.width = "90px"
      wrapper.style.height = "90px"

      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      img.className = "rounded border object-fit-cover w-100 h-100 shadow-sm"
      img.onload = () => URL.revokeObjectURL(img.src)

      const removeBtn = document.createElement("button")
      removeBtn.type = "button"
      removeBtn.className = "btn btn-danger btn-sm rounded-circle position-absolute top-0 end-0 d-flex align-items-center justify-content-center p-0 shadow"
      removeBtn.style.width = "22px"
      removeBtn.style.height = "22px"
      removeBtn.style.transform = "translate(30%, -30%)"
      removeBtn.innerHTML = '<span class="material-symbols-outlined" style="font-size: 14px;">close</span>'
      removeBtn.dataset.index = index
      removeBtn.dataset.action = "click->image-upload#removeFile"

      wrapper.appendChild(img)
      wrapper.appendChild(removeBtn)
      this.previewContainerTarget.appendChild(wrapper)
    })
  }

  showError(msg) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = msg
      this.errorMessageTarget.classList.remove("d-none")
    } else {
      alert(msg)
    }
  }

  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = ""
      this.errorMessageTarget.classList.add("d-none")
    }
  }
}