# frozen_string_literal: true

require "lipgloss"

class Theme
  attr_reader :title, :tab, :active_tab, :muted, :help_key, :error, :filter,
              :match, :status_running, :status_stopped, :dim, :system_text,
              :inactive_header, :system_prefix, :white_separator

  def initialize
    @title = Lipgloss::Style.new.bold(true).foreground("#FFFDF5").background("#FF5555").padding_left(2).padding_right(2)
    @tab = Lipgloss::Style.new.foreground("#626262").padding_left(1).padding_right(1)
    @active_tab = Lipgloss::Style.new.bold(true).foreground("#FFFDF5").background("#6C50FF").padding_left(1).padding_right(1)
    @muted = Lipgloss::Style.new.foreground("#626262")
    @help_key = Lipgloss::Style.new.foreground("#909090")
    @error = Lipgloss::Style.new.foreground("#FF5555").bold(true)
    @filter = Lipgloss::Style.new.foreground("#F1FA8C")
    @match = Lipgloss::Style.new.background("#6C50FF").foreground("#FFFFFF")
    @status_running = Lipgloss::Style.new.foreground("#50FA7B")
    @status_stopped = Lipgloss::Style.new.foreground("#FF5555")
    @dim = Lipgloss::Style.new.foreground("#6272A4")
    @system_text = Lipgloss::Style.new.foreground("#6272A4").italic(true)
    @inactive_header = Lipgloss::Style.new.foreground("#6272A4").background("#44475A")
    @system_prefix = Lipgloss::Style.new.background("#6272A4").foreground("#282A36").bold(true)
    @white_separator = Lipgloss::Style.new.foreground("#FFFFFF")
  end

  def pane_header(color)
    Lipgloss::Style.new.foreground("#282A36").background(color).bold(true)
  end

  def colored_dot(color)
    Lipgloss::Style.new.foreground(color)
  end

  def active_process_tab(color)
    Lipgloss::Style.new.background(color).foreground("#282A36").bold(true)
  end

  def log_line(color, background_color)
    Lipgloss::Style.new.background(background_color).foreground(color)
  end

  def log_prefix(color)
    Lipgloss::Style.new.background(color).foreground("#282A36").bold(true)
  end

  def log_box(width)
    Lipgloss::Style.new.border(:rounded).border_foreground("#6272A4").padding_left(1).padding_right(1).width(width)
  end
end
