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
- **Authentication**: OmniAuth with Google OAuth2
- **Styling**: Tailwind CSS
- **Frontend**: Stimulus controllers, Turbo Rails, Importmap
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **Real-time**: Solid Cable (Action Cable)
- **Asset Pipeline**: Propshaft

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
- **User**: Handles authentication with secure password and OAuth identities
- **Session**: Manages user sessions
- **OmniAuthIdentity**: Stores OAuth provider connections
- **Chat**: Stores chat interactions (basic model, likely to be expanded)

### Controllers
- **ChatsController**: Main chat interface at root path
- **ApplicationController**: Base controller with authentication concerns
- **Sessions::OmniAuthsController**: Handles OAuth callbacks
- **SessionsController**: Session management
- **PasswordsController**: Password reset functionality

### Authentication Flow
- Google OAuth2 integration via OmniAuth
- User creation from OAuth data with automatic name assignment
- Session-based authentication with secure password fallback

### Database Schema
- Multi-database setup for production (main, cache, queue, cable)
- PostgreSQL with standard Rails conventions
- Migrations include users, sessions, chats, and OAuth identities

### Key Configuration
- **Routes**: RESTful resources for chats, sessions, passwords
- **OAuth**: Google OAuth2 configured with callback routes
- **Development**: Uses `bin/dev` for concurrent Rails server and Tailwind watching
- **Production**: Configured for deployment with environment variables

## Project Context

This application is part of a paid challenge to build a comprehensive AI assistant for financial advisors within 72 hours. The final product should be fully deployed and demonstrate:

1. Google OAuth integration with appropriate permissions
2. HubSpot CRM connectivity
3. Chat interface for client data queries using RAG
4. AI agent with tool calling for automated tasks
5. Memory and ongoing instruction capabilities
6. Proactive assistance based on webhook/polling events

The codebase appears to be in early stages with basic authentication and chat scaffolding in place.