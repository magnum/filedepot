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
      setup: <<~HELP,
        Usage:
          filedepot setup

        Create or reconfigure the config file. Prompts for store name, type, host, username, and base path.
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
      versions: "Usage: filedepot versions HANDLE\n\nList all versions of a handle. Each version has an integer ID from 1 to n.\nTo get the list of handles, use: filedepot handles",
      delete: "Usage: filedepot delete HANDLE [--version N]\n\nAfter confirmation, deletes all versions of a file.\nIf --version N is specified, deletes only that specific version.",
      info: "Usage: filedepot info HANDLE\n\nShow info for a handle: remote base path and current version.",
      handles: "Usage: filedepot handles\n\nList all handles in storage.",
      test: "Usage: filedepot test\n\nRun end-to-end test: push, pull, delete a temporary file.",
      purge: "Usage: filedepot purge HANDLE\n\nShow versions, then prompt how many to keep. Deletes older versions, keeping the newest N."
    }.freeze

    desc "test", "Run end-to-end test (push, pull, delete)"
    def test
      store = check_config
      return unless store

      timestamp = Time.now.to_i
      test_handle = timestamp.to_s
      test_filename = "#{timestamp}.txt"

      File.write(test_filename, Time.now.to_s)
      invoke :push, [test_handle, test_filename]

      File.delete(test_filename)

      invoke :pull, [test_handle]

      invoke :delete, [test_handle], yes: true

      if File.exist?(test_filename)
        File.delete(test_filename)
        puts "Test is OK"
      else
        puts "Test is KO, see the outputs for errors"
      end
    rescue RuntimeError => e
      puts "Test is KO, see the outputs for errors"
      puts "Error: #{e.message}"
    end

    desc "config", "Open the config file using $EDITOR"
    def config
      config_path = Config::CONFIG_PATH
      unless Config.exists?
        puts "Error: No config file. Run 'filedepot setup' first."
        return
      end
      editor = ENV["EDITOR"] || "vim"
      system(editor, config_path)
      return unless confirm?("Run a test? [y/N]")

      invoke :test
    end

    desc "setup", "Create or reconfigure the config file"
    def setup
      store_types = Storage::Base.store_types
      first_type = store_types.keys.first
      defaults = store_types[first_type][:config].transform_keys(&:to_s)

      if Config.exists?
        config = Config.load
        stores = config["stores"] || []
        first_store = stores.first
        if first_store
          defaults["name"] = (first_store["name"] || first_store[:name]).to_s
          defaults["host"] = (first_store["host"] || first_store[:host]).to_s
          defaults["username"] = (first_store["username"] || first_store[:username]).to_s
          defaults["base_path"] = (first_store["base_path"] || first_store[:base_path]).to_s
          defaults["public_base_url"] = (first_store["public_base_url"] || first_store[:public_base_url]).to_s
        end
      end

      puts "Configure storage store (press Enter to accept default)"
      puts ""

      name = prompt_with_default("store name", defaults["name"])
      type = prompt_with_default("Type (#{store_types.keys.join(', ')})", first_type.to_s)
      host = prompt_with_default("Host", defaults["host"])
      username = prompt_with_default("Username", defaults["username"])
      base_path = prompt_with_default("Base path", defaults["base_path"])
      public_base_url = prompt_with_default("Public base URL (optional)", defaults["public_base_url"])

      puts ""
      puts "Store: #{name}"
      puts "  Type: #{type}"
      puts "  Host: #{host}"
      puts "  Username: #{username}"
      puts "  Base path: #{base_path}"
      puts "  Public base URL: #{public_base_url}" unless public_base_url.empty?
      puts ""

      return unless confirm?("Write config? [y/N]")

      store_hash = {
        "name" => name,
        "type" => type,
        "host" => host,
        "username" => username,
        "base_path" => base_path,
        "public_base_url" => (public_base_url.empty? ? nil : public_base_url)
      }.compact

      config = {
        "default_store" => name,
        "stores" => [store_hash]
      }

      FileUtils.mkdir_p(Config::CONFIG_DIR)
      File.write(Config::CONFIG_PATH, config.to_yaml)
      puts "Config written to #{Config::CONFIG_PATH}"

      return unless confirm?("Run a test? [y/N]")

      invoke :test
    end

    desc "push HANDLE FILE", "Send a file to the current storage with a specific handle"
    def push(handle, file_path)
      if handle.to_s.strip.empty?
        puts "Error: Handle is required."
        return
      end
      if file_path.to_s.strip.empty?
        puts "Error: File path is required."
        return
      end
      path = File.expand_path(file_path)
      unless File.file?(path)
        puts "Error: File not found: #{path}"
        return
      end

      store = check_config
      return unless store

      storage = Storage::Base.for(store)
      storage.push(handle, path)
      version = storage.current_version(handle)
      puts "Pushed #{file_path} as #{handle} (version #{version})"
      uploaded_url = storage.url(handle, version, File.basename(path))
      puts uploaded_url if uploaded_url
    rescue RuntimeError => e
      puts "Error: #{e.message}"
    end

    desc "pull HANDLE", "Get file from storage"
    method_option :path, type: :string, desc: "Local path to save the file"
    method_option :version, type: :string, desc: "Version number to pull (default: latest)"
    def pull(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:pull]
        return
      end

      store = check_config
      return unless store

      local_path = options[:path]
      version = (options[:version].nil? || options[:version].empty?) ? nil : options[:version].to_i

      storage = Storage::Base.for(store)
      info = storage.pull_info(handle, version, local_path)
      target_path = info[:target_path]

      puts "Pulling #{handle} (version #{info[:version_num]})"

      parent_dir = File.dirname(target_path)
      unless parent_dir == "." || File.directory?(parent_dir)
        return unless confirm?("create local directory #{parent_dir}, y/n?")
        FileUtils.mkdir_p(parent_dir)
      end

      if File.exist?(target_path)
        return unless confirm?("overwrite local #{target_path}, y/n?")
      end

      storage.pull(handle, version, target_path)
      puts "pulled to #{target_path}"
    rescue RuntimeError => e
      puts "Error: #{e.message}"
    end

    desc "versions HANDLE", "List all versions of a handle (each version has an integer from 1 to n)"
    def versions(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:versions]
        return
      end

      store = check_config
      return unless store

      storage = Storage::Base.for(store)
      versions_list = storage.versions(handle)
      if versions_list.empty?
        puts "Error: Handle '#{handle}' not found."
      else
        puts "version, datetime, size"
        max_display = 10
        to_show = versions_list.first(max_display)
        to_show.each do |v, date_str, size_str|
          parts = [v.to_s, date_str, size_str].reject(&:empty?)
          puts parts.join(", ")
        end
        if versions_list.size > max_display
          remaining = versions_list.size - max_display
          puts "... and #{remaining} other ones for a total of #{versions_list.size} versions"
        end
      end
    end

    desc "info HANDLE", "Show info for a handle"
    def info(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:info]
        return
      end

      store = check_config
      return unless store

      storage = Storage::Base.for(store)
      versions_list = storage.versions(handle)
      if versions_list.empty?
        puts "Error: Handle '#{handle}' not found."
        return
      end

      data = storage.info(handle)

      puts "handle: #{data[:handle]}"
      puts "remote_base_path: #{data[:remote_base_path]}"
      puts "current version: #{data[:current_version]}"
      puts "updated at: #{data[:updated_at]}" if data[:updated_at]
      puts "latest version url: #{data[:latest_version_url]}" if data[:latest_version_url]
    end

    desc "handles", "List all handles in storage"
    def handles
      store = check_config
      return unless store

      storage = Storage::Base.for(store)
      handles_list = storage.handles_data
      if handles_list.empty?
        puts "No handles found."
      else
        puts "name, versions, size"
        handles_list.each do |h|
          puts [h[:handle], h[:versions_count], h[:size]].join(", ")
        end
      end
    end

    desc "purge HANDLE", "Keep only the newest N versions; delete older ones after confirmation"
    def purge(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:purge]
        return
      end

      store = check_config
      return unless store

      storage = Storage::Base.for(store)
      versions_list = storage.versions(handle)
      if versions_list.empty?
        puts "Error: Handle '#{handle}' not found."
        return
      end

      puts "version, datetime, size"
      versions_list.each do |v, date_str, size_str|
        parts = [v.to_s, date_str, size_str].reject(&:empty?)
        puts parts.join(", ")
      end

      total = versions_list.size
      begin
        print "How many versions to keep? [1]: "
        response = $stdin.gets&.strip
      rescue Interrupt
        puts
        return
      end

      keep_str = response.empty? ? "1" : response
      keep_num = keep_str.to_i
      if keep_num < 1 || keep_str != keep_num.to_s
        puts "invalid number of versions"
        return
      end

      versions_to_delete = total - keep_num
      if versions_to_delete <= 0
        puts "Nothing to delete."
        return
      end

      begin
        print "Delete #{versions_to_delete} versions of #{total} total? Type handle name to confirm: "
        input = $stdin.gets&.strip
      rescue Interrupt
        puts
        return
      end

      unless input == handle
        puts "Aborted (handle name did not match)."
        return
      end

      version_nums = versions_list.map(&:first)
      to_delete = version_nums.sort.first(versions_to_delete)
      to_delete.each do |v|
        storage.delete(handle, v)
        puts "Deleted version #{v}"
      end
      puts "Purged #{versions_to_delete} versions of #{handle}"
    rescue RuntimeError => e
      puts "Error: #{e.message}"
    end

    desc "delete HANDLE", "After confirmation, delete all versions of a file; or only a specific version with --version N"
    method_option :version, type: :string, desc: "Delete only this version number"
    method_option :yes, type: :boolean, aliases: "-y", desc: "Skip confirmation (for scripts)"
    def delete(handle = nil)
      if handle.nil?
        puts COMMAND_HELP[:delete]
        return
      end

      store = check_config
      return unless store

      storage = Storage::Base.for(store)
      versions_list = storage.versions(handle)
      if versions_list.empty?
        puts "Error: Handle '#{handle}' not found."
        return
      end
      version = (options[:version].nil? || options[:version].empty?) ? nil : options[:version].to_i
      if version && version > 0
        version_nums = versions_list.map(&:first)
        unless version_nums.include?(version)
          puts "Error: Version #{version} not found for handle '#{handle}'."
          return
        end
      end

      unless options[:yes]
        version_str = version ? " version #{version}" : " all versions"
        puts "This will delete '#{handle}'#{version_str}."
        begin
          print "Type the handle name to confirm: "
          input = $stdin.gets&.strip
        rescue Interrupt
          puts
          return
        end

        unless input == handle
          puts "Aborted (handle name did not match)."
          return
        end
      end

      storage.delete(handle, version)
      puts "Deleted handle '#{handle}'#{version ? " version #{version}" : ""}."
    rescue RuntimeError => e
      puts "Error: #{e.message}"
    end

    default_task :default

    desc "default", "Show current store and list of available commands"
    def default
      config = Config.load
      if config.nil?
        puts "Error: No storage store configured. Run 'filedepot setup' to set up."
        return
      end

      store = Config.current_store
      if store
        puts "Current store:"
        type_str = store["type"] ? store["type"] : "unknown"
        puts "#{store.to_yaml}"
      end
      puts ""
      puts "Available commands:"
      puts "filedepot setup               Create or reconfigure config"
      puts "filedepot config              Open config file using $EDITOR"
      puts "filedepot test                Run end-to-end test"
      puts "filedepot info HANDLE         Show info for a handle"
      puts "filedepot handles             List all handles in storage"
      puts "filedepot versions HANDLE     List all versions of a handle"
      puts "filedepot push HANDLE FILE    Send file to current storage"
      puts "filedepot pull HANDLE [--path PATH] [--version N]  Get file from storage"
      puts "filedepot delete HANDLE [--version N] Delete file(s) after confirmation"
      puts "filedepot purge HANDLE           Keep newest N versions, delete older"
      puts ""
      puts "Use 'filedepot help COMMAND' for more information on a command."
    end

    def self.exit_on_failure?
      true
    end

    private

    def prompt_with_default(label, default)
      default_str = default.to_s
      prompt = default_str.empty? ? "#{label}: " : "#{label} [#{default_str}]: "
      print prompt
      input = $stdin.gets&.strip
      input.empty? ? default_str : input
    rescue Interrupt
      puts
      exit 1
    end

    def check_config
      store = Config.current_store
      if store.nil?
        puts "Error: No storage store configured. Run 'filedepot setup' to set up."
        return nil
      end
      store
    end

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
