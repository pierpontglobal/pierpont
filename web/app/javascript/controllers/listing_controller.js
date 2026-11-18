import { Controller } from "@hotwired/stimulus"

const usd = (n) => n.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 })

export default class extends Controller {
  static targets = ["vin", "vinStatus", "year", "make", "model", "trim", "mileage", "body", "color", "photo", "preview", "insights", "suggestions", "estimate", "start"]
  static values = { vinUrl: String, photoUrl: String, estimateUrl: String }

  async post(url, body) {
    const token = document.querySelector("meta[name=csrf-token]")?.content
    const res = await fetch(url, { method: "POST", body, headers: { "X-CSRF-Token": token, Accept: "application/json" } })
    return res.ok ? res.json() : null
  }

  async decode() {
    const vin = this.vinTarget.value.trim().toUpperCase()
    this.vinStatusTarget.textContent = "Decoding…"
    const data = await this.post(this.vinUrlValue, new URLSearchParams({ vin }))
    if (!data) {
      this.vinStatusTarget.textContent = "Couldn't decode that VIN. Check it or fill in the fields."
      return
    }
    for (const key of ["year", "make", "model", "trim"]) if (data[key]) this[`${key}Target`].value = data[key]
    if (data.body_style) this.bodyTarget.value = data.body_style
    this.vinStatusTarget.textContent = `Decoded by NHTSA: ${[data.year, data.make, data.model].join(" ")}`
    this.estimate()
  }

  async analyze() {
    const file = this.photoTarget.files[0]
    if (!file) return
    this.previewTarget.src = URL.createObjectURL(file)
    this.previewTarget.hidden = false
    this.insightsTarget.hidden = false
    this.suggestionsTarget.textContent = "Looking at your photo…"
    const form = new FormData()
    form.append("photo", file)
    const r = await this.post(this.photoUrlValue, form)
    this.suggestionsTarget.textContent = ""
    if (!r) { this.suggestionsTarget.textContent = "Photo analysis is unavailable right now."; return }
    if (!r.is_vehicle) { this.suggestionsTarget.textContent = "This doesn't look like a vehicle. Try another photo."; return }
    const add = (label, apply) => {
      const b = document.createElement("button")
      b.type = "button"
      b.textContent = label
      b.addEventListener("click", apply)
      this.suggestionsTarget.append(b)
    }
    const body = r.body_style[0], color = r.color[0]
    add(`${body.label} · ${Math.round(body.p * 100)}%`, () => { this.bodyTarget.value = body.label })
    add(`${color.label} · ${Math.round(color.p * 100)}%`, () => { this.colorTarget.value = color.label })
    if (!this.bodyTarget.value) this.bodyTarget.value = body.label
    if (!this.colorTarget.value) this.colorTarget.value = color.label
  }

  async estimate() {
    const q = { make: this.makeTarget.value, model: this.modelTarget.value, year: this.yearTarget.value, mileage: this.mileageTarget.value }
    if (Object.values(q).some((v) => !v)) return
    const e = await this.post(this.estimateUrlValue, new URLSearchParams(q))
    if (!e) return
    this.estimateTarget.innerHTML = ""
    const big = document.createElement("p")
    big.innerHTML = `<strong style="font-size:26px;color:var(--ink)">${usd(e.estimate_usd)}</strong>`
    const range = document.createElement("p")
    range.className = "muted"
    range.textContent = `80% range ${usd(e.low_usd)} – ${usd(e.high_usd)}${e.known_model ? "" : " · model not in training data, treat as rough"}`
    this.estimateTarget.append(big, range)
    const suggested = Math.round(e.low_usd * 0.85 / 100) * 100
    if (this.startTarget.value === "1000") this.startTarget.value = suggested
  }
}
