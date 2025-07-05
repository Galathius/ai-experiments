Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer if Rails.env.development? || Rails.env.test?
  provider :google_oauth2, 
    Rails.application.credentials.dig(:oauth, :google, :client_id), 
    Rails.application.credentials.dig(:oauth, :google, :client_secret),
    {
      scope: 'email,profile,https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/calendar',
      access_type: 'offline',
      prompt: 'consent'
    }
end
