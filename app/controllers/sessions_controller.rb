class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new ]

  def new
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
