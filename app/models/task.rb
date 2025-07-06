class Task < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :status, inclusion: { in: %w[pending in_progress completed cancelled] }
  validates :priority, inclusion: { in: %w[low medium high urgent] }

  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :active, -> { where(status: ['pending', 'in_progress']) }
  scope :overdue, -> { where('due_date < ? AND status != ?', Time.current, 'completed') }
  scope :due_soon, -> { where(due_date: Time.current..1.week.from_now).where.not(status: 'completed') }
  scope :by_priority, -> { order(:priority) }
  scope :recent, -> { order(created_at: :desc) }

  def overdue?
    due_date && due_date < Time.current && status != 'completed'
  end

  def due_soon?
    due_date && due_date <= 1.week.from_now && status != 'completed'
  end

  def complete!
    update!(status: 'completed', completed_at: Time.current)
  end

  def priority_number
    case priority
    when 'urgent' then 4
    when 'high' then 3
    when 'medium' then 2
    when 'low' then 1
    else 0
    end
  end
end
