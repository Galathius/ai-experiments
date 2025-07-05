import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "container"]
  
  connect() {
    this.setupEventListeners()
    this.scrollToBottom()
  }
  
  setupEventListeners() {
    // Handle form submission (both desktop and mobile)
    document.querySelectorAll('#chat-form, #mobile-chat-form').forEach(form => {
      form.addEventListener('submit', (e) => this.handleSubmit(e))
    })
    
    // Handle Enter key for all inputs
    document.querySelectorAll('#message-input, #mobile-message-input').forEach(input => {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault()
          this.handleSubmit(e)
        }
      })
    })
    
    // Handle chat switching (both desktop and mobile)
    document.querySelectorAll('.chat-item, .mobile-chat-item').forEach(item => {
      item.addEventListener('click', (e) => this.switchChat(e))
    })
    
    // Handle new thread buttons (both desktop and mobile)
    document.querySelectorAll('#new-thread-btn, #mobile-new-thread-btn').forEach(btn => {
      btn.addEventListener('click', () => this.startNewThread())
    })
    
    // Handle mobile tabs
    const mobileChatTab = document.getElementById('mobile-chat-tab')
    const mobileHistoryTab = document.getElementById('mobile-history-tab')
    
    if (mobileChatTab) {
      mobileChatTab.addEventListener('click', () => this.showMobileChatView())
    }
    
    if (mobileHistoryTab) {
      mobileHistoryTab.addEventListener('click', () => this.showMobileHistoryView())
    }
  }
  
  async handleSubmit(e) {
    e.preventDefault()
    
    // Get the active input based on screen size
    const activeInput = window.innerWidth >= 768 
      ? document.getElementById('message-input')
      : document.getElementById('mobile-message-input')
    
    if (!activeInput) return
    
    const content = activeInput.value.trim()
    
    if (!content) return
    
    // Clear input immediately
    activeInput.value = ''
    
    // Add user message to UI
    this.addMessageToUI(content, 'user')
    
    // Show typing indicator
    this.showTypingIndicator()
    
    try {
      const chatId = document.getElementById('current-chat-id')?.value
      const formData = new FormData()
      formData.append('message[content]', content)
      
      // Determine endpoint based on whether we have a chat ID
      const endpoint = chatId ? `/chats/${chatId}/messages` : '/messages'
      
      const response = await fetch(endpoint, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // Remove typing indicator
        this.hideTypingIndicator()
        
        // Add AI response to UI
        this.addMessageToUI(data.ai_message.content, 'assistant')
        
        // Update current chat ID if it's a new chat
        if (!chatId && data.chat_id) {
          const currentChatInput = document.getElementById('current-chat-id')
          if (currentChatInput) {
            currentChatInput.value = data.chat_id
          }
          
          // Remove virtual chat and refresh page to show real chat
          const virtualChat = document.querySelector('.virtual-chat')
          if (virtualChat) {
            // Page will refresh to show the new real chat in sidebar
            window.location.href = '/chats'
          }
        }
      } else {
        this.hideTypingIndicator()
        this.showError('Failed to send message')
      }
    } catch (error) {
      this.hideTypingIndicator()
      this.showError('Network error occurred')
      console.error('Chat error:', error)
    }
  }
  
  addMessageToUI(content, role) {
    const container = document.querySelector('.messages-container')
    const messageDiv = document.createElement('div')
    
    const isUser = role === 'user'
    const avatarIcon = isUser 
      ? `<svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
         </svg>`
      : `<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
         </svg>`
    
    messageDiv.className = `flex items-start space-x-3 ${isUser ? 'flex-row-reverse space-x-reverse' : ''}`
    messageDiv.innerHTML = `
      <div class="flex-shrink-0">
        <div class="w-8 h-8 ${isUser ? 'bg-gray-300' : 'bg-blue-500'} rounded-full flex items-center justify-center">
          ${avatarIcon}
        </div>
      </div>
      <div class="flex-1">
        <div class="${isUser ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-900'} rounded-lg p-4">
          <p>${this.formatMessage(content)}</p>
        </div>
      </div>
    `
    
    container.appendChild(messageDiv)
    this.scrollToBottom()
  }
  
  formatMessage(content) {
    // Basic formatting - replace newlines with <br>
    return content.replace(/\n/g, '<br>')
  }
  
  showTypingIndicator() {
    const container = document.querySelector('.messages-container')
    const typingDiv = document.createElement('div')
    typingDiv.id = 'typing-indicator'
    typingDiv.className = 'flex items-start space-x-3'
    typingDiv.innerHTML = `
      <div class="flex-shrink-0">
        <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
          <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
          </svg>
        </div>
      </div>
      <div class="flex-1">
        <div class="bg-gray-100 rounded-lg p-4">
          <div class="flex space-x-1">
            <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
            <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
            <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
          </div>
        </div>
      </div>
    `
    
    container.appendChild(typingDiv)
    this.scrollToBottom()
  }
  
  hideTypingIndicator() {
    const indicator = document.getElementById('typing-indicator')
    if (indicator) {
      indicator.remove()
    }
  }
  
  showError(message) {
    // You could implement a toast notification here
    console.error(message)
  }
  
  scrollToBottom() {
    const container = document.querySelector('.messages-container')
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  }
  
  async switchChat(e) {
    const chatItem = e.currentTarget
    const chatId = chatItem.dataset.chatId
    
    // Skip if this is a virtual chat
    if (chatItem.classList.contains('virtual-chat')) {
      return
    }
    
    // Remove virtual chat if switching to real chat
    const virtualChat = document.querySelector('.virtual-chat')
    if (virtualChat) {
      virtualChat.remove()
    }
    
    // Update current chat ID
    const currentChatInput = document.getElementById('current-chat-id')
    if (currentChatInput) {
      currentChatInput.value = chatId
    }
    
    // Update UI to show selected chat (both desktop and mobile)
    document.querySelectorAll('.chat-item, .mobile-chat-item').forEach(item => {
      item.classList.remove('bg-blue-50', 'border', 'border-blue-200')
    })
    chatItem.classList.add('bg-blue-50', 'border', 'border-blue-200')
    
    // Load messages for this chat
    await this.loadChatMessages(chatId)
    
    // Switch to chat view on mobile
    if (window.innerWidth < 768) {
      this.showMobileChatView()
    }
  }
  
  async loadChatMessages(chatId) {
    try {
      const response = await fetch(`/chats/${chatId}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.displayMessages(data.messages)
      } else {
        console.error('Failed to load chat messages')
      }
    } catch (error) {
      console.error('Error loading chat messages:', error)
    }
  }
  
  displayMessages(messages) {
    const container = document.querySelector('.messages-container')
    if (!container) return
    
    // Clear current messages and add initial AI message
    this.clearMessagesArea()
    
    // Add each message
    messages.forEach(message => {
      this.addMessageToUI(message.content, message.role)
    })
  }
  
  startNewThread() {
    // Clear current chat ID to start fresh
    const currentChatInput = document.getElementById('current-chat-id')
    if (currentChatInput) {
      currentChatInput.value = ''
    }
    
    // Clear existing chat selection
    document.querySelectorAll('.chat-item').forEach(item => {
      item.classList.remove('bg-blue-50', 'border', 'border-blue-200')
    })
    
    // Remove any existing virtual chat
    const existingVirtual = document.querySelector('.virtual-chat')
    if (existingVirtual) {
      existingVirtual.remove()
    }
    
    // Add virtual "New Chat" to sidebar (desktop only)
    if (window.innerWidth >= 768) { // md breakpoint
      this.addVirtualChatToSidebar()
    }
    
    // Clear messages area and show initial state
    this.clearMessagesArea()
    
    // Switch to chat view on mobile
    this.showMobileChatView()
    
    // Focus on the active input
    const activeInput = window.innerWidth >= 768 
      ? document.getElementById('message-input')
      : document.getElementById('mobile-message-input')
    
    if (activeInput) {
      activeInput.focus()
    }
  }
  
  addVirtualChatToSidebar() {
    const chatHistory = document.querySelector('.flex-1.overflow-y-auto.p-4')
    if (!chatHistory) return
    
    const virtualChat = document.createElement('div')
    virtualChat.className = 'virtual-chat chat-item p-3 rounded-lg bg-blue-50 border border-blue-200 cursor-pointer mb-2'
    virtualChat.innerHTML = `
      <div class="text-sm font-medium text-gray-900 truncate">New Chat</div>
      <div class="text-xs text-gray-500 mt-1">Start typing to begin...</div>
    `
    
    // Insert at the top
    chatHistory.insertBefore(virtualChat, chatHistory.firstChild)
  }
  
  clearMessagesArea() {
    const container = document.querySelector('.messages-container')
    if (!container) return
    
    container.innerHTML = `
      <!-- Initial AI Message -->
      <div class="flex items-start space-x-3">
        <div class="flex-shrink-0">
          <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
            <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
            </svg>
          </div>
        </div>
        <div class="flex-1">
          <div class="bg-gray-100 rounded-lg p-4">
            <p class="text-gray-900">I can answer questions about any Jump meeting. What do you want to know?</p>
          </div>
        </div>
      </div>
    `
  }
  
  // Mobile tab switching methods
  showMobileChatView() {
    const chatPanel = document.getElementById('chat-panel')
    const historyPanel = document.getElementById('mobile-history-panel')
    const chatTab = document.getElementById('mobile-chat-tab')
    const historyTab = document.getElementById('mobile-history-tab')
    
    // Show chat panel, hide history panel
    if (chatPanel) chatPanel.classList.remove('hidden')
    if (historyPanel) historyPanel.classList.add('hidden')
    
    // Update tab styling
    if (chatTab) {
      chatTab.classList.add('border-b-2', 'border-blue-500', 'text-blue-600', 'font-medium')
      chatTab.classList.remove('text-gray-500')
    }
    if (historyTab) {
      historyTab.classList.remove('border-b-2', 'border-blue-500', 'text-blue-600', 'font-medium')
      historyTab.classList.add('text-gray-500')
    }
  }
  
  showMobileHistoryView() {
    const chatPanel = document.getElementById('chat-panel')
    const historyPanel = document.getElementById('mobile-history-panel')
    const chatTab = document.getElementById('mobile-chat-tab')
    const historyTab = document.getElementById('mobile-history-tab')
    
    // Hide chat panel, show history panel
    if (chatPanel) chatPanel.classList.add('hidden')
    if (historyPanel) historyPanel.classList.remove('hidden')
    
    // Update tab styling
    if (historyTab) {
      historyTab.classList.add('border-b-2', 'border-blue-500', 'text-blue-600', 'font-medium')
      historyTab.classList.remove('text-gray-500')
    }
    if (chatTab) {
      chatTab.classList.remove('border-b-2', 'border-blue-500', 'text-blue-600', 'font-medium')
      chatTab.classList.add('text-gray-500')
    }
  }
  
}