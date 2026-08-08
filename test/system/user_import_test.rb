require "application_system_test_case"

class UserImportTest < ApplicationSystemTestCase
  setup do
    sign_in users(:admin)
  end

  test "importing users through the form" do
    file = Tempfile.new([ "users", ".csv" ])
    file.write(<<~CSV)
      Name,Email,Role,Password
      Sys Import One,sys_one@bedlamtheatre.test,team,pineapple24
      Sys Import Two,sys_two@bedlamtheatre.test,scorer,viking24
    CSV
    file.rewind

    visit users_url
    click_on "Import Users"
    assert_selector "h1", text: "Import Users"

    assert_difference -> { User.count }, 2 do
      attach_file("file", file.path)
      click_on "Import"

      assert_text "Imported 2 users."
    end

    assert_text "Sys Import One"
    assert_text "Sys Import Two"
  end

  # The error path is the one that was invisible in the challenges importer until it learned to
  # answer with 422 -- Turbo throws away a 200 response to a form submission.
  test "a rejected row is reported without a page reload" do
    file = Tempfile.new([ "users", ".csv" ])
    file.write(<<~CSV)
      Name,Email,Password
      Sys Short,sys_short@bedlamtheatre.test,abc
    CSV
    file.rewind

    visit import_form_users_url

    assert_no_difference -> { User.count } do
      attach_file("file", file.path)
      click_on "Import"

      assert_text "1 rejected"
    end
  end
end
