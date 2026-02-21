# frozen_string_literal: true

class ProcfileParser
  Process = Struct.new(:name, :command, keyword_init: true)

  attr_reader :processes

  def initialize
    @processes = []
  end

  def parse(content)
    @processes = []

    content.each_line do |line|
      line = line.strip

      next if line.empty? || line.start_with?("#")

      if line =~ /\A([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.+)\z/
        name = ::Regexp.last_match(1)
        command = ::Regexp.last_match(2)

        @processes << Process.new(name: name, command: command)
      end
    end

    self
  end

  def parse_file(path)
    parse(File.read(path))
  end
end
