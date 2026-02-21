# frozen_string_literal: true

require "bubbletea"

class LogMessage < Bubbletea::Message
  attr_reader :log_line

  def initialize(log_line)
    super()

    @log_line = log_line
  end
end

class TickMessage < Bubbletea::Message
end
