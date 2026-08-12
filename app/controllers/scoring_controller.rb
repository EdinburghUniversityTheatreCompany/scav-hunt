class ScoringController < ApplicationController
  authorize_resource class: :scoring

  # GET /scoring
  def index
    redirect_to root_path
  end

  # GET /scoring/:id
  def score
    @team = User.find(params[:id])
    return redirect_to scoring_path, notice: "Only teams can be scored." unless @team.team?

    @title = "Scoring #{@team.name}"

    @challenges = Challenge.by_number
    @results = Result.includes(:challenge).where(user: @team).index_by(&:challenge_id)
  end

  # POST /scoring/update
  def update
    @result = find_or_build_result
    apply_submission

    if save_result
      # Only the columns that really moved get repainted; see the stream partial.
      @fields = @result.saved_changes.keys & Result::POINT_FIELDS
      @updated_by = current_user.id
      render :update, formats: :turbo_stream
    else
      flash.now[:alert] = @result.errors.full_messages.to_sentence
      # Put the stored value back in the field the scorer just broke, with no flash
      # highlight -- the alert is the feedback, a green "saved" glow would be a lie.
      @fields = submitted_fields
      @result = @result.persisted? ? @result.reload : blank_result
      render :update, formats: :turbo_stream, status: :unprocessable_entity
    end
  end

  private

  def find_or_build_result
    Result.find_or_initialize_by(challenge_id: params[:challenge_id], user_id: params[:user_id])
  end

  def apply_submission
    assign_submitted_points
    @result.updated_by_id = current_user.id
  end

  # The uniqueness validation is a SELECT taken before the INSERT, so two scorers who
  # open a challenge nobody has scored yet can both pass it and whichever INSERT lands
  # second trips the unique index on [user_id, challenge_id]. That used to escape as a
  # 500 and the score was simply lost.
  #
  # Losing the race is not a failure, though: the row the other request just committed
  # is the row this one meant to update. Re-read it and lay this request's column on
  # top, which is exactly what would have happened had the two arrived a moment
  # further apart. Once only, because a second conflict means something other than a
  # concurrent create and should be seen rather than swallowed.
  def save_result
    @result.save
  rescue ActiveRecord::RecordNotUnique
    raise if @lost_insert_race

    @lost_insert_race = true
    @result = find_or_build_result
    apply_submission
    retry
  end

  # Assign only the columns the scorer actually submitted. The old handler read BOTH
  # points fields out of the DOM and posted them together, so two saves in flight --
  # one scorer tabbing quickly between the two inputs, or two scorers on the same
  # team -- raced, and the later response wrote its stale copy of the other field
  # back over the earlier save, in the UI and in the database. One column per request
  # plus ActiveRecord's partial updates means the two writes cannot collide.
  def assign_submitted_points
    submitted_fields.each { |field| @result.public_send("#{field}=", params[field]) }

    # A result created by a single-field form still needs its other column filled --
    # but only the column nobody submitted. A blank value that WAS submitted has to
    # keep failing validation rather than quietly becoming a zero.
    (Result::POINT_FIELDS - submitted_fields).each do |field|
      @result.public_send("#{field}=", 0) if @result.public_send(field).nil?
    end
  end

  def submitted_fields
    Result::POINT_FIELDS.select { |field| params.key?(field) }
  end

  def blank_result
    Result.new(challenge_id: params[:challenge_id], user_id: params[:user_id], regular_points: 0, bonus_points: 0)
  end
end
