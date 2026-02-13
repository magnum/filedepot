# frozen_string_literal: true

require "fileutils"
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
          filedepot push HANDLE FILE

        Send a file to the current storage with a specific handle.
        Example: filedepot push test test.txt
      HELP
      pull: <<~HELP,
        Usage:
          filedepot pull HANDLE [--path PATH] [--version VERSION]

        Get a file from storage. By default gets the latest version and saves to current directory.
        Options:
          --path PATH    Save to this local path (e.g. ./test/file.txt)
          --version N   Get specific version (default: latest)
        Examples:
          filedepot pull test
          filedepot pull test --path ./test/file.txt
          filedepot pull test --version 2
          filedepot pull test --version 2 --path ./test/file.txt
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

    desc "push HANDLE FILE", "Send a file to the current storage with a specific handle"
    def push(handle, file_path)
      source = Config.current_source
      if source.nil?
        puts "Error: No storage source configured. Run 'filedepot config' to set up."
        return
      end

      storage = Storage::Base.for(source)
      storage.push(handle, file_path)
      puts "Pushed #{file_path} as #{handle} (version #{storage.current_version(handle)})"
    end

    desc "pull HANDLE", "Get file from storage"
    method_option :path, type: :string, desc: "Local path to save the file"
    method_option :version, type: :string, desc: "Version number to pull (default: latest)"
    def pull(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:pull]
        return
      end

      source = Config.current_source
      if source.nil?
        puts "Error: No storage source configured. Run 'filedepot config' to set up."
        return
      end

      local_path = options[:path]
      version = (options[:version].nil? || options[:version].empty?) ? nil : options[:version].to_i

      storage = Storage::Base.for(source)
      info = storage.pull_info(handle, version, local_path)
      target_path = info[:target_path]

      parent_dir = File.dirname(target_path)
      unless parent_dir == "." || File.directory?(parent_dir)
        return unless confirm?("create local directory #{parent_dir}, y/n?")
        FileUtils.mkdir_p(parent_dir)
      end

      if File.exist?(target_path)
        return unless confirm?("overwrite local #{target_path}, y/n?")
      end

      storage.pull(handle, version, target_path)
      puts "Pulled #{handle} (version #{info[:version_num]}) to #{target_path}"
    end

    desc "versions HANDLE", "List all versions of a handle (each version has an integer from 1 to n)"
    def versions(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:versions]
        return
      end

      source = Config.current_source
      if source.nil?
        puts "Error: No storage source configured. Run 'filedepot config' to set up."
        return
      end

      storage = Storage::Base.for(source)
      versions_list = storage.versions(handle)
      if versions_list.empty?
        puts "No versions found for handle: #{handle}"
      else
        max_display = 10
        to_show = versions_list.first(max_display)
        to_show.each { |v, date_str| puts date_str.empty? ? v.to_s : "#{v} - #{date_str}" }
        if versions_list.size > max_display
          remaining = versions_list.size - max_display
          puts "... and #{remaining} other ones for a total of #{versions_list.size} versions"
        end
      end
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
      puts "  filedepot push HANDLE FILE    Send file to current storage"
      puts "  filedepot pull HANDLE [--path PATH] [--version N]  Get file from storage"
      puts "  filedepot versions HANDLE     List all versions of a handle"
      puts "  filedepot delete HANDLE [VER] Delete file(s) after confirmation"
      puts ""
      puts "Use 'filedepot help COMMAND' for more information on a command."
    end

    def self.exit_on_failure?
      true
    end

    private

    def confirm?(prompt)
      print "#{prompt} "
      input = $stdin.gets&.strip&.downcase
      input == "y" || input == "yes"
    rescue Interrupt
      puts
      false
    end
  end
end
