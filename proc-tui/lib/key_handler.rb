# frozen_string_literal: true

module KeyHandler
  def handle_key(message)
    if @filter_mode
      return handle_filter_key(message)
    end

    if @split_mode
      return handle_split_key(message)
    end

    case message.to_s
    when "q", "ctrl+c"
      @manager.stop_all
      return [self, Bubbletea.quit]
    when "tab", "l", "right"
      @active_tab = (@active_tab + 1) % @tabs.length
      @scroll_offset = 0
      @auto_scroll = true
    when "shift+tab", "h", "left"
      @active_tab = (@active_tab - 1) % @tabs.length
      @scroll_offset = 0
      @auto_scroll = true
    when "1", "2", "3", "4", "5", "6", "7", "8", "9"
      index = message.to_s.to_i - 1

      if index < @tabs.length
        @active_tab = index
        @scroll_offset = 0
        @auto_scroll = true
      end
    when "0"
      @active_tab = 0
      @scroll_offset = 0
      @auto_scroll = true
    when "up", "k"
      @auto_scroll = false
      @scroll_offset = [0, @scroll_offset - 1].max
    when "down", "j"
      @scroll_offset += 1
      check_auto_scroll
    when "pgup", "ctrl+u"
      @auto_scroll = false
      @scroll_offset = [0, @scroll_offset - visible_log_lines].max
    when "pgdown", "ctrl+d"
      @scroll_offset += visible_log_lines
      check_auto_scroll
    when "home", "g"
      @auto_scroll = false
      @scroll_offset = 0
    when "end", "G"
      @auto_scroll = true
      scroll_to_bottom
    when "/"
      @filter_mode = true
      @filter_text = ""
    when "esc"
      @filter_text = ""
    when "r"
      if @active_tab > 0
        process_name = @tabs[@active_tab]
        @manager.restart_process(process_name)
      end
    when "s"
      if @active_tab > 0
        process_name = @tabs[@active_tab]
        @manager.stop_process(process_name)
      end
    when "S"
      if @active_tab > 0
        process_name = @tabs[@active_tab]
        process_definition = @parser.processes.find { |definition| definition.name == process_name }
        if process_definition
          color = @manager.process_color(process_name)
          @manager.start_process(process_name, process_definition.command, color)
        end
      end
    when "a"
      @auto_scroll = !@auto_scroll
      scroll_to_bottom if @auto_scroll
    when "v"
      enter_split_mode
    end

    [self, nil]
  end

  def handle_split_key(message)
    case message.to_s
    when "q", "ctrl+c"
      @manager.stop_all
      return [self, Bubbletea.quit]
    when "v", "esc"
      if @focus_mode
        @focus_mode = false
      else
        @split_mode = false
      end
    when "f"
      @focus_mode = !@focus_mode
    when "tab", "l", "right"
      @active_pane = (@active_pane + 1) % @split_panes.length
    when "shift+tab", "h", "left"
      @active_pane = (@active_pane - 1) % @split_panes.length
    when "up", "k"
      @auto_scroll = false
      pane = @split_panes[@active_pane]
      @pane_scrolls[pane] = [0, (@pane_scrolls[pane] || 0) - 1].max
    when "down", "j"
      pane = @split_panes[@active_pane]
      @pane_scrolls[pane] = (@pane_scrolls[pane] || 0) + 1
    when "pgup", "ctrl+u"
      @auto_scroll = false
      pane = @split_panes[@active_pane]
      @pane_scrolls[pane] = [0, (@pane_scrolls[pane] || 0) - split_visible_lines].max
    when "pgdown", "ctrl+d"
      pane = @split_panes[@active_pane]
      @pane_scrolls[pane] = (@pane_scrolls[pane] || 0) + split_visible_lines
    when "a"
      @auto_scroll = !@auto_scroll
    when "r"
      process_name = @split_panes[@active_pane]
      @manager.restart_process(process_name)
    end

    [self, nil]
  end

  def handle_filter_key(message)
    case message.to_s
    when "enter", "esc"
      @filter_mode = false
    when "backspace"
      @filter_text = @filter_text[0...-1]
    when "ctrl+u"
      @filter_text = ""
    else
      character = message.to_s
      if character.length == 1 && character.match?(/[[:print:]]/)
        @filter_text += character
      end
    end

    [self, nil]
  end
end
