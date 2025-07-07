import { Controller } from "@hotwired/stimulus"
import { parse, format, isValid } from "date-fns"

export default class extends Controller {
  static targets = ["chatTab", "historyTab", "chatContent", "historyContent", "closeBtn", "sendBtn", "messageInput", "chatForm", "messagesContainer", "newThreadBtn"]

  connect() {
    console.log('Chat modal controller connected')
    
    this.bindEvents()
    this.showChatTab()
    if (this.hasMessageInputTarget) this.messageInputTarget.focus()
    
    // Set initial highlight for current chat
    const currentChatId = document.getElementById('current-chat-id')?.value
    if (currentChatId) {
      this.updateHistoryHighlight(currentChatId)
    }
    
    // Process existing messages for calendar events
    this.processExistingMessages()
    
    // Auto-scroll to bottom on opening
    this.scrollToBottom()
  }

  closeModal() {
    // Find the dashboard controller and call its closeModal method
    const dashboardElement = document.querySelector('[data-controller="dashboard"]')
    if (dashboardElement) {
      const dashboardController = this.application.getControllerForElementAndIdentifier(dashboardElement, 'dashboard')
      if (dashboardController) {
        dashboardController.closeModal()
      }
    }
  }

  bindEvents() {
    // History item clicks - for dynamically loaded content
    document.querySelectorAll('.chat-history-item').forEach(item => {
      item.onclick = () => {
        const chatId = item.getAttribute('data-chat-id')
        if (chatId) {
          this.loadChat(chatId)
          this.showChatTab()
        }
      }
    })
  }

  showChatTab() {
    this.chatContentTarget.classList.remove('hidden')
    this.chatContentTarget.classList.add('flex')
    this.historyContentTarget.classList.add('hidden')
    this.historyContentTarget.classList.remove('flex')
    
    this.chatTabTarget.className = 'tab-button active-tab py-4 mr-8 border-none bg-transparent text-base font-medium cursor-pointer border-b-2 border-gray-900 text-gray-900'
    this.historyTabTarget.className = 'tab-button py-4 border-none bg-transparent text-base font-normal cursor-pointer border-b-2 border-transparent text-gray-500'
    
    if (this.hasMessageInputTarget) this.messageInputTarget.focus()
  }

  showHistoryTab() {
    this.historyContentTarget.classList.remove('hidden')
    this.historyContentTarget.classList.add('flex')
    this.chatContentTarget.classList.add('hidden')
    this.chatContentTarget.classList.remove('flex')

    this.historyTabTarget.className = 'tab-button py-4 border-none bg-transparent text-base font-medium cursor-pointer border-b-2 border-gray-900 text-gray-900'
    this.chatTabTarget.className = 'tab-button active-tab py-4 mr-8 border-none bg-transparent text-base font-normal cursor-pointer border-b-2 border-transparent text-gray-500'
  }

  newThread() {
    const chatIdInput = document.getElementById('current-chat-id')
    if (chatIdInput) chatIdInput.value = ''
    
    this.messagesContainerTarget.innerHTML = `
      <div class="mb-3">
        <div class="bg-gray-100 rounded-xl p-3 max-w-[80%]">
          <p class="text-gray-900 text-sm m-0 leading-snug">I can answer questions about any Jump meeting. What do you want to know?</p>
        </div>
      </div>
    `
    
    this.showChatTab()
    this.updateChatTitle("New Chat")
  }

  async loadChat(chatId) {
    const chatIdInput = document.getElementById('current-chat-id')
    if (chatIdInput) chatIdInput.value = chatId
    
    try {
      const response = await fetch(`/chats/${chatId}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      this.messagesContainerTarget.innerHTML = `
        <div class="mb-3">
          <div class="bg-gray-100 rounded-xl p-3 max-w-[80%]">
            <p class="text-gray-900 text-sm m-0 leading-snug">I can answer questions about any Jump meeting. What do you want to know?</p>
          </div>
        </div>
      `
      
      if (data.messages) {
        data.messages.forEach(message => {
          this.addMessage(message.role, message.content)
        })
      }
      
      this.scrollToBottom()
      this.updateHistoryHighlight(chatId)
      this.updateChatTitle(data.chat.title)
      
      // Process existing messages for calendar events
      this.processExistingMessages()
    } catch (error) {
      console.error('Error loading chat:', error)
    }
  }

  handleModalKeydown(event) {
    if (event.key === 'Escape') {
      event.preventDefault()
      this.closeModal()
    }
  }

  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage()
    }
  }

  async sendMessage(event) {
    if (event) {
      event.preventDefault()
    }
    const content = this.messageInputTarget.value.trim()
    if (!content) return
    
    const chatId = document.getElementById('current-chat-id')?.value
    this.messageInputTarget.value = ''
    
    this.addMessage('user', content)
    
    try {
      const url = chatId ? `/chats/${chatId}/messages` : '/messages'
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ message: { content } })
      })
      
      const data = await response.json()
      
      if (data.ai_message) {
        this.addMessage('assistant', data.ai_message.content)
      }
      
      if (data.chat_id) {
        const chatIdInput = document.getElementById('current-chat-id')
        if (chatIdInput) chatIdInput.value = data.chat_id
        
        // If this is a new chat, refresh the history
        if (!chatId) {
          this.refreshHistory()
        }
        
        // Update highlight for current chat
        this.updateHistoryHighlight(data.chat_id)
        
        // Update chat title if it's provided
        if (data.chat_title) {
          this.updateChatTitle(data.chat_title)
        }
      }
    } catch (error) {
      console.error('Error sending message:', error)
      this.addMessage('assistant', 'Sorry, I encountered an error. Please try again.')
    }
  }

  addMessage(role, content) {
    const messageDiv = document.createElement('div')
    
    if (role === 'user') {
      messageDiv.className = 'mb-3 flex justify-end'
      messageDiv.innerHTML = `
        <div class="bg-gray-200 max-w-[80%] rounded-xl p-3">
          ${this.renderMarkdown(content)}
        </div>
      `
    } else {
      messageDiv.className = 'mb-3'
      const processedContent = this.processCalendarEvents(content)
      messageDiv.innerHTML = `
        <div class="bg-gray-100 max-w-[80%] rounded-xl p-3">
          ${processedContent}
        </div>
      `
    }
    
    this.messagesContainerTarget.appendChild(messageDiv)
    this.scrollToBottom()
  }

  processCalendarEvents(content) {
    // Check if content contains new calendar events formatting
    const calendarRegex = /\[CALENDAR_EVENTS\](.*?)\[\/CALENDAR_EVENTS\]/s
    const match = content.match(calendarRegex)
    
    if (match) {
      return this.processNewCalendarFormat(content, match)
    }
    
    // Check for old format: "You have the following events scheduled:"
    if (content.includes('You have the following events scheduled:') || content.includes('events scheduled')) {
      return this.processOldCalendarFormat(content)
    }
    
    return this.renderMarkdown(content)
  }

  renderMarkdown(content) {
    // Simple markdown-like formatting
    let html = content
    
    // Convert **bold** to <strong>
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong class="font-semibold">$1</strong>')
    
    // Convert *italic* to <em>
    html = html.replace(/(?<!\*)\*([^*]+)\*(?!\*)/g, '<em class="italic">$1</em>')
    
    // Handle different types of line breaks
    html = html.replace(/\r\n/g, '<br>')  // Windows line endings
    html = html.replace(/\r/g, '<br>')    // Mac line endings  
    html = html.replace(/\n/g, '<br>')    // Unix line endings
    
    // Handle multiple consecutive line breaks as paragraph breaks
    html = html.replace(/(<br>\s*){2,}/g, '</p><p class="text-gray-900 text-sm m-0 leading-snug mt-4">')
    
    // Wrap in paragraph with our styling
    return `<p class="text-gray-900 text-sm m-0 leading-snug">${html}</p>`
  }

  processNewCalendarFormat(content, match) {
    const beforeEvents = content.substring(0, match.index)
    const afterEvents = content.substring(match.index + match[0].length)
    const eventsData = match[1].trim()
    
    // Parse event lines
    const eventLines = eventsData.split('\n').filter(line => line.trim().startsWith('-'))
    const eventsHtml = eventLines.map(line => {
      const parts = line.substring(1).split('|').map(p => p.trim())
      const eventData = {}
      
      parts.forEach(part => {
        const [key, value] = part.split(':').map(s => s.trim())
        eventData[key] = value
      })
      
      // Try multiple date formats for the new format
      let startDate = parse(eventData.start, 'yyyy-MM-dd HH:mm', new Date())
      if (!isValid(startDate)) {
        startDate = parse(eventData.start, 'yyyy-MM-dd H:mm', new Date())
      }
      if (!isValid(startDate)) {
        startDate = parse(eventData.start, 'yyyy-MM-dd HH', new Date())
      }
      if (!isValid(startDate)) {
        startDate = parse(eventData.start, 'yyyy-MM-dd H', new Date())
      }
      
      let endDate = parse(eventData.end, 'yyyy-MM-dd HH:mm', new Date())
      if (!isValid(endDate)) {
        endDate = parse(eventData.end, 'yyyy-MM-dd H:mm', new Date())
      }
      if (!isValid(endDate)) {
        endDate = parse(eventData.end, 'yyyy-MM-dd HH', new Date())
      }
      if (!isValid(endDate)) {
        endDate = parse(eventData.end, 'yyyy-MM-dd H', new Date())
      }
      
      const dayName = isValid(startDate) ? format(startDate, 'EEEE') : 'Day'
      const dayNumber = isValid(startDate) ? format(startDate, 'd') : '?'
      const startTime = isValid(startDate) ? format(startDate, 'h a').replace(':00', '') : eventData.start
      const endTime = isValid(endDate) ? format(endDate, 'h a').replace(':00', '') : eventData.end
      
      return this.renderEventCard(dayNumber, dayName, startTime, endTime, eventData.title)
    }).join('')
    
    return this.buildResult(beforeEvents, eventsHtml, afterEvents)
  }

  processOldCalendarFormat(content) {
    // Parse old format: "1. **Event Title** - Date: Month DD, YYYY at HH:MM AM/PM"
    const eventRegex = /(\d+)\.\s*\*\*(.*?)\*\*[\s\S]*?Date:\s*(.*?)\s*at\s*(\d{1,2}:\d{2}\s*(?:AM|PM))/gi
    const matches = [...content.matchAll(eventRegex)]
    
    if (matches.length === 0) {
      return `<p class="text-gray-900 text-sm m-0 leading-snug">${content}</p>`
    }
    
    const beforeEvents = content.substring(0, matches[0].index)
    const eventsHtml = matches.map(match => {
      const title = match[2].trim()
      const dateStr = match[3].trim()
      const timeStr = match[4].trim()
      
      // Parse with date-fns
      const fullDateStr = `${dateStr} ${timeStr}`
      let eventDate = parse(fullDateStr, 'MMMM dd, yyyy h:mm a', new Date())
      
      // Try alternative formats if first parsing fails
      if (!isValid(eventDate)) {
        eventDate = parse(fullDateStr, 'MMMM d, yyyy h:mm a', new Date())
      }
      if (!isValid(eventDate)) {
        eventDate = parse(fullDateStr, 'MMM dd, yyyy h:mm a', new Date())
      }
      if (!isValid(eventDate)) {
        eventDate = parse(fullDateStr, 'MMM d, yyyy h:mm a', new Date())
      }
      
      const dayNumber = isValid(eventDate) ? format(eventDate, 'd') : '?'
      const dayName = isValid(eventDate) ? format(eventDate, 'EEEE') : 'Day'
      const startTime = isValid(eventDate) ? format(eventDate, 'h a').replace(':00', '') : timeStr
      
      return this.renderEventCard(dayNumber, dayName, startTime, null, title)
    }).join('')
    
    return this.buildResult(beforeEvents, eventsHtml, '')
  }

  renderEventCard(dayNumber, dayName, startTime, endTime, title) {
    const timeDisplay = endTime ? `${startTime} - ${endTime}` : startTime
    return `
      <div class="mb-4">
        <div class="text-sm font-medium text-gray-900 mb-2">${dayNumber} ${dayName}</div>
        <div class="border border-gray-200 rounded-lg p-3 bg-white">
          <div class="text-xs text-gray-500 mb-1">${timeDisplay}</div>
          <div class="font-semibold text-gray-900 text-sm">${title}</div>
        </div>
      </div>
    `
  }

  buildResult(beforeEvents, eventsHtml, afterEvents) {
    let result = ''
    if (beforeEvents.trim()) {
      const beforeHtml = this.renderMarkdown(beforeEvents.trim())
      // Add margin bottom to the last paragraph before events
      result += beforeHtml.replace(/<p class="([^"]*)"/, '<p class="$1 mb-3"')
    }
    result += eventsHtml
    if (afterEvents.trim()) {
      result += this.renderMarkdown(afterEvents.trim())
    }
    return result
  }

  processExistingMessages() {
    // Find all assistant message containers and process their content
    const assistantMessages = this.messagesContainerTarget.querySelectorAll('.bg-gray-100')
    
    assistantMessages.forEach((messageContainer, index) => {
      // Get the full text content from the entire container
      const content = messageContainer.textContent || messageContainer.innerText
      
      if (content && content.trim()) {
        const processedContent = this.processCalendarEvents(content.trim())
        
        // Always update with processed markdown content
        messageContainer.innerHTML = processedContent
      }
    })
  }

  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  async refreshHistory() {
    try {
      const response = await fetch('/chat_interface', {
        headers: {
          'Accept': 'text/html',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      const html = await response.text()
      const tempDiv = document.createElement('div')
      tempDiv.innerHTML = html
      
      const newHistoryList = tempDiv.querySelector('#chat-history-list')
      const currentHistoryList = document.getElementById('chat-history-list')
      
      if (newHistoryList && currentHistoryList) {
        currentHistoryList.innerHTML = newHistoryList.innerHTML
        
        // Rebind history item clicks
        document.querySelectorAll('.chat-history-item').forEach(item => {
          item.onclick = () => {
            const chatId = item.getAttribute('data-chat-id')
            if (chatId) {
              this.loadChat(chatId)
              this.showChatTab()
            }
          }
        })
        
        // Update highlight for current chat
        const currentChatId = document.getElementById('current-chat-id')?.value
        if (currentChatId) {
          this.updateHistoryHighlight(currentChatId)
        }
      }
    } catch (error) {
      console.error('Error refreshing history:', error)
    }
  }

  updateHistoryHighlight(currentChatId) {
    document.querySelectorAll('.chat-history-item').forEach(item => {
      const chatId = item.getAttribute('data-chat-id')
      if (chatId === currentChatId) {
        item.className = 'chat-history-item p-4 bg-blue-50 border-blue-500 rounded-xl cursor-pointer border mb-3'
      } else {
        item.className = 'chat-history-item p-4 bg-white border-gray-200 rounded-xl cursor-pointer border mb-3'
      }
    })
  }

  updateChatTitle(title) {
    const chatTitleElement = document.getElementById('chat-title')
    if (chatTitleElement) {
      chatTitleElement.textContent = title || 'New Chat'
    }
  }
}