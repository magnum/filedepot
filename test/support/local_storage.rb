# frozen_string_literal: true

require "shellwords"

# Local filesystem storage for testing - mirrors Ssh structure
# without requiring SSH. Uses base_path/handle/1/, base_path/handle/2/, etc.
module Filedepot
  module Storage
    class LocalStorage < Base
      def test
        FileUtils.mkdir_p(remote_base_path)
      end

      def ls
        handles_data.map { |h| h[:handle] }
      end

      def handles_data
        return [] unless Dir.exist?(remote_base_path)

        handle_names = Dir.children(remote_base_path).select { |c| File.directory?(File.join(remote_base_path, c)) }
        handle_names.map do |name|
          handle_dir = File.join(remote_base_path, name)
          versions_list = versions_for(name)
          size_str = du_size(handle_dir)
          { handle: name, versions_count: versions_list.size, size: size_str }
        end
      end

      def push(handle, local_path)
        path = File.expand_path(local_path)
        raise "File not found: #{path}" unless File.file?(path)

        push_path = next_version_path(handle)
        FileUtils.mkdir_p(push_path)
        FileUtils.cp(path, File.join(push_path, File.basename(path)))
      end

      def pull(handle, version = nil, local_path = nil)
        versions_list = versions_for(handle)
        raise "Handle '#{handle}' not found" if versions_list.empty?

        version_num = version ? version.to_i : versions_list.max
        raise "Version #{version} not found for handle '#{handle}'" unless versions_list.include?(version_num)

        version_dir = File.join(remote_handle_path(handle), version_num.to_s)
        remote_file = first_file_in_dir(version_dir)
        raise "No file found in version #{version_num} for handle '#{handle}'" if remote_file.nil?

        remote_filename = File.basename(remote_file)
        target_path = resolve_local_path(local_path, remote_filename)
        FileUtils.cp(remote_file, target_path)
        target_path
      end

      def pull_info(handle, version = nil, local_path = nil)
        versions_list = versions_for(handle)
        raise "Handle '#{handle}' not found" if versions_list.empty?

        version_num = version ? version.to_i : versions_list.max
        raise "Version #{version} not found for handle '#{handle}'" unless versions_list.include?(version_num)

        version_dir = File.join(remote_handle_path(handle), version_num.to_s)
        remote_file = first_file_in_dir(version_dir)
        raise "No file found in version #{version_num} for handle '#{handle}'" if remote_file.nil?

        remote_filename = File.basename(remote_file)
        target_path = resolve_local_path(local_path, remote_filename)

        { remote_filename: remote_filename, version_num: version_num, target_path: target_path }
      end

      def current_version_path(handle)
        handle_dir = remote_handle_path(handle)
        FileUtils.mkdir_p(handle_dir)

        versions_list = versions_for(handle)
        return nil if versions_list.empty?

        File.join(handle_dir, versions_list.max.to_s)
      end

      def versions_data(handle)
        versions_list = versions_for(handle).sort.reverse
        versions_list.map do |v|
          version_dir = File.join(remote_handle_path(handle), v.to_s)
          remote_file = first_file_in_dir(version_dir)
          mtime = remote_file ? File.mtime(remote_file) : nil
          filename = remote_file ? File.basename(remote_file) : nil
          size_str = du_size(version_dir)
          {
            version: v,
            datetime: mtime,
            path: remote_file || version_dir,
            handle: handle,
            filename: filename,
            url: url(handle, v, filename),
            size: size_str
          }
        end
      end

      def versions(handle)
        versions_data(handle).map { |d| [d[:version], d[:datetime] ? d[:datetime].to_s : "", d[:size] || ""] }
      end

      def delete(handle, version = nil)
        handle_dir = remote_handle_path(handle)

        if version
          version_dir = File.join(handle_dir, version.to_s)
          FileUtils.rm_rf(version_dir)
          FileUtils.rmdir(handle_dir) if Dir.exist?(handle_dir) && Dir.empty?(handle_dir)
        else
          FileUtils.rm_rf(handle_dir)
        end
      end

      def resolve_local_path(local_path_param, remote_filename)
        if local_path_param.nil? || local_path_param.empty?
          File.join(Dir.pwd, remote_filename)
        elsif local_path_param.end_with?("/") || (File.exist?(local_path_param) && File.directory?(local_path_param))
          File.join(File.expand_path(local_path_param), remote_filename)
        else
          File.expand_path(local_path_param)
        end
      end

      private

      def versions_for(handle)
        handle_dir = remote_handle_path(handle)
        return [] unless Dir.exist?(handle_dir)

        Dir.children(handle_dir).map(&:to_i).select { |v| v.positive? }
      end

      def first_file_in_dir(dir)
        return nil unless Dir.exist?(dir)

        first = Dir.children(dir).first
        first ? File.join(dir, first) : nil
      end

      def du_size(path)
        return "" unless Dir.exist?(path)

        result = `du -sh #{Shellwords.escape(path)} 2>/dev/null`.strip
        result.split(/\s+/).first || ""
      end
    end
  end
end
