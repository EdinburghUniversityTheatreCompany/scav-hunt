import { Controller } from "@hotwired/stimulus"

// Submits the form this controller is attached to. Wire it up with
// `data-action="change->auto-submit#submit"` to turn any input into one that saves
// itself, and let the Turbo Stream response say what changed on the page.
//
// A form that names an `input` target -- the scoring points fields do, the group
// permission checkboxes do not -- also gets two things: it stops re-posting a value
// it has already sent, and it becomes the single write path for that field, which is
// how the Full Points button awards (see full_points_controller.js) instead of
// posting a score of its own.
export default class extends Controller {
  static targets = ["input"]

  #submitted

  connect() {
    if (this.hasInputTarget) this.#submitted = this.inputTarget.value
  }

  submit() {
    if (this.hasInputTarget) {
      // `change` fires on blur whenever the field was edited, including an edit that
      // ended back on the value already stored. Awarding full points to a field that
      // is already at full points leaves the input dirty the same way, because
      // nothing changed and so no Turbo Stream comes back to replace it. Neither is
      // worth a write, a broadcast, or a "saved" flash on every other scorer's screen.
      if (this.inputTarget.value === this.#submitted) return

      this.#submitted = this.inputTarget.value
    }

    this.element.requestSubmit()
  }

  awardPoints(points) {
    this.inputTarget.value = points
    this.submit()
  }
}
