class Task < ApplicationRecord
  belongs_to :user
  has_one :embedding, as: :embeddable, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: %w[pending in_progress completed cancelled] }
  validates :priority, inclusion: { in: %w[low medium high urgent] }

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :active, -> { where(status: [ "pending", "in_progress" ]) }
  scope :overdue, -> { where("due_date < ? AND status != ?", Time.current, "completed") }
  scope :due_soon, -> { where(due_date: Time.current..1.week.from_now).where.not(status: "completed") }
  scope :by_priority, -> { order(:priority) }
  scope :recent, -> { order(created_at: :desc) }

  def overdue?
    due_date && due_date < Time.current && status != "completed"
  end

  def due_soon?
    due_date && due_date <= 1.week.from_now && status != "completed"
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def priority_number
    case priority
    when "urgent" then 4
    when "high" then 3
    when "medium" then 2
    when "low" then 1
    else 0
    end
  end

  def content_for_embedding
    parts = []

    # Add task title and description
    parts << "Task: #{title}" if title.present?
    parts << description if description.present?

    # Add priority and status context
    parts << "Priority: #{priority}" if priority.present?
    parts << "Status: #{status}" if status.present?

    # Add due date context
    if due_date.present?
      parts << "Due: #{due_date.strftime('%B %d, %Y')}"
    end

    parts.compact.join(" ")
  end

  def self.semantic_search(query, limit: 10)
    # This will be used for RAG - find tasks similar to the query
    embeddings = Embedding.semantic_search(query, limit: limit, types: [ "Task" ])
    task_ids = embeddings.pluck(:embeddable_id)
    where(id: task_ids)
  end
end
