import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop", "content"]

  connect() {
    console.log('Dashboard controller connected')
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