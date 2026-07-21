import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navbar", "button"]

  connect() {
    console.log("Secondary Nav Controller connected!")
    // Bind the handlers so they can be removed on disconnect
    this.handleShown = () => {
      this.buttonTarget.title = this.buttonTarget.dataset.titleClose
    }
    
    this.handleHidden = () => {
      this.buttonTarget.title = this.buttonTarget.dataset.titleOpen
    }

    // Đăng ký sự kiện Bootstrap từ tầng DOM của targets
    this.navbarTarget.addEventListener("shown.bs.collapse", this.handleShown)
    this.navbarTarget.addEventListener("hidden.bs.collapse", this.handleHidden)
  }

  disconnect() {
    // Bắt buộc phải gỡ bỏ event listener để tránh rò rỉ bộ nhớ khi Turbo chuyển trang
    if (this.hasNavbarTarget) {
      this.navbarTarget.removeEventListener("shown.bs.collapse", this.handleShown)
      this.navbarTarget.removeEventListener("hidden.bs.collapse", this.handleHidden)
    }
  }
}