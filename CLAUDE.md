# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby on Rails 8.0 application for a financial advisor AI assistant that integrates with Gmail, Google Calendar, and HubSpot. The application features:

- Google OAuth authentication with email/calendar permissions
- HubSpot CRM integration via OAuth
- ChatGPT-like chat interface for querying client data
- RAG (Retrieval-Augmented Generation) capabilities for email and CRM data
- AI agent with tool calling for task automation
- Proactive assistance based on ongoing instructions

## Technology Stack

- **Backend**: Ruby on Rails 8.0.2
- **Database**: PostgreSQL with multiple databases (main, cache, queue, cable)
- **Authentication**: OmniAuth with Google OAuth2 and HubSpot OAuth
- **Styling**: Tailwind CSS
- **Frontend**: Stimulus controllers, Turbo Rails, Importmap
- **JavaScript Libraries**: date-fns for date parsing and formatting
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **Real-time**: Solid Cable (Action Cable)
- **Asset Pipeline**: Propshaft
- **AI Integration**: OpenAI GPT-4o-mini with tool calling
- **Vector Database**: pgvector for RAG embeddings

## Development Commands

### Setup and Dependencies
```bash
bundle install                    # Install Ruby gems
bin/rails db:create              # Create databases
bin/rails db:migrate             # Run migrations
bin/rails db:seed               # Seed database
```

### Running the Application
```bash
bin/dev                          # Start development server with CSS watching
bin/rails server                 # Start Rails server only
bin/rails tailwindcss:watch     # Watch Tailwind CSS changes
```

### Testing
```bash
bin/rails test                   # Run all tests
bin/rails test:system           # Run system tests
bin/rails test test/models/user_test.rb  # Run specific test file
```

### Code Quality
```bash
bin/rubocop                      # Run RuboCop linter
bin/brakeman                     # Run security analysis
```

### Database Operations
```bash
bin/rails db:migrate             # Run pending migrations
bin/rails db:rollback           # Rollback last migration
bin/rails db:reset              # Drop, create, migrate, and seed
bin/rails console               # Open Rails console
```

## Architecture

### Models
- **User**: Handles authentication via OAuth identities only
- **Session**: Manages user sessions
- **OmniAuthIdentity**: Stores OAuth provider connections (Google, HubSpot)
- **Chat**: Stores chat conversations with title generation
- **Message**: Individual chat messages with role (user/assistant)
- **Email**: Imported Gmail messages with full content and metadata
- **CalendarEvent**: Google Calendar events with attendees and descriptions
- **HubspotContact**: CRM contacts with company and contact details
- **HubspotNote**: CRM notes linked to contacts
- **Task**: AI-created and user tasks with priorities and due dates
- **ActionLog**: Tool execution tracking for AI agent actions
- **Embedding**: Vector embeddings for RAG search across all content types (emails, events, contacts, notes)

### Controllers
- **DashboardController**: Main dashboard with data overview and chat modal
- **ChatsController**: Chat interface and history management
- **MessagesController**: AI message processing with RAG and tool calling
- **ApplicationController**: Base controller with authentication concerns
- **Sessions::OmniAuthsController**: Handles OAuth callbacks (Google, HubSpot)
- **SessionsController**: Session management
- **GoogleController**: Gmail and Calendar data import
- **HubspotController**: CRM data import and management

### Authentication Flow
- Google OAuth2 integration via OmniAuth (OAuth-only, no password authentication)
- HubSpot OAuth integration for CRM access
- User creation from OAuth data with automatic name assignment
- Session-based authentication

### Frontend Architecture
- **Stimulus Controllers**: 
  - `dashboard_controller.js`: Handles chat modal opening/closing
  - `chat_modal_controller.js`: Manages chat interface, message sending, calendar event formatting
- **Importmap Configuration**: Date-fns library for professional date parsing
- **Modal System**: Chat interface loads dynamically via AJAX
- **Calendar Events**: Processed with date-fns and rendered as formatted cards
- **Tab Navigation**: Chat and History tabs with proper Stimulus actions

### Database Schema
- Multi-database setup for production (main, cache, queue, cable)
- PostgreSQL with pgvector extension for embeddings
- Comprehensive migrations for all models including RAG embeddings
- Indexes for performance on user_id, status, and vector similarity

### Key Configuration
- **Routes**: Dashboard as root, RESTful resources for all models
- **OAuth**: Google OAuth2 and HubSpot OAuth with proper scopes
- **Background Jobs**: Solid Queue for data import and proactive monitoring
- **Vector Search**: pgvector for semantic search across emails, events, contacts
- **AI Tools**: Registry system for email sending, calendar events, tasks, CRM notes
- **Development**: Uses `bin/dev` for concurrent Rails server and Tailwind watching
- **Production**: Configured for deployment with environment variables

## Project Context

This application is part of a paid challenge to build a comprehensive AI assistant for financial advisors within 72 hours. The final product should be fully deployed and demonstrate:

1. ✅ Google OAuth integration with appropriate permissions
2. ✅ HubSpot CRM connectivity  
3. ✅ Chat interface for client data queries using RAG
4. ✅ AI agent with tool calling for automated tasks
5. ✅ Memory and ongoing instruction capabilities
6. ✅ Proactive assistance based on webhook/polling events

## Current Implementation Status

### Completed Features
- **Authentication**: Google OAuth2 and HubSpot OAuth integration
- **Data Import**: Gmail, Google Calendar, HubSpot Contacts & Notes
- **RAG System**: Vector embeddings with pgvector for semantic search
- **AI Chat**: OpenAI GPT-4o-mini with conversation history and context
- **Tool Calling**: Email sending, calendar events, task management, CRM notes
- **Task Management**: AI-created tasks with priorities and due dates
- **Proactive Monitoring**: Background jobs for data freshness and proactive assistance
- **Dashboard**: Complete overview with connection status and recent data
- **Chat Modal**: Professional interface with calendar event formatting

### Architecture Highlights
- **Rails 8 Patterns**: Proper Stimulus controllers, no inline JavaScript
- **Modular Design**: Separate controllers for dashboard and chat functionality  
- **Professional UI**: Tailwind CSS with modal system and responsive design
- **Background Processing**: Solid Queue for data sync and proactive actions
- **Vector Search**: Semantic search across emails, calendar, and CRM data
- **Tool Registry**: Extensible system for AI agent capabilities

### Key Services
- `EmbeddingService`: Handles vector embeddings for RAG
- `ToolRegistry` & `ToolExecutor`: AI agent tool calling system  
- `TaskManager`: Persistent memory and task management
- `ProactiveService`: Background monitoring and proactive assistance
- `SyncManager`: Automated data freshness management