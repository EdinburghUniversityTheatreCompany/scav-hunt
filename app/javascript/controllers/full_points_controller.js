import { Controller } from "@hotwired/stimulus"

// The Full Points button used to be a `button_to`: its own form, posting its own copy
// of the score. Clicking it while a typed value was still in the regular points input
// blurred that input first, so the input's form posted the typed value and this form
// posted the full value some 50ms later -- two writes for one click, with the row
// keeping whichever of them committed last rather than the one that was asked for.
//
// So the button no longer writes anything itself. It fills in the field it is about
// and lets that field's form save, which is the same path typing a value takes.
export default class extends Controller {
  static outlets = ["auto-submit"]
  static values = { points: Number }

  // Clicking a button moves focus to it, and that blur is what fires the input's
  // `change`. Cancelling the mousedown default leaves focus where it is, so no blur
  // and no stray save; the click still arrives.
  keepFocus(event) {
    event.preventDefault()
  }

  award() {
    this.autoSubmitOutlet.awardPoints(this.pointsValue)
  }
}
