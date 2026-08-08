require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "an admin can reach the import form" do
    sign_in users(:admin)

    get import_form_users_path

    assert_response :success
  end

  test "a scorer cannot reach the import form" do
    sign_in users(:scorer)

    get import_form_users_path

    assert_redirected_to root_path
  end

  test "a team cannot import users" do
    sign_in users(:team_one)

    assert_no_difference -> { User.count } do
      post_import "Name,Email,Password\nSneaky,sneaky@bedlamtheatre.test,pineapple24"
    end

    assert_redirected_to root_path
  end

  test "a clean import redirects with a count" do
    sign_in users(:admin)

    assert_difference -> { User.count }, 2 do
      post_import <<~CSV
        Name,Email,Role,Password
        Ctl One,ctl_one@bedlamtheatre.test,team,pineapple24
        Ctl Two,ctl_two@bedlamtheatre.test,scorer,viking24
      CSV
    end

    assert_redirected_to users_path
    assert_equal "Imported 2 users.", flash[:notice]
  end

  test "a partial import reports what happened and returns 422" do
    sign_in users(:admin)
    existing = users(:team_two)

    assert_difference -> { User.count }, 1 do
      post_import <<~CSV
        Name,Email,Password
        Ctl Good,ctl_good@bedlamtheatre.test,pineapple24
        Duplicate Email,#{existing.email},pineapple24
        Ctl Short,ctl_short@bedlamtheatre.test,abc
      CSV
    end

    assert_response :unprocessable_entity
    assert_match(/Created 1/, flash[:alert])
    assert_match(/Skipped 1/, flash[:alert])
    assert_match(/1 rejected/, flash[:alert])
    assert_match(/row 4/, flash[:alert])
  end

  # The report is shown to an operator and lands in the flash; a password must never reach it.
  test "the report never echoes a password" do
    sign_in users(:admin)

    post_import <<~CSV
      Name,Email,Password
      Ctl Secret,#{users(:team_one).email},hunter2secret
    CSV

    assert_not_includes flash[:alert].to_s, "hunter2secret"
  end

  test "missing headers are named and nothing is imported" do
    sign_in users(:admin)

    assert_no_difference -> { User.count } do
      post_import "Naam,Emailadres\nNope,nope@bedlamtheatre.test"
    end

    assert_response :unprocessable_entity
    assert_match(/missing required columns/i, flash[:alert])
  end

  test "submitting no file is reported" do
    sign_in users(:admin)

    post import_users_path

    assert_response :unprocessable_entity
    assert_match(/select a file/i, flash[:alert])
  end

  private

  def post_import(csv)
    file = Tempfile.new([ "users", ".csv" ])
    file.write(csv)
    file.rewind

    post import_users_path,
         params: { import: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") } }
  end
end
