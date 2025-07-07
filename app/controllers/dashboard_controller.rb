class DashboardController < ApplicationController
  def index
    @user = Current.user
    @google_connected = @user.google_identity.present?
    @hubspot_connected = @user.hubspot_identity.present?

    # Get detailed data for display
    @stats = {
      emails: @user.emails.count,
      calendar_events: @user.calendar_events.count,
      hubspot_contacts: @user.hubspot_contacts.count,
      hubspot_notes: @user.hubspot_notes.count,
      tasks: @user.tasks.count,
      pending_tasks: @user.tasks.pending.count
    }

    # Get actual data for inline display
    @recent_emails = @user.emails.order(received_at: :desc).limit(5)
    @closest_events = @user.calendar_events.closest.limit(5)
    @recent_contacts = @user.hubspot_contacts.order(created_at: :desc).limit(5)
    @recent_notes = @user.hubspot_notes.order(created_at: :desc).limit(5)
    @pending_tasks = @user.tasks.pending.order(created_at: :desc).limit(10)
    @recent_action_logs = @user.action_logs.order(created_at: :desc).limit(10)
  end

  def pull_data
    # Get selected sync options from checkboxes
    sync_emails = params[:sync_emails] == "1"
    sync_calendar = params[:sync_calendar] == "1"
    sync_contacts = params[:sync_contacts] == "1"
    sync_notes = params[:sync_notes] == "1"

    # Check if any options are selected and user has connected accounts
    if Current.user.google_identity || Current.user.hubspot_identity
      # Track what existed before sync
      before_counts = {
        emails: Current.user.emails.count,
        calendar_events: Current.user.calendar_events.count,
        hubspot_contacts: Current.user.hubspot_contacts.count,
        hubspot_notes: Current.user.hubspot_notes.count
      }

      # Start background import jobs based on selections
      jobs_started = []

      if Current.user.google_identity
        google_jobs = []
        if sync_emails
          ImportEmailsJob.perform_later(Current.user.id)
          google_jobs << "emails"
        end
        if sync_calendar
          ImportCalendarEventsJob.perform_later(Current.user.id)
          google_jobs << "calendar"
        end
        jobs_started << "Google #{google_jobs.join(' & ')}" if google_jobs.any?
      end

      if Current.user.hubspot_identity
        hubspot_jobs = []
        if sync_contacts && defined?(ImportHubspotContactsJob)
          ImportHubspotContactsJob.perform_later(Current.user.id)
          hubspot_jobs << "contacts"
        end
        if sync_notes && defined?(ImportHubspotNotesJob)
          ImportHubspotNotesJob.perform_later(Current.user.id)
          hubspot_jobs << "notes"
        end
        jobs_started << "HubSpot #{hubspot_jobs.join(' & ')}" if hubspot_jobs.any?
      end

      if jobs_started.any?
        # Schedule proactive task checking after imports complete
        CheckTriggeredTasksJob.set(wait: 30.seconds).perform_later(Current.user.id, before_counts)

        respond_to do |format|
          format.html { redirect_to root_path, notice: "Data sync started for: #{jobs_started.join(', ')}. This may take a few minutes." }
          format.json { render json: { status: "success", message: "Syncing: #{jobs_started.join(', ')}" } }
          format.turbo_stream do
            render turbo_stream: turbo_stream.update("sync-status",
              partial: "dashboard/sync_status",
              locals: { message: "Syncing: #{jobs_started.join(', ')}..." }
            )
          end
        end
      else
        respond_to do |format|
          format.html { redirect_to root_path, alert: "Please select at least one data type to sync." }
          format.json { render json: { status: "error", message: "No data types selected" } }
          format.turbo_stream do
            render turbo_stream: turbo_stream.update("sync-status",
              partial: "dashboard/sync_status",
              locals: { message: "Please select at least one data type to sync.", error: true }
            )
          end
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: "No connected accounts to sync data from." }
        format.json { render json: { status: "error", message: "No connected accounts" } }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("sync-status",
            partial: "dashboard/sync_status",
            locals: { message: "No connected accounts to sync data from.", error: true }
          )
        end
      end
    end
  end

  def dashboard_update
    # Called by JavaScript polling to get fresh data
    @user = Current.user
    @google_connected = @user.google_identity.present?
    @hubspot_connected = @user.hubspot_identity.present?

    @stats = {
      emails: @user.emails.count,
      calendar_events: @user.calendar_events.count,
      hubspot_contacts: @user.hubspot_contacts.count,
      hubspot_notes: @user.hubspot_notes.count,
      tasks: @user.tasks.count,
      pending_tasks: @user.tasks.pending.count
    }

    @recent_emails = @user.emails.order(received_at: :desc).limit(5)
    @closest_events = @user.calendar_events.closest.limit(5)
    @recent_contacts = @user.hubspot_contacts.order(created_at: :desc).limit(5)
    @recent_notes = @user.hubspot_notes.order(created_at: :desc).limit(5)
    @pending_tasks = @user.tasks.pending.order(created_at: :desc).limit(10)
    @recent_action_logs = @user.action_logs.order(created_at: :desc).limit(10)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("dashboard-content",
          partial: "dashboard/dashboard_content",
          locals: {
            user: @user,
            google_connected: @google_connected,
            hubspot_connected: @hubspot_connected,
            stats: @stats,
            recent_emails: @recent_emails,
            closest_events: @closest_events,
            recent_contacts: @recent_contacts,
            recent_notes: @recent_notes,
            pending_tasks: @pending_tasks,
            recent_action_logs: @recent_action_logs
          }
        )
      end
      format.json do
        turbo_stream_html = render_to_string(
          turbo_stream: turbo_stream.update("dashboard-content",
            partial: "dashboard/dashboard_content",
            locals: {
              user: @user,
              google_connected: @google_connected,
              hubspot_connected: @hubspot_connected,
              stats: @stats,
              recent_emails: @recent_emails,
              closest_events: @closest_events,
              recent_contacts: @recent_contacts,
              recent_notes: @recent_notes,
              pending_tasks: @pending_tasks,
              recent_action_logs: @recent_action_logs
            }
          )
        )

        render json: {
          stats: @stats,
          recent_emails: @recent_emails.map { |e| { id: e.id, subject: e.subject } },
          closest_events: @closest_events.map { |e| { id: e.id, title: e.title } },
          recent_contacts: @recent_contacts.map { |c| { id: c.id, full_name: c.full_name } },
          recent_notes: @recent_notes.map { |n| { id: n.id, content: n.content } },
          pending_tasks: @pending_tasks.map { |t| { id: t.id, title: t.title } },
          recent_action_logs: @recent_action_logs.map { |l| { id: l.id, tool_name: l.tool_name } },
          turbo_stream: turbo_stream_html
        }
      end
    end
  end
end
