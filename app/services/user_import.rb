require "csv"

# Creates users in bulk from an uploaded CSV.
#
# Users are built and saved one at a time rather than through activerecord-import (which
# ChallengesController#import uses): bulk insert writes columns straight to the database and
# never runs Devise's `password=` setter, so every password would be stored blank or in the
# clear. Correctness here is worth more than the round trips.
#
# Rows whose email already belongs to someone are skipped, never updated -- re-running the same
# file has to be harmless, and must never reset a live password mid-hunt. Rows that fail
# validation are recorded and stepped over, so one bad line cannot block the batch.
class UserImport
  REQUIRED_HEADERS = %w[Name Email Password].freeze
  DEFAULT_ROLE = "team"

  # A row's position as the operator sees it in their spreadsheet: the header is row 1, so the
  # first row of data is row 2.
  HEADER_ROWS = 1

  Result = Struct.new(:created, :skipped, :rejected, :missing_headers, :error, keyword_init: true) do
    def success?
      rejected.empty? && skipped.empty? && missing_headers.empty? && error.nil?
    end
  end

  def initialize(file)
    @file = file
  end

  def call
    rows = CSV.read(@file.path, headers: true)

    missing = REQUIRED_HEADERS - (rows.headers || [])
    return failure(missing_headers: missing) if missing.any?

    import(rows)
  rescue CSV::MalformedCSVError => e
    failure(error: "Could not read that file as CSV: #{e.message}")
  end

  private

  def import(rows)
    created = []
    skipped = []
    rejected = []

    rows.each_with_index do |row, index|
      email = row["Email"].to_s.strip

      if email.present? && User.exists?(email: email)
        skipped << email
        next
      end

      number = index + 1 + HEADER_ROWS
      role = role_for(row)

      # Assigning an unknown value to an enum raises ArgumentError rather than failing
      # validation, so the check has to happen before the record is built.
      unless User.roles.key?(role)
        rejected << { row: number, reason: "Role #{role.inspect} is not one of #{User.roles.keys.join(', ')}" }
        next
      end

      user = build_user(row, email, role)

      if user.save
        created << user
      else
        rejected << { row: number, reason: user.errors.full_messages.to_sentence }
      end
    end

    Result.new(created: created, skipped: skipped, rejected: rejected, missing_headers: [])
  end

  def build_user(row, email, role)
    User.new(
      name: row["Name"].to_s.strip,
      email: email,
      password: row["Password"],
      role: role
    )
  end

  # A blank role means "team" -- the least-privileged role, so a missing value can never mint an
  # admin. An unrecognised one is returned as-is so the caller can reject the row, rather than
  # being silently coerced to the default.
  def role_for(row)
    value = row["Role"].to_s.strip
    value.presence || DEFAULT_ROLE
  end

  def failure(missing_headers: [], error: nil)
    Result.new(created: [], skipped: [], rejected: [], missing_headers: missing_headers, error: error)
  end
end
