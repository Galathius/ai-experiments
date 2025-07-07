class TaskManager
  def initialize(user)
    @user = user
  end

  def create_task(title:, description: nil, priority: "medium", due_date: nil, metadata: {})
    task = @user.tasks.create!(
      title: title,
      description: description,
      priority: priority,
      due_date: due_date,
      metadata: metadata
    )

    # Generate embedding for the task
    EmbeddingService.generate_embedding_for(task)

    task
  end

  def update_task(task_id, updates = {})
    task = @user.tasks.find(task_id)
    task.update!(updates)
    task
  end

  def complete_task(task_id)
    task = @user.tasks.find(task_id)
    task.complete!
    task
  end

  def list_tasks(filters = {})
    tasks = @user.tasks

    # Apply filters
    tasks = tasks.where(status: filters[:status]) if filters[:status]
    tasks = tasks.where(priority: filters[:priority]) if filters[:priority]

    if filters[:overdue]
      tasks = tasks.overdue
    elsif filters[:due_soon]
      tasks = tasks.due_soon
    elsif filters[:active]
      tasks = tasks.active
    end

    # Default ordering: priority desc, then due date
    tasks.order(
      Arel.sql("
        CASE priority
          WHEN 'urgent' THEN 4
          WHEN 'high' THEN 3
          WHEN 'medium' THEN 2
          WHEN 'low' THEN 1
          ELSE 0
        END DESC
      "),
      :due_date
    )
  end

  def get_task_summary
    {
      total: @user.tasks.count,
      pending: @user.tasks.pending.count,
      in_progress: @user.tasks.in_progress.count,
      completed: @user.tasks.completed.count,
      overdue: @user.tasks.overdue.count,
      due_soon: @user.tasks.due_soon.count
    }
  end

  def get_urgent_tasks
    @user.tasks.active.where(priority: [ "urgent", "high" ]).limit(5)
  end

  def get_context_for_ai
    summary = get_task_summary
    urgent_tasks = get_urgent_tasks

    context = []

    if summary[:overdue] > 0
      context << "⚠️ You have #{summary[:overdue]} overdue task(s)"
    end

    if summary[:due_soon] > 0
      context << "📅 You have #{summary[:due_soon]} task(s) due soon"
    end

    if urgent_tasks.any?
      context << "🔥 Urgent tasks:"
      urgent_tasks.each do |task|
        due_text = task.due_date ? " (due #{task.due_date.strftime('%m/%d')})" : ""
        context << "  • #{task.title}#{due_text}"
      end
    end

    context.join("\n") if context.any?
  end
end
