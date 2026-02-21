# frozen_string_literal: true

module Renderer
  def error_view
    lines = []

    lines << @theme.title.render(" proc-tui ")
    lines << ""
    lines << @theme.error.render("Error: #{@error}")
    lines << ""
    lines << @theme.muted.render("Press q to quit")

    lines.join("\n")
  end

  def split_view
    lines = []

    lines << render_header_row("SPLIT VIEW")
    lines << ""
    lines << render_split_panes
    lines << ""
    lines << render_split_help

    lines.join("\n")
  end

  def render_header_row(mode_label = nil)
    left = @theme.title.render(" proc-tui ")
    running = @manager.processes.values.count(&:running)
    total = @manager.processes.length

    left += "  " + @theme.muted.render("#{running}/#{total} running")
    left += "  " + @theme.active_tab.render(" #{mode_label} ") if mode_label

    right = if @split_mode
      render_split_status_inline
    else
      render_tab_status_inline
    end

    padding = @width - visible_length(left) - visible_length(right) - 2
    padding = [0, padding].max

    left + " " * padding + right
  end

  def render_tab_status_inline
    logs = filtered_logs
    total = logs.length
    visible = visible_log_lines
    max_scroll = [0, total - visible].max

    scroll_percentage = max_scroll.positive? ? ((@scroll_offset.to_f / max_scroll) * 100).round : 100
    auto_scroll_label = @auto_scroll ? @theme.status_running.render("AUTO") : @theme.muted.render("auto")

    lines_string = total.to_s.rjust(5)
    percentage_string = "#{scroll_percentage}%".rjust(4)

    "#{@theme.muted.render("Lines: #{lines_string}")}  #{@theme.muted.render("Scroll: #{percentage_string}")}  #{auto_scroll_label}"
  end

  def render_split_status_inline
    pane = @split_panes[@active_pane]
    logs = @manager.process_logs[pane] || []
    total = logs.length
    visible = split_visible_lines - 1
    scroll = @pane_scrolls[pane] || 0
    max_scroll = [0, total - visible].max

    scroll_percentage = max_scroll.positive? ? ((scroll.to_f / max_scroll) * 100).round : 100
    auto_scroll_label = @auto_scroll ? @theme.status_running.render("AUTO") : @theme.muted.render("auto")

    max_name_length = @split_panes.map(&:length).max || 8
    pane_string = pane.ljust(max_name_length)
    lines_string = total.to_s.rjust(5)
    percentage_string = "#{scroll_percentage}%".rjust(4)

    "#{@theme.muted.render("Pane: #{pane_string}")}  #{@theme.muted.render("Lines: #{lines_string}")}  #{@theme.muted.render("Scroll: #{percentage_string}")}  #{auto_scroll_label}"
  end

  def render_tabs
    @tabs.each_with_index.map do |tab, index|
      name = tab == ProcTUI::TAB_ALL ? "All" : tab
      is_active = index == @active_tab

      if tab != ProcTUI::TAB_ALL
        color = @manager.process_color(tab)
        running = @manager.running?(tab)
        status_icon = running ? "" : " ✗"
        dot = @theme.colored_dot(color).render("●")

        if is_active
          tab_style = @theme.active_process_tab(color)
          "#{tab_style.render(" ● #{name} ")}#{status_icon}"
        else
          "#{dot} #{@theme.tab.render(name)}#{status_icon}"
        end
      else
        style = is_active ? @theme.active_tab : @theme.tab
        style.render(name)
      end
    end.join("  ")
  end

  def render_filter_bar
    if @filter_mode
      cursor = @theme.filter.render("█")
      "  #{@theme.filter.render("/")} #{@filter_text}#{cursor}"
    elsif !@filter_text.empty?
      count = filtered_logs.length
      "  #{@theme.filter.render("Filter:")} #{@filter_text} (#{count} matches)"
    else
      ""
    end
  end

  def render_logs
    logs = filtered_logs
    visible = visible_log_lines - (@filter_mode || !@filter_text.empty? ? 2 : 0)

    if logs.empty?
      return @theme.muted.render("  No logs yet...")
    end

    start_index = @scroll_offset
    end_index = [start_index + visible, logs.length].min
    visible_logs = logs[start_index...end_index] || []

    max_name_length = @tabs.reject { |tab| tab == ProcTUI::TAB_ALL }.map(&:length).max || 8

    lines = visible_logs.map do |log|
      text = log.text

      if !@filter_text.empty? && text.downcase.include?(@filter_text.downcase)
        text = highlight_matches(text, @filter_text)
      end

      if all_tab?
        if log.system
          line_style = @theme.system_text
          prefix_style = @theme.system_prefix
          separator_style = @theme.dim
        else
          line_style = @theme.log_line(log.color, log.background_color)
          prefix_style = @theme.log_prefix(log.color)
          separator_style = @theme.white_separator
        end

        prefix = prefix_style.render(" #{log.process_name.ljust(max_name_length)} ")
        separator = separator_style.render(" │ ")

        inner_width = @width - max_name_length - 10
        styled_text = line_style.render(text[0...inner_width].to_s.ljust(inner_width))

        "#{prefix}#{separator}#{styled_text}"
      else
        inner_width = @width - 6
        if log.system
          @theme.system_text.render(text[0...inner_width].to_s.ljust(inner_width))
        else
          text[0...inner_width].to_s.ljust(inner_width)
        end
      end
    end

    while lines.length < visible
      lines << ""
    end

    content = lines.join("\n")

    @theme.log_box(@width - 2).render(content)
  end

  def render_help
    bindings = if @filter_mode
                 [
                   ["enter/esc", "done"],
                   ["ctrl+u", "clear"]
                 ]
               else
                 [
                   ["←/→", "tabs"],
                   ["↑/↓", "scroll"],
                   ["/", "filter"],
                   ["v", "split"],
                   ["a", "auto"],
                   ["r", "restart"],
                   ["q", "quit"]
                 ]
               end

    help = bindings.map do |key, description|
      "#{@theme.help_key.render(key)} #{@theme.muted.render(description)}"
    end.join(@theme.muted.render(" │ "))

    "  #{help}"
  end

  def render_split_panes
    return "" if @split_panes.empty?

    visible = split_visible_lines

    if @focus_mode
      return render_focused_pane(visible)
    end

    pane_count = @split_panes.length
    pane_width = (@width - pane_count + 1) / pane_count

    if @auto_scroll
      @split_panes.each do |pane|
        logs = @manager.process_logs[pane] || []
        @pane_scrolls[pane] = [0, logs.length - visible].max
      end
    end

    pane_contents = @split_panes.each_with_index.map do |process_name, pane_index|
      logs = @manager.process_logs[process_name] || []
      scroll = @pane_scrolls[process_name] || 0
      is_active = pane_index == @active_pane

      color = @manager.process_color(process_name)

      header_style = is_active ? @theme.pane_header(color) : @theme.inactive_header

      running = @manager.running?(process_name)
      status_indicator = running ? " ●" : " ✗"
      header_text = " #{process_name}#{status_indicator} "
      header = header_style.render(header_text.ljust(pane_width))

      start_index = scroll
      end_index = [start_index + visible - 1, logs.length].min
      visible_logs = logs[start_index...end_index] || []

      log_lines = visible_logs.map do |log|
        text = log.text
        text = text[0...(pane_width - 2)] + "…" if text.length > pane_width - 1
        line = " #{text}".ljust(pane_width)

        if log.system
          @theme.system_text.render(line)
        elsif is_active
          line
        else
          @theme.dim.render(line)
        end
      end

      while log_lines.length < visible - 1
        log_lines << " " * pane_width
      end

      [header] + log_lines
    end

    separator = "│"
    result_lines = []

    (visible).times do |line_index|
      row_parts = pane_contents.map { |pane| pane[line_index] || " " * pane_width }
      result_lines << row_parts.join(separator)
    end

    result_lines.join("\n")
  end

  def render_focused_pane(visible)
    process_name = @split_panes[@active_pane]
    logs = @manager.process_logs[process_name] || []
    scroll = @pane_scrolls[process_name] || 0
    color = @manager.process_color(process_name)

    other_pane_count = @split_panes.length - 1
    hint_width = 3
    main_width = @width - (other_pane_count * (hint_width + 1))

    if @auto_scroll
      @pane_scrolls[process_name] = [0, logs.length - visible].max
      scroll = @pane_scrolls[process_name]
    end

    header_style = @theme.pane_header(color)
    running = @manager.running?(process_name)
    status_indicator = running ? " ●" : " ✗"
    header_text = " #{process_name}#{status_indicator} "
    header = header_style.render(header_text.ljust(main_width))

    start_index = scroll
    end_index = [start_index + visible - 1, logs.length].min
    visible_logs = logs[start_index...end_index] || []

    log_lines = visible_logs.map do |log|
      text = log.text
      text = text[0...(main_width - 2)] + "…" if text.length > main_width - 1
      " #{text}".ljust(main_width)
    end

    while log_lines.length < visible - 1
      log_lines << " " * main_width
    end

    main_content = [header] + log_lines

    hint_columns = @split_panes.each_with_index.map do |pane_name, index|
      next nil if index == @active_pane

      pane_logs = @manager.process_logs[pane_name] || []
      pane_scroll = @pane_scrolls[pane_name] || 0

      hint_header = @theme.inactive_header.render(" … ")

      hint_start = pane_scroll
      hint_end = [hint_start + visible - 1, pane_logs.length].min
      hint_visible = pane_logs[hint_start...hint_end] || []

      hint_lines = hint_visible.map do |_log|
        @theme.dim.render(" … ")
      end

      while hint_lines.length < visible - 1
        hint_lines << " " * hint_width
      end

      [hint_header] + hint_lines
    end.compact

    result_lines = []

    visible.times do |line_index|
      before_hints = @split_panes[0...@active_pane].each_with_index.map do |_, column_index|
        hint_columns[column_index] ? hint_columns[column_index][line_index] : ""
      end

      main_line = main_content[line_index] || " " * main_width

      after_hints = @split_panes[(@active_pane + 1)..].each_with_index.map do |_, offset|
        column_index = @active_pane > 0 ? @active_pane - 1 + offset + 1 : offset
        hint_columns[column_index] ? hint_columns[column_index][line_index] : ""
      end

      parts = before_hints + [main_line] + after_hints
      result_lines << parts.join("│")
    end

    result_lines.join("\n")
  end

  def render_split_help
    bindings = if @focus_mode
      [
        ["↑/↓", "scroll"],
        ["a", "auto"],
        ["r", "restart"],
        ["f/esc", "unfocus"],
        ["q", "quit"]
      ]
    else
      [
        ["←/→", "pane"],
        ["↑/↓", "scroll"],
        ["f", "focus"],
        ["a", "auto"],
        ["r", "restart"],
        ["v/esc", "exit split"],
        ["q", "quit"]
      ]
    end

    help = bindings.map do |key, description|
      "#{@theme.help_key.render(key)} #{@theme.muted.render(description)}"
    end.join(@theme.muted.render(" │ "))

    "  #{help}"
  end

  def highlight_matches(text, query)
    result = ""
    remaining = text
    query_lower = query.downcase

    while (index = remaining.downcase.index(query_lower))
      result += remaining[0...index]
      match_text = remaining[index, query.length]
      result += @theme.match.render(match_text)
      remaining = remaining[(index + query.length)..]
    end

    result + remaining
  end

  def visible_length(string)
    string.gsub(/\e\[[0-9;]*m/, '').length # todo: use Bubbles::ANSI.strip_ansi
  end
end
