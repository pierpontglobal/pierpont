import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { endsAt: String }

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() { clearInterval(this.timer) }

  tick() {
    const left = Math.max(0, Math.floor((Date.parse(this.endsAtValue) - Date.now()) / 1000))
    if (left === 0) {
      this.element.textContent = "Ended"
      clearInterval(this.timer)
      return
    }
    const d = Math.floor(left / 86400), h = Math.floor(left % 86400 / 3600), m = Math.floor(left % 3600 / 60), s = left % 60
    const pad = (n) => String(n).padStart(2, "0")
    this.element.textContent = d > 0 ? `${d}d ${h}h left` : h > 0 ? `${h}h ${pad(m)}m left` : `${pad(m)}:${pad(s)} left`
    this.element.classList.toggle("urgent", left < 600)
  }
}
