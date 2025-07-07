class Calendar < ApplicationRecord
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
      last_sync_at: nil,
      last_sync_token: nil
    )
  end

  def start_sync!
    update!(sync_status: "syncing")
  end

  def complete_sync!(sync_token: nil)
    update!(
      sync_status: "completed",
      last_sync_at: Time.current,
      last_sync_token: sync_token,
      initial_sync_complete: true
    )
  end

  def fail_sync!(error_message = nil)
    update!(
      sync_status: "failed",
      last_error: error_message
    )
  end

  def incremental_sync?
    initial_sync_complete? && (next_page_token.present? || last_sync_token.present?)
  end

  def initial_sync?
    !initial_sync_complete?
  end
end
