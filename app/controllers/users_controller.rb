class UsersController < ApplicationController
  load_and_authorize_resource

  def index
    @title = "Users"
    @users = User.accessible_by(current_ability).order(:role, :name)
  end

  def show
    @title = @user.name.presence || "User"
  end

  def new
    set_new_user_title
  end

  def edit
    set_edit_user_title
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to @user, notice: "User was successfully created."
    else
      set_new_user_title
      render :new, status: :unprocessable_entity
    end
  end

  def update
    params = user_params

    if params[:password].blank? && params[:password_confirmation].blank?
      params.delete(:password)
      params.delete(:password_confirmation)
    end

    if @user.update(params)
      redirect_to @user, notice: "User was successfully updated."
    else
      set_edit_user_title
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user.destroy
      redirect_to users_url, notice: "User was successfully destroyed."
    else
      redirect_to users_url, alert: destroy_error_for(@user)
    end
  end

  def import_form
    @title = "Import Users"
  end

  def import
    file = params.dig(:import, :file)
    return import_failed("Please select a file to import.") if file.blank?

    result = UserImport.new(file).call

    if result.success?
      redirect_to users_path, notice: "Imported #{result.created.size} #{'user'.pluralize(result.created.size)}."
    else
      import_failed(import_report(result))
    end
  end

  private

  # Turbo discards a 200 response to a form submission, so a report rendered without an error
  # status is invisible. flash.now, not flash: the message belongs to this render, not the next
  # request.
  def import_failed(message)
    @title = "Import Users"
    flash.now[:alert] = message
    render "import_form", status: :unprocessable_entity
  end

  # Never includes a password, in any branch.
  def import_report(result)
    return "CSV is missing required columns: #{result.missing_headers.to_sentence}." if result.missing_headers.any?
    return result.error if result.error.present?

    parts = [ "Created #{result.created.size}." ]

    if result.skipped.any?
      parts << "Skipped #{result.skipped.size} (already exist): #{result.skipped.to_sentence}."
    end

    if result.rejected.any?
      details = result.rejected.first(5).map { |r| "row #{r[:row]}: #{r[:reason]}" }
      details << "and #{result.rejected.size - 5} more" if result.rejected.size > 5
      parts << "#{result.rejected.size} rejected — #{details.join('; ')}."
    end

    parts.join(" ")
  end

  # A destroy vetoed by Result#ensure_zero_points records its reason on the
  # result, not on the user, so collect both.
  def destroy_error_for(user)
    reasons = (user.errors.full_messages + user.results.flat_map { |r| r.errors.full_messages }).uniq

    reasons.presence&.to_sentence || "User could not be destroyed."
  end

  def user_params
    params.require(:user).permit(:email, :name, :role, :password, :password_confirmation)
  end

  def set_edit_user_title
    @title = "Edit #{@user.name}"
  end

  def set_new_user_title
    @title = "New User"
  end
end
