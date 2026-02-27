import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.hero = document.querySelector(".lv-hero")
    this.onScroll = this.onScroll.bind(this)
    this.onResize = this.onResize.bind(this)

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onResize, { passive: true })

    this.refreshThreshold()
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onResize)
  }

  onResize() {
    this.refreshThreshold()
    this.onScroll()
  }

  onScroll() {
    const shouldUseSolidStyle = this.hero ? window.scrollY >= this.scrollThreshold : true
    this.element.classList.toggle("public-topbar--scrolled", shouldUseSolidStyle)
  }

  refreshThreshold() {
    if (!this.hero) {
      this.scrollThreshold = 0
      return
    }

    const heroHeight = this.hero.offsetHeight || 0
    const topbarHeight = this.element.offsetHeight || 0
    this.scrollThreshold = Math.max(36, heroHeight - topbarHeight - 14)
  }
}
