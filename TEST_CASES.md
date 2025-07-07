# Test Cases for Financial Advisor AI Assistant

## Authentication & OAuth Integration

### TC-01: Google OAuth Login
- **Test**: User can log in using Google OAuth
- **Expected**: Successful authentication with email/calendar read/write permissions
- **Verify**: User ***@gmail.com can be added as test user

### TC-02: HubSpot CRM Connection
- **Test**: User can connect HubSpot CRM account via OAuth
- **Expected**: Successful HubSpot integration with access to contacts and notes

## Data Import & RAG System

### TC-03: Gmail Data Import
- **Test**: System imports emails from Gmail
- **Expected**: Emails stored in database with embeddings for RAG search

### TC-04: HubSpot Data Import
- **Test**: System imports contacts and contact notes from HubSpot
- **Expected**: CRM data stored with embeddings for semantic search

### TC-05: Google Calendar Import
- **Test**: System imports calendar events
- **Expected**: Calendar events available for scheduling queries

## Chat Interface & RAG Queries

### TC-06: Client Information Queries
- **Test**: Ask "Who mentioned their kid plays baseball?"
- **Expected**: AI searches emails/CRM and provides relevant client information

### TC-07: Specific Client Context
- **Test**: Ask "Why did greg say he wanted to sell AAPL stock?"
- **Expected**: AI retrieves context from emails/notes and explains Greg's reasoning

### TC-08: RAG Context Accuracy
- **Test**: Ask questions about specific client interactions
- **Expected**: AI provides accurate answers based on imported data

## Tool Calling & Task Management

### TC-09: Appointment Scheduling
- **Test**: "Schedule an appointment with Sara Smith"
- **Expected**: 
  - Look up Sara in HubSpot/emails
  - Send email with available times
  - Create task to track scheduling process

### TC-10: Task Persistence
- **Test**: Verify scheduling task continues after email response
- **Expected**: AI follows up appropriately based on client response

### TC-11: Complex Scheduling Edge Cases
- **Test**: Client responds with unavailable times
- **Expected**: AI sends new available times and updates task status

## Memory & Ongoing Instructions

### TC-12: Ongoing Instruction Storage
- **Test**: "When someone emails me that is not in HubSpot, create a contact"
- **Expected**: Instruction stored in memory for future processing

### TC-13: New Contact Auto-Creation
- **Test**: Receive email from unknown sender
- **Expected**: AI creates HubSpot contact with email note

### TC-14: Welcome Email Automation
- **Test**: "When I create a contact in HubSpot, send them a thank you email"
- **Expected**: Auto-sends welcome email when new contact is created

### TC-15: Calendar Event Notifications
- **Test**: "When I add calendar event, email attendees about meeting"
- **Expected**: Auto-emails attendees when new calendar event is created

## Proactive Assistance

### TC-16: Proactive Meeting Responses
- **Test**: Client emails asking about upcoming meeting
- **Expected**: AI looks up calendar and responds automatically

### TC-17: Webhook/Polling Integration
- **Test**: Changes in Gmail/Calendar/HubSpot trigger proactive actions
- **Expected**: AI evaluates new data against ongoing instructions

### TC-18: Contextual Proactive Actions
- **Test**: AI takes appropriate action based on incoming data
- **Expected**: Actions align with stored ongoing instructions

## User Interface

### TC-19: Chat Interface Design
- **Test**: Chat UI matches provided design specifications
- **Expected**: Professional ChatGPT-like interface with proper styling

### TC-20: Message Flow
- **Test**: User can send messages and receive AI responses
- **Expected**: Smooth conversational flow with proper message formatting

### TC-21: Tool Call Visibility
- **Test**: User can see when AI is performing actions
- **Expected**: Clear indication of tool usage and task completion

## System Integration

### TC-22: Full Deployment
- **Test**: App deployed to Render/Fly.io or similar platform
- **Expected**: Fully functional deployed application

### TC-23: End-to-End Workflow
- **Test**: Complete client interaction from email to calendar appointment
- **Expected**: All steps automated with proper task tracking

### TC-24: Error Handling
- **Test**: System handles OAuth failures, API errors gracefully
- **Expected**: Appropriate error messages and recovery mechanisms

## Performance & Reliability

### TC-25: RAG Search Performance
- **Test**: Search queries return results within reasonable time
- **Expected**: Sub-second response times for context retrieval

### TC-26: Concurrent Task Management
- **Test**: Multiple ongoing tasks handled simultaneously
- **Expected**: Tasks tracked independently without conflicts

### TC-27: Data Consistency
- **Test**: Imported data remains consistent across sessions
- **Expected**: No data loss or corruption during normal operations
