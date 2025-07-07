class Mailbox < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  enum :sync_status, {
    idle: "idle",
    syncing: "syncing",
    completed: "completed",
    failed: "failed"
  }

  def reset_sync!
    update!(
      next_page_token: nil,
      sync_status: "idle",
      last_sync_at: nil
    )
  end

  def start_sync!
    update!(sync_status: "syncing")
  end

  def complete_sync!
    update!(
      sync_status: "completed",
      last_sync_at: Time.current
    )
  end

  def fail_sync!(error_message = nil)
    update!(
      sync_status: "failed",
      last_error: error_message
    )
  end

  def incremental_sync?
    next_page_token.present?
  end

  def initial_sync?
    !incremental_sync?
  end
end
