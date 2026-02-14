# frozen_string_literal: true

require "fileutils"
require "yaml"

module Filedepot
  class Config
    CONFIG_DIR = File.expand_path("~/.filedepot")
    CONFIG_PATH = File.join(CONFIG_DIR, "config.yml")

    class << self
      def exists?
        File.exist?(CONFIG_PATH)
      end

      def load
        return nil unless exists?

        YAML.load_file(CONFIG_PATH)
      end

      def current_store
        config = load
        return nil if config.nil?

        default = config["default_store"]
        stores = config["stores"] || []
        return nil if stores.empty?

        store = stores.find { |s| (s["name"] || s[:name]) == default }
        store || stores.first
      end
    end
  end
end
