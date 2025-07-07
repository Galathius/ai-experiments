import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop", "content"]

  connect() {
    console.log('Dashboard controller connected')
    // Initialize change tracking
    this.unchangedIterations = 0
    this.lastDataHash = null
    // Start periodic polling for dashboard updates
    this.startPolling()
  }

  disconnect() {
    // Stop polling when user leaves
    this.stopPolling()
  }

  startPolling() {
    // Poll every 5 seconds
    this.pollingInterval = setInterval(() => {
      this.updateDashboard()
    }, 5000)
  }

  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
      console.log('Dashboard polling stopped')
    }
  }

  updateDashboard() {
    // Fetch updated dashboard content
    fetch('/dashboard_update', {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      // Create a hash of the current data for comparison
      const currentDataHash = this.hashData(data)
      
      if (this.lastDataHash === currentDataHash) {
        // No changes detected
        this.unchangedIterations++
        console.log(`No changes detected (${this.unchangedIterations}/3)`)
        
        if (this.unchangedIterations >= 3) {
          console.log('No changes for 3 iterations, stopping polling')
          this.stopPolling()
          return
        }
      } else {
        // Changes detected, reset counter and update UI
        this.unchangedIterations = 0
        this.lastDataHash = currentDataHash
        console.log('Changes detected, updating dashboard')
        
        // Update the dashboard content
        if (data.turbo_stream) {
          Turbo.renderStreamMessage(data.turbo_stream)
        }
      }
    })
    .catch(error => {
      console.log('Dashboard update failed:', error)
    })
  }

  hashData(data) {
    // Create a simple hash of the data to detect changes
    const dataString = JSON.stringify({
      stats: data.stats,
      recent_emails: data.recent_emails?.map(e => ({id: e.id, subject: e.subject})),
      closest_events: data.closest_events?.map(e => ({id: e.id, title: e.title})),
      recent_contacts: data.recent_contacts?.map(c => ({id: c.id, name: c.full_name})),
      recent_notes: data.recent_notes?.map(n => ({id: n.id, content: n.content?.substring(0, 100)})),
      pending_tasks: data.pending_tasks?.map(t => ({id: t.id, title: t.title})),
      recent_action_logs: data.recent_action_logs?.map(l => ({id: l.id, tool_name: l.tool_name}))
    })
    
    // Simple hash function
    let hash = 0
    for (let i = 0; i < dataString.length; i++) {
      const char = dataString.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash // Convert to 32-bit integer
    }
    return hash
  }

  openModal() {
    console.log('Opening chat modal...')
    document.body.style.overflow = 'hidden'
    this.modalTarget.classList.remove('hidden')
    
    fetch('/chat_interface')
      .then(response => response.text())
      .then(html => {
        this.contentTarget.innerHTML = html
        // The chat interface will have its own controller
      })
      .catch(error => {
        console.error('Error loading chat:', error)
        this.contentTarget.innerHTML = '<div class="flex-1 flex items-center justify-center"><div class="text-red-500">Error loading chat</div></div>'
      })
  }

  closeModal() {
    document.body.style.overflow = ''
    this.modalTarget.classList.add('hidden')
  }
}