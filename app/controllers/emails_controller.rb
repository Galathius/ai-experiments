class EmailsController < ApplicationController
  def index
    @emails = Current.user.emails.recent.limit(50)
  end

  def import
    google_identity = Current.user.google_identity

    unless google_identity
      redirect_to emails_path, alert: "Please connect your Google account first."
      return
    end

    ImportEmailsJob.perform_later(Current.user.id)
    redirect_to emails_path, notice: "Email import started. This may take a few minutes."
  end

  def show
    @email = Current.user.emails.find(params[:id])
  end
end
