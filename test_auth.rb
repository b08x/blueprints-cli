# frozen_string_literal: true

class UserAuthentication
  def initialize(username, password)
    @username = username
    @password = password
  end

  def login
    return false if @username.nil? || @password.nil?

    # Simple authentication logic
    if valid_credentials?
      create_session
      true
    else
      false
    end
  end

  private

  def valid_credentials?
    # Simplified validation
    @username.length > 3 && @password.length > 6
  end

  def create_session
    puts "Session created for #{@username}"
  end
end
