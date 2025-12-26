// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
// import * as bootstrap from "bootstrap"

document.addEventListener("turbo:load", () => {
  const tooltipTriggerList = document.querySelectorAll('[title]')
  tooltipTriggerList.forEach(el => {
    new bootstrap.Tooltip(el)
  })
})
