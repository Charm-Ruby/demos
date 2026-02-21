# frozen_string_literal: true

require "lipgloss"
require "bubbles"
require "bubbletea"

require_relative "theme"
require_relative "messages"
require_relative "procfile_parser"
require_relative "process_manager"
require_relative "key_handler"
require_relative "renderer"

class ProcTUI
  include Bubbletea::Model
  include KeyHandler
  include Renderer

  TAB_ALL = "__all__"

  def initialize(procfile_path)
    @procfile_path = procfile_path
    @parser = ProcfileParser.new
    @manager = ProcessManager.new
    @theme = Theme.new
    @width = 120
    @height = 40

    @tabs = [TAB_ALL]        # Tab names (TAB_ALL + process names)
    @active_tab = 0          # Current tab index
    @scroll_offset = 0       # Log scroll position
    @auto_scroll = true      # Auto-scroll to bottom

    @filter_mode = false     # Filter/search mode
    @filter_text = ""        # Current filter text

    @split_mode = false      # Whether split view is active
    @split_panes = []        # Which processes are in split view
    @active_pane = 0         # Which pane is focused in split view
    @pane_scrolls = {}       # Scroll offset per pane
    @focus_mode = false      # Whether focused on single pane in split view

    @error = nil

    load_procfile
  end

  def init
    [self, Bubbletea.tick(0.1) { TickMessage.new }]
  end

  def update(message)
    case message
    when Bubbletea::WindowSizeMessage
      @width = message.width
      @height = message.height

      return [self, nil]
    when TickMessage
      check_scroll_update

      return [self, Bubbletea.tick(0.1) { TickMessage.new }]
    when Bubbletea::KeyMessage
      return handle_key(message)
    end

    [self, nil]
  end

  def view
    return error_view if @error
    return split_view if @split_mode

    lines = []

    lines << render_header_row
    lines << ""

    lines << render_tabs
    lines << ""

    if @filter_mode || !@filter_text.empty?
      lines << render_filter_bar
      lines << ""
    end

    lines << render_logs
    lines << ""
    lines << render_help

    lines.join("\n")
  end

  private

  def load_procfile
    unless File.exist?(@procfile_path)
      @error = "Procfile not found: #{@procfile_path}"
      return
    end

    @parser.parse_file(@procfile_path)

    if @parser.processes.empty?
      @error = "No processes defined in Procfile"
      return
    end

    @tabs = [TAB_ALL] + @parser.processes.map(&:name)

    @manager.on_log do |_log_line|
      # Log received - will be picked up by tick
    end

    @manager.start_all(@parser.processes)
  rescue StandardError => error
    @error = "Error loading Procfile: #{error.message}"
  end

  def enter_split_mode
    @split_panes = @parser.processes.map(&:name)
    return if @split_panes.empty?

    @split_mode = true
    @active_pane = 0
    @pane_scrolls = {}
    @split_panes.each { |pane_name| @pane_scrolls[pane_name] = 0 }
  end

  def check_scroll_update
    scroll_to_bottom if @auto_scroll
  end

  def check_auto_scroll
    logs = filtered_logs
    max_scroll = [0, logs.length - visible_log_lines].max
    @auto_scroll = @scroll_offset >= max_scroll - 1
  end

  def scroll_to_bottom
    logs = filtered_logs
    @scroll_offset = [0, logs.length - visible_log_lines].max
  end

  def visible_log_lines
    @height - 9  # Header, blank, tabs, blank, logs, blank, help
  end

  def split_visible_lines
    @height - 4  # Header, blank, blank, help
  end

  def current_log_lines
    if @active_tab == 0
      @manager.log_lines
    else
      process_name = @tabs[@active_tab]
      @manager.process_logs[process_name] || []
    end
  end

  def all_tab?
    @tabs[@active_tab] == TAB_ALL
  end

  def filtered_logs
    logs = current_log_lines
    return logs if @filter_text.empty?

    logs.select { |log| log.text.downcase.include?(@filter_text.downcase) }
  end
end
