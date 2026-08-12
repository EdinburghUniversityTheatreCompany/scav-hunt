require "test_helper"

# Writes used to arrive over ScoringChannel#receive as well as over this action, and
# the channel test covered who was allowed to write. There is only one write path
# now, so that coverage lives here.
class ScoringControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = users(:team_one)
    @challenge = challenges(:three)
    @result = results(:challenge_one_by_team_one)
  end

  test "a team cannot write a score" do
    sign_in @team

    assert_no_difference -> { Result.count } do
      post scoring_update_path, params: { challenge_id: @challenge.id, user_id: @team.id, regular_points: 300 }
    end

    assert_redirected_to root_path
  end

  test "a scorer can write a score" do
    sign_in users(:scorer)

    assert_difference -> { Result.count }, 1 do
      post scoring_update_path, params: { challenge_id: @challenge.id, user_id: @team.id, regular_points: 300 }
    end

    assert_response :success
    assert_equal 300, Result.find_by(challenge: @challenge, user: @team).regular_points
  end

  test "a new result created from one field defaults the other to zero" do
    sign_in users(:scorer)

    post scoring_update_path, params: { challenge_id: @challenge.id, user_id: @team.id, bonus_points: 25 }

    result = Result.find_by(challenge: @challenge, user: @team)
    assert_equal 25, result.bonus_points
    assert_equal 0, result.regular_points
  end

  # The bug this replaces: the old handler posted BOTH columns, read out of the DOM,
  # so a save that was only meant to change one of them wrote a stale value over the
  # other. A request that names one column must leave the other exactly as it was.
  test "a save that names one column does not touch the other" do
    sign_in users(:scorer)
    @result.update!(regular_points: 1500, bonus_points: 0)

    post scoring_update_path, params: { challenge_id: @result.challenge_id, user_id: @team.id, bonus_points: 10 }

    @result.reload
    assert_equal 10, @result.bonus_points
    assert_equal 1500, @result.regular_points, "The untouched column was overwritten"
  end

  test "an interleaved pair of single-column saves both survive" do
    sign_in users(:scorer)
    @result.update!(regular_points: 1500, bonus_points: 0)

    # Two requests that each read the row before the other has written, exactly the
    # shape of two scorers saving at the same moment.
    first = Result.find_or_initialize_by(challenge_id: @result.challenge_id, user_id: @team.id)
    second = Result.find_or_initialize_by(challenge_id: @result.challenge_id, user_id: @team.id)

    first.regular_points = 50
    second.bonus_points = 10
    first.save!
    second.save!

    @result.reload
    assert_equal 50, @result.regular_points
    assert_equal 10, @result.bonus_points
  end

  test "a blank value is refused and the stored score is left alone" do
    sign_in users(:scorer)
    @result.update!(regular_points: 1500, bonus_points: 0)

    post scoring_update_path, params: { challenge_id: @result.challenge_id, user_id: @team.id, regular_points: "" }

    assert_response :unprocessable_entity
    assert_equal 1500, @result.reload.regular_points
  end
end

# Two requests that both score a challenge nobody has scored yet each build a new
# Result, and the uniqueness validation is a SELECT taken before the INSERT, so both
# can pass it. Whichever INSERT lands second hits the unique index on
# [user_id, challenge_id] and used to come back as an unrescued
# ActiveRecord::RecordNotUnique -- a 500 in the scorer's face, with their score lost.
#
# Staging that needs the winning row to be committed by somebody else while this
# request's own transaction is open, which the suite's transactional wrapper cannot
# express -- our INSERT's rollback would take the other row with it. So this class
# opts out of transactional tests and cleans up the rows it commits.
class ScoringControllerRaceTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @team = users(:team_one)
    @challenge = challenges(:three) # No fixture result, so both requests would INSERT.
    sign_in users(:scorer)
  end

  teardown do
    Result.where(challenge_id: @challenge.id).delete_all
  end

  test "a scorer who loses the insert race still has their score recorded" do
    losing_the_race_to(bonus_points: 42) do
      post scoring_update_path, params: { challenge_id: @challenge.id, user_id: @team.id, regular_points: 300 }
    end

    assert_response :success

    results = Result.where(challenge_id: @challenge.id, user_id: @team.id)
    assert_equal 1, results.count, "The race left a duplicate row behind"
    assert_equal 300, results.first.regular_points, "The score that lost the race was dropped"
    assert_equal 42, results.first.bonus_points, "The winning request's column was overwritten"
  end

  private

  # Commits the row the other request would have created, in the window between this
  # request's uniqueness check and its INSERT. A separate connection, because the row
  # has to outlive the failed INSERT's rollback exactly as a committed one would.
  def losing_the_race_to(bonus_points:)
    inserted = false
    # Bound up front: ActiveSupport runs the callback against the Result, so `self`
    # inside it is the record being saved, not this test.
    commit_winner = method(:commit_result_on_another_connection)
    callback = ->(_result) do
      next if inserted

      inserted = true
      commit_winner.call(bonus_points)
    end

    Result.set_callback(:validation, :after, callback)
    yield
    assert inserted, "The race was never staged, so this proves nothing"
  ensure
    Result.skip_callback(:validation, :after, callback, raise: false)
  end

  def commit_result_on_another_connection(bonus_points)
    pool = ActiveRecord::Base.connection_pool
    other = pool.checkout
    other.execute(<<~SQL.squish)
      INSERT INTO results (user_id, challenge_id, regular_points, bonus_points, created_at, updated_at)
      VALUES (#{@team.id.to_i}, #{@challenge.id.to_i}, 0, #{bonus_points.to_i}, NOW(), NOW())
    SQL
  ensure
    pool.checkin(other) if other
  end
end
