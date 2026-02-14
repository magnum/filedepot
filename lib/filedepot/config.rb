# frozen_string_literal: true

require "fileutils"
require "yaml"

module Filedepot
  class Config
    CONFIG_DIR = File.expand_path("~/.filedepot")
    CONFIG_PATH = File.join(CONFIG_DIR, "config.yml")

    DEFAULT_CONFIG = <<~YAML
      default_source: test
      sources:
        - name: test
          type: ssh
          host: 127.0.0.1
          username:
          base_path: %<base_path>s
    YAML

    class << self
      def ensure_config!
        return if File.exist?(CONFIG_PATH)

        FileUtils.mkdir_p(CONFIG_DIR)
        base_path = File.join(File.expand_path("~"), "filedepot")
        File.write(CONFIG_PATH, format(DEFAULT_CONFIG, base_path: base_path))
      end

      def load
        ensure_config!
        YAML.load_file(CONFIG_PATH)
      end

      def current_source
        config = load
        default = config["default_source"]
        sources = config["sources"] || []
        return nil if sources.empty?

        source = sources.find { |s| (s["name"] || s[:name]) == default }
        source || sources.first
      end
    end
  end
end
