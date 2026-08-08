require "test_helper"

class UserImportTest < ActiveSupport::TestCase
  # The service takes anything with #path, which is what Rack's uploaded-file object
  # gives us in the controller. A Tempfile stands in for it here.
  def import(csv)
    file = Tempfile.new([ "users", ".csv" ])
    file.write(csv)
    file.rewind
    UserImport.new(file).call
  end

  test "creates a user per row" do
    result = import(<<~CSV)
      Name,Email,Role,Password
      Import One,import_one@bedlamtheatre.test,team,pineapple24
      Import Two,import_two@bedlamtheatre.test,scorer,viking24
    CSV

    assert result.success?
    assert_equal 2, result.created.size
    assert_empty result.skipped
    assert_empty result.rejected

    assert_equal "team", User.find_by(email: "import_one@bedlamtheatre.test").role
    assert_equal "scorer", User.find_by(email: "import_two@bedlamtheatre.test").role
  end

  # The whole reason activerecord-import is not used here: bulk insert writes columns
  # directly and never runs Devise's password= setter, so the password would be stored
  # blank or in the clear.
  test "the password is hashed and actually works" do
    import <<~CSV
      Name,Email,Password
      Import Hash,import_hash@bedlamtheatre.test,pineapple24
    CSV

    user = User.find_by(email: "import_hash@bedlamtheatre.test")

    assert user.valid_password?("pineapple24"), "Imported user cannot sign in with their password"
    assert_not_equal "pineapple24", user.encrypted_password
    assert_not_includes user.encrypted_password, "pineapple24"
  end

  test "a blank role defaults to team, the least privileged" do
    import <<~CSV
      Name,Email,Role,Password
      Import Blank,import_blank@bedlamtheatre.test,,pineapple24
    CSV

    assert_equal "team", User.find_by(email: "import_blank@bedlamtheatre.test").role
  end

  test "the Role column may be absent entirely" do
    result = import(<<~CSV)
      Name,Email,Password
      Import NoRole,import_norole@bedlamtheatre.test,pineapple24
    CSV

    assert result.success?
    assert_equal "team", User.find_by(email: "import_norole@bedlamtheatre.test").role
  end

  test "an unrecognised role is rejected rather than silently defaulted" do
    result = import(<<~CSV)
      Name,Email,Role,Password
      Import Bad,import_bad@bedlamtheatre.test,superuser,pineapple24
    CSV

    assert_not result.success?
    assert_equal 1, result.rejected.size
    assert_match(/role/i, result.rejected.first[:reason])
    assert_not User.exists?(email: "import_bad@bedlamtheatre.test")
  end

  test "an existing email is skipped and its account left untouched" do
    existing = users(:team_one)
    digest_before = existing.encrypted_password

    result = import(<<~CSV)
      Name,Email,Role,Password
      Totally Different Name,#{existing.email},admin,pineapple24
    CSV

    assert_not result.success?
    assert_equal [ existing.email ], result.skipped
    assert_empty result.created

    existing.reload
    assert_equal digest_before, existing.encrypted_password, "A skipped row must not reset a password"
    assert_equal "team", existing.role, "A skipped row must not change a role"
  end

  test "a short password is rejected with a usable reason" do
    result = import(<<~CSV)
      Name,Email,Password
      Import Short,import_short@bedlamtheatre.test,abc
    CSV

    assert_not result.success?
    assert_match(/password/i, result.rejected.first[:reason])
    assert_not User.exists?(email: "import_short@bedlamtheatre.test")
  end

  test "a duplicate name is rejected, since name is unique" do
    result = import(<<~CSV)
      Name,Email,Password
      #{users(:team_one).name},import_dupname@bedlamtheatre.test,pineapple24
    CSV

    assert_not result.success?
    assert_match(/name/i, result.rejected.first[:reason])
  end

  test "rejected rows carry the CSV row number the operator sees" do
    result = import(<<~CSV)
      Name,Email,Password
      Import Fine,import_fine@bedlamtheatre.test,pineapple24
      Import Short,import_short2@bedlamtheatre.test,abc
    CSV

    # Header is row 1, so the second data row is row 3.
    assert_equal 3, result.rejected.first[:row]
  end

  test "one bad row does not block the rest of the batch" do
    result = import(<<~CSV)
      Name,Email,Password
      Import Good A,import_good_a@bedlamtheatre.test,pineapple24
      Import Short,import_short3@bedlamtheatre.test,abc
      Import Good B,import_good_b@bedlamtheatre.test,viking24
    CSV

    assert_equal 2, result.created.size
    assert_equal 1, result.rejected.size
  end

  test "missing required headers stop the import before anything is created" do
    result = import(<<~CSV)
      Naam,Emailadres,Wachtwoord
      Import Nope,import_nope@bedlamtheatre.test,pineapple24
    CSV

    assert_not result.success?
    assert_equal %w[Name Email Password], result.missing_headers
    assert_empty result.created
    assert_not User.exists?(email: "import_nope@bedlamtheatre.test")
  end

  test "a malformed CSV is reported rather than raising" do
    result = import("Name,Email,Password\n\"unclosed,quote,here\n")

    assert_not result.success?
    assert_predicate result.error, :present?
  end

  test "an empty file is not a crash" do
    result = import("")

    assert_not result.success?
    assert_empty result.created
  end
end
