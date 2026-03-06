import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "payload",
    "editable",
    "selectedLabel",
    "fontSize",
    "fontWeight",
    "fontColor",
    "textAlign",
    "textTransform",
    "fontFamily",
    "letterSpacing",
    "lineHeight",
    "fontItalic",
    "imageInput",
    "imagePreview",
    "saveButton",
    "publishButton",
    "dirtyNotice"
  ]

  static values = {
    fontMap: Object,
    draftPending: Boolean
  }

  connect() {
    this.selectedElement = null
    this.payload = this.readPayload()
    this.ensurePayloadShape()
    this.savedPayload = this.deepClone(this.payload)
    this.dirty = false
    this.applyInitialStyles()
    this.applyPendingState()
    this.refreshDirtyState()
  }

  beforeSubmit(event) {
    const action = event.submitter?.value || ""

    if (action === "save") {
      this.payloadTarget.value = JSON.stringify(this.payload)
      return
    }

    if (this.dirty) {
      const confirmed = window.confirm("You have unsaved changes. Preview/Publish uses only the last saved draft. Continue?")
      if (!confirmed) {
        event.preventDefault()
        return
      }
    }

    this.payloadTarget.value = JSON.stringify(this.savedPayload)
  }

  pickImage(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.imageKey
    const input = this.imageInputTargets.find((el) => el.dataset.imageKey === key)
    if (input) input.click()
  }

  imageChanged(event) {
    const input = event.currentTarget
    const key = input.dataset.imageKey
    const file = input.files && input.files[0]
    if (!file) return

    const preview = this.imagePreviewTargets.find((el) => el.dataset.imageKey === key)
    if (preview) {
      const objectUrl = URL.createObjectURL(file)
      preview.src = objectUrl
      const wrapper = preview.closest(".partners-editor-image")
      this.refreshDirtyState(wrapper ? [wrapper] : [])
    } else {
      this.refreshDirtyState()
    }
  }

  selectEditable(event) {
    const element = event.currentTarget
    this.editableTargets.forEach((target) => target.classList.remove("partners-editor-field--selected"))
    element.classList.add("partners-editor-field--selected")
    this.selectedElement = element

    const label = element.dataset.label || element.dataset.styleKey || "text"
    if (this.hasSelectedLabelTarget) {
      this.selectedLabelTarget.textContent = `Selected: ${label}`
    }

    const styleKey = element.dataset.styleKey
    const style = (this.payload.styles && this.payload.styles[styleKey]) || {}
    this.syncControls(style)
  }

  updateText(event) {
    const element = event.currentTarget
    const textValue = this.cleanText(element.textContent)

    const textKey = element.dataset.textKey
    if (textKey) {
      this.payload.texts[textKey] = textValue
      this.refreshDirtyState([element])
      return
    }

    const listKey = element.dataset.listKey
    const listIndex = parseInt(element.dataset.listIndex, 10)
    if (!listKey || Number.isNaN(listIndex)) return

    if (!Array.isArray(this.payload.arrays[listKey])) this.payload.arrays[listKey] = []
    this.payload.arrays[listKey][listIndex] = textValue
    this.refreshDirtyState([element])
  }

  updateSelectedStyle() {
    if (!this.selectedElement) return

    const styleKey = this.selectedElement.dataset.styleKey
    if (!styleKey) return

    const style = {}
    const fontSize = this.fontSizeTarget.value.trim()
    const fontWeight = this.fontWeightTarget.value.trim()
    const color = this.fontColorTarget.value.trim()
    const textAlign = this.textAlignTarget.value.trim()
    const textTransform = this.textTransformTarget.value.trim()
    const fontFamily = this.fontFamilyTarget.value.trim()
    const letterSpacing = this.letterSpacingTarget.value.trim()
    const lineHeight = this.lineHeightTarget.value.trim()

    if (fontSize) style.font_size = fontSize
    if (fontWeight) style.font_weight = fontWeight
    if (textAlign) style.text_align = textAlign
    if (textTransform) style.text_transform = textTransform
    if (fontFamily) style.font_family = fontFamily
    if (letterSpacing) style.letter_spacing = letterSpacing
    if (lineHeight) style.line_height = lineHeight
    if (color && color !== "#ffffff") style.color = color
    if (this.fontItalicTarget.checked) style.font_style = "italic"

    if (Object.keys(style).length > 0) {
      this.payload.styles[styleKey] = style
    } else {
      delete this.payload.styles[styleKey]
    }

    this.applyStyleToKey(styleKey)
    const relatedElements = this.editableTargets.filter((element) => element.dataset.styleKey === styleKey)
    this.refreshDirtyState(relatedElements)
  }

  applyInitialStyles() {
    Object.keys(this.payload.styles || {}).forEach((key) => this.applyStyleToKey(key))
  }

  applyStyleToKey(styleKey) {
    const style = (this.payload.styles && this.payload.styles[styleKey]) || {}
    const cssText = this.buildCss(style)

    this.editableTargets
      .filter((element) => element.dataset.styleKey === styleKey)
      .forEach((element) => {
        if (cssText.length > 0) {
          element.setAttribute("style", cssText)
        } else {
          element.removeAttribute("style")
        }
      })
  }

  buildCss(style) {
    const declarations = []

    if (style.font_size) declarations.push(`font-size: ${this.normalizeSize(style.font_size)}`)
    if (style.color) declarations.push(`color: ${style.color}`)
    if (style.font_weight) declarations.push(`font-weight: ${style.font_weight}`)
    if (style.font_style) declarations.push(`font-style: ${style.font_style}`)
    if (style.text_align) declarations.push(`text-align: ${style.text_align}`)
    if (style.text_transform) declarations.push(`text-transform: ${style.text_transform}`)
    if (style.letter_spacing) declarations.push(`letter-spacing: ${this.normalizeSize(style.letter_spacing)}`)
    if (style.line_height) declarations.push(`line-height: ${style.line_height}`)
    if (style.font_family) {
      const stack = this.fontMapValue[style.font_family]
      if (stack) declarations.push(`font-family: ${stack}`)
    }

    return declarations.join("; ")
  }

  normalizeSize(rawValue) {
    const value = String(rawValue).trim()
    if (/^\d+(\.\d+)?$/.test(value)) return `${value}px`
    return value
  }

  syncControls(style) {
    this.fontSizeTarget.value = this.safeNumber(style.font_size)
    this.fontWeightTarget.value = style.font_weight || ""
    this.textAlignTarget.value = style.text_align || ""
    this.textTransformTarget.value = style.text_transform || ""
    this.fontFamilyTarget.value = style.font_family || ""
    this.letterSpacingTarget.value = this.safeNumber(style.letter_spacing)
    this.lineHeightTarget.value = this.safeDecimal(style.line_height)
    this.fontItalicTarget.checked = style.font_style === "italic"
    this.fontColorTarget.value = this.safeColor(style.color)
  }

  safeNumber(value) {
    if (!value) return ""
    const match = String(value).match(/^(-?\d+(\.\d+)?)/)
    return match ? match[1] : ""
  }

  safeColor(value) {
    if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)) return value
    return "#ffffff"
  }

  safeDecimal(value) {
    if (!value) return ""
    const match = String(value).match(/^(\d+(\.\d+)?)/)
    return match ? match[1] : ""
  }

  cleanText(value) {
    return String(value || "").replace(/\s+/g, " ").trim()
  }

  refreshDirtyState(changedElements = []) {
    this.dirty = this.isPayloadDirty() || this.hasUnsavedImageFiles()

    changedElements.forEach((element) => {
      if (!element) return

      if (element.classList.contains("partners-editor-image")) {
        element.classList.add("partners-editor-image--dirty")
      } else {
        element.classList.add("partners-editor-field--dirty")
      }
    })

    if (this.dirty) {
      if (this.hasSaveButtonTarget) {
        this.saveButtonTarget.classList.add("partners-editor-button--dirty")
        this.saveButtonTarget.textContent = "Save Draft (Unsaved)"
      }

      if (this.hasDirtyNoticeTarget) {
        this.dirtyNoticeTarget.hidden = false
      }
      return
    }

    this.clearDirtyUi()
  }

  clearDirtyUi() {
    this.editableTargets.forEach((element) => element.classList.remove("partners-editor-field--dirty"))
    this.element.querySelectorAll(".partners-editor-image--dirty").forEach((element) => element.classList.remove("partners-editor-image--dirty"))

    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.classList.remove("partners-editor-button--dirty")
      this.saveButtonTarget.textContent = "Save Draft"
    }

    if (this.hasDirtyNoticeTarget) {
      this.dirtyNoticeTarget.hidden = true
    }
  }

  isPayloadDirty() {
    return JSON.stringify(this.payload) !== JSON.stringify(this.savedPayload)
  }

  hasUnsavedImageFiles() {
    return this.imageInputTargets.some((input) => input.files && input.files.length > 0)
  }

  applyPendingState() {
    if (this.draftPendingValue && this.hasPublishButtonTarget) {
      this.publishButtonTarget.classList.add("partners-editor-button--pending")
    }
  }

  deepClone(value) {
    return JSON.parse(JSON.stringify(value))
  }

  readPayload() {
    try {
      const parsed = JSON.parse(this.payloadTarget.value || "{}")
      return parsed && typeof parsed === "object" ? parsed : {}
    } catch (_error) {
      return {}
    }
  }

  ensurePayloadShape() {
    if (!this.payload.texts || typeof this.payload.texts !== "object") this.payload.texts = {}
    if (!this.payload.arrays || typeof this.payload.arrays !== "object") this.payload.arrays = {}
    if (!this.payload.images || typeof this.payload.images !== "object") this.payload.images = {}
    if (!this.payload.styles || typeof this.payload.styles !== "object") this.payload.styles = {}
  }
}
