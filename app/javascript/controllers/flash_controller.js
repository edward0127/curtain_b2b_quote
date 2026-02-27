import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: Number
  }

  connect() {
    if (this.hasTimeoutValue && this.timeoutValue > 0) {
      this.timeoutHandle = setTimeout(() => this.dismiss(), this.timeoutValue)
    }
  }

  disconnect() {
    if (this.timeoutHandle) {
      clearTimeout(this.timeoutHandle)
      this.timeoutHandle = null
    }
  }

  close(event) {
    event.preventDefault()
    this.dismiss()
  }

  dismiss() {
    if (!this.element || this.element.dataset.flashClosing === "1") return

    this.element.dataset.flashClosing = "1"
    this.element.classList.add("flash--closing")
    setTimeout(() => {
      this.element?.remove()
    }, 220)
  }
}
