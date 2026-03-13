import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template"]

  connect() {
    this.nextIndex = this.rowsTarget.querySelectorAll("tr").length
  }

  addLine() {
    const html = this.templateTarget.innerHTML
      .replace(/__INDEX__/g, String(this.nextIndex))
      .replace(/__LINE_POSITION__/g, String(this.nextIndex + 1))

    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.nextIndex += 1
  }
}
