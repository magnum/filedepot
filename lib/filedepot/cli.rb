# frozen_string_literal: true

require "thor"

module Filedepot
  class CLI < Thor
    package_name "filedepot"

    COMMAND_HELP = {
      config: <<~HELP,
        Usage:
          filedepot config

        Opens the config file ($HOME/.filedepot/config.yml) using $EDITOR.
      HELP
      push: <<~HELP,
        Usage:
          filedepot push HANDLE

        Send a file with a specific handle to the current storage.
      HELP
      pull: <<~HELP,
        Usage:
          filedepot pull HANDLE [VERSION]

        Get the latest version of file with a specific handle from the current storage.
        VERSION is optional; if omitted, retrieves the latest version.
      HELP
      versions: <<~HELP,
        Usage:
          filedepot versions HANDLE

        List all versions of a handle. Each version has an integer ID from 1 to n.
      HELP
      delete: <<~HELP
        Usage:
          filedepot delete HANDLE [VERSION]

        After confirmation, deletes all versions of a file.
        If VERSION is specified, deletes only that specific version.
      HELP
    }.freeze

    desc "config", "Open the config file using $EDITOR"
    def config
      config_path = Config::CONFIG_PATH
      Config.ensure_config!
      editor = ENV["EDITOR"] || "vim"
      exec(editor, config_path)
    end

    desc "push HANDLE", "Send a file with a specific handle to the current storage"
    def push(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:push]
        return
      end
      puts "push: would send file with handle '#{handle}' to current storage (not implemented)"
    end

    desc "pull HANDLE [VERSION]", "Get the latest version of file with a specific handle from the current storage"
    def pull(handle = nil, version = nil)
      if handle.nil?
        puts COMMAND_HELP[:pull]
        return
      end
      version_str = version ? " version #{version}" : " latest version"
      puts "pull: would get file '#{handle}'#{version_str} from current storage (not implemented)"
    end

    desc "versions HANDLE", "List all versions of a handle (each version has an integer from 1 to n)"
    def versions(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:versions]
        return
      end
      puts "versions: would list all versions of handle '#{handle}' (not implemented)"
    end

    desc "delete HANDLE [VERSION]", "After confirmation, delete all versions of a file; or only a specific version if specified"
    def delete(handle = nil, version = nil)
      if handle.nil?
        puts COMMAND_HELP[:delete]
        return
      end
      version_str = version ? " version #{version}" : " all versions"
      puts "delete: would delete file '#{handle}'#{version_str} after confirmation (not implemented)"
    end

    default_task :default

    desc "default", "Show current source and list of available commands"
    def default
      source = Config.current_source
      config = Config.load
      default_name = config["default_source"]

      puts "filedepot"
      puts "--------"
      puts "Current source: #{default_name}"
      if source
        puts "  Type: #{source['ssh']} (#{source['host']})"
        puts "  Base path: #{source['base_path']}"
      end
      puts ""
      puts "Available commands:"
      puts "  filedepot config              Open config file using $EDITOR"
      puts "  filedepot push HANDLE         Send file to current storage"
      puts "  filedepot pull HANDLE [VER]   Get file from storage (version optional)"
      puts "  filedepot versions HANDLE     List all versions of a handle"
      puts "  filedepot delete HANDLE [VER] Delete file(s) after confirmation"
      puts ""
      puts "Use 'filedepot help COMMAND' for more information on a command."
    end

    def self.exit_on_failure?
      true
    end
  end
end
