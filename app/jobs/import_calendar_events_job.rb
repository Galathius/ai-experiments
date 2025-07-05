class ImportCalendarEventsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    calendar_service = CalendarService.new(user)
    
    begin
      events_imported = calendar_service.import_events(limit: 50)
      Rails.logger.info "Imported #{events_imported} calendar events for user #{user.id}"
    rescue => e
      Rails.logger.error "Calendar import failed for user #{user.id}: #{e.message}"
      raise e
    end
  end
end