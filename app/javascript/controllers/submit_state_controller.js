import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "spinner", "message"]

  connect() {
    this.originalLabel = this.hasLabelTarget ? this.labelTarget.textContent.trim() : ""
  }

  start() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.setAttribute("aria-busy", "true")
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = "Submitting..."
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.hidden = false
    }

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = "Submitting quote request. Please wait..."
    }
  }

  end(event) {
    if (event.detail.success) return

    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
      this.buttonTarget.removeAttribute("aria-busy")
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.originalLabel
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.hidden = true
    }

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = ""
    }
  }
}
