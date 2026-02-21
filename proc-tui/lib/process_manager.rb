# frozen_string_literal: true

require "pty"
require "io/wait"

class ProcessManager
  COLORS = %w[
    #FF79C6
    #8BE9FD
    #50FA7B
    #FFB86C
    #BD93F9
    #F1FA8C
    #FF5555
    #6272A4
  ].freeze

  BACKGROUND_COLORS = %w[
    #2D1F2B
    #1F2D2D
    #1F2D1F
    #2D2A1F
    #252033
    #2D2D1F
    #2D1F1F
    #1F2029
  ].freeze

  ProcessInfo = Struct.new(:name, :command, :pid, :pty, :color, :background_color, :running, keyword_init: true)
  LogLine = Struct.new(:process_name, :text, :color, :background_color, :timestamp, :system, keyword_init: true)

  attr_reader :processes, :log_lines, :process_logs

  def initialize
    @processes = {}
    @log_lines = []
    @process_logs = {}
    @mutex = Mutex.new
    @callbacks = []
    @max_log_lines = 10_000
  end

  def on_log(&block)
    @callbacks << block
  end

  def start_process(name, command, color, background_color = nil)
    return if @processes[name]&.running

    @process_logs[name] ||= []
    background_color ||= BACKGROUND_COLORS[0]

    begin
      pty_read, pty_write, pid = PTY.spawn(command)

      process_info = ProcessInfo.new(
        name: name,
        command: command,
        pid: pid,
        pty: pty_read,
        color: color,
        background_color: background_color,
        running: true
      )

      @processes[name] = process_info

      start_reader_thread(process_info, pty_read)

      Thread.new do
        begin
          Process.wait(pid)
          status = $?.exitstatus

          @mutex.synchronize do
            process_info.running = false
            add_log_line(name, "[exited with status #{status}]", color, background_color, system: true)
          end
        rescue Errno::ECHILD
          @mutex.synchronize do
            process_info.running = false
          end
        end
      end

      add_log_line(name, "[started: #{command}]", color, background_color, system: true)
    rescue PTY::ChildExited => error
      add_log_line(name, "[failed to start: #{error.message}]", color, nil, system: true)
    rescue Errno::ENOENT => error
      add_log_line(name, "[command not found: #{error.message}]", color, nil, system: true)
    end
  end

  def stop_process(name)
    process_info = @processes[name]
    return unless process_info&.running

    begin
      Process.kill("TERM", process_info.pid)

      Thread.new do
        sleep 2
        begin
          Process.kill("KILL", process_info.pid) if process_info.running
        rescue Errno::ESRCH
          # Process already gone
        end
      end
    rescue Errno::ESRCH
      # Process already gone
    end

    process_info.running = false

    add_log_line(name, "[stopped]", process_info.color, process_info.background_color, system: true)
  end

  def restart_process(name)
    process_info = @processes[name]
    return unless process_info

    add_log_line(name, "[restarting...]", "#FF5555", process_info.background_color, system: true)
    stop_process(name)
    sleep 0.5
    start_process(name, process_info.command, process_info.color, process_info.background_color)
  end

  def stop_all
    @processes.each_key do |name|
      stop_process(name)
    end
  end

  def start_all(process_definitions)
    process_definitions.each_with_index do |process_definition, index|
      color = COLORS[index % COLORS.length]
      background_color = BACKGROUND_COLORS[index % BACKGROUND_COLORS.length]
      start_process(process_definition.name, process_definition.command, color, background_color)
    end
  end

  def running?(name)
    @processes[name]&.running || false
  end

  def all_running?
    @processes.values.all?(&:running)
  end

  def any_running?
    @processes.values.any?(&:running)
  end

  def process_color(name)
    @processes[name]&.color || COLORS[0]
  end

  def process_background_color(name)
    @processes[name]&.background_color || BACKGROUND_COLORS[0]
  end

  private

  def start_reader_thread(process_info, pty_reader)
    Thread.new do
      begin
        pty_reader.each_line do |line|
          @mutex.synchronize do
            add_log_line(process_info.name, line.chomp, process_info.color, process_info.background_color)
          end
        end
      rescue Errno::EIO, IOError
        # PTY closed, process ended
      end
    end
  end

  def add_log_line(process_name, text, color, background_color = nil, system: false)
    background_color ||= BACKGROUND_COLORS[0]

    log_line = LogLine.new(
      process_name: process_name,
      text: text,
      color: color,
      background_color: background_color,
      timestamp: Time.now,
      system: system
    )

    @log_lines << log_line
    @process_logs[process_name] ||= []
    @process_logs[process_name] << log_line

    if @log_lines.length > @max_log_lines
      @log_lines.shift(@log_lines.length - @max_log_lines)
    end

    if @process_logs[process_name].length > @max_log_lines
      @process_logs[process_name].shift(@process_logs[process_name].length - @max_log_lines)
    end

    @callbacks.each { |callback| callback.call(log_line) }
  end
end
