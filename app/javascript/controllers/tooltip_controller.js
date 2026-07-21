import { Controller } from "@hotwired/stimulus"

// Đảm bảo dự án của bạn đã import Bootstrap (thường là trong application.js)
// Nếu chưa có đối tượng bootstrap toàn cục, bạn có thể import trực tiếp:
// import bootstrap from "bootstrap/dist/js/bootstrap.bundle.js"

export default class extends Controller {
  connect() {
    // Initialize Bootstrap Tooltip
    this.tooltip = bootstrap.Tooltip.getOrCreateInstance(this.element)
  }

  disconnect() {
    // Hủy Tooltip để tránh rò rỉ bộ nhớ khi phần tử bị Turbo xóa bỏ
    if (this.tooltip) {
      this.tooltip.dispose()
    }
  }
}
