# frozen_string_literal: true

require "shellwords"
require "net/ssh"
require "net/scp"

module Filedepot
  module Storage
    class Ssh < Base
      def test
        ssh_session do |ssh|
          result = ssh.exec!("echo ok")
          raise "Connection failed" unless result&.include?("ok")
        end
      end

      def ls
        handles = []
        ssh_session do |ssh|
          result = ssh.exec!("ls -1 #{shell_escape(remote_base_path)} 2>/dev/null || true")
          return [] if result.nil? || result.strip.empty?

          handles = result.strip.split("\n").select { |line| !line.empty? }
        end
        handles
      end

      def push(handle, local_path)
        path = File.expand_path(local_path)
        raise "File not found: #{path}" unless File.file?(path)

        push_path = next_version_path(handle)

        ssh_session do |ssh|
          ssh.exec!("mkdir -p #{shell_escape(push_path)}")
          # Upload to directory - SCP places file with original name inside
          ssh.scp.upload!(path, push_path)
        end
      end

      def current_version_path(handle)
        ssh_session do |ssh|
          handle_dir = remote_handle_path(handle)
          ssh.exec!("mkdir -p #{shell_escape(handle_dir)}")

          result = ssh.exec!("ls -1 #{shell_escape(handle_dir)} 2>/dev/null || true")
          versions = parse_versions(result)

          if versions.empty?
            nil
          else
            File.join(handle_dir, versions.max.to_s)
          end
        end
      end

      def pull(handle, version = nil, local_path = nil)
        ssh_session do |ssh|
          versions_list = versions_for(ssh, handle)
          raise "Handle '#{handle}' not found" if versions_list.empty?

          version_num = version ? version.to_i : versions_list.max
          raise "Version #{version} not found for handle '#{handle}'" unless versions_list.include?(version_num)

          version_dir = File.join(remote_handle_path(handle), version_num.to_s)
          remote_file = first_file_in_dir(ssh, version_dir)
          raise "No file found in version #{version_num} for handle '#{handle}'" if remote_file.nil?

          remote_filename = File.basename(remote_file)
          target_path = resolve_local_path(local_path, remote_filename)

          ssh.scp.download!(remote_file, target_path)
          target_path
        end
      end

      def pull_info(handle, version = nil, local_path = nil)
        ssh_session do |ssh|
          versions_list = versions_for(ssh, handle)
          raise "Handle '#{handle}' not found" if versions_list.empty?

          version_num = version ? version.to_i : versions_list.max
          raise "Version #{version} not found for handle '#{handle}'" unless versions_list.include?(version_num)

          version_dir = File.join(remote_handle_path(handle), version_num.to_s)
          remote_file = first_file_in_dir(ssh, version_dir)
          raise "No file found in version #{version_num} for handle '#{handle}'" if remote_file.nil?

          remote_filename = File.basename(remote_file)
          target_path = resolve_local_path(local_path, remote_filename)

          { remote_filename: remote_filename, version_num: version_num, target_path: target_path }
        end
      end

      def versions_data(handle)
        ssh_session do |ssh|
          versions_list = versions_for(ssh, handle).sort.reverse
          versions_list.map do |v|
            version_dir = File.join(remote_handle_path(handle), v.to_s)
            epoch = stat_mtime(ssh, version_dir)
            remote_file = first_file_in_dir(ssh, version_dir)
            path = remote_file || version_dir
            filename = remote_file ? File.basename(remote_file) : nil
            {
              version: v,
              datetime: epoch ? Time.at(epoch) : nil,
              path: path,
              handle: handle,
              filename: filename,
              url: url(handle, v, filename)
            }
          end
        end
      end

      def versions(handle)
        versions_data(handle).map { |d| [d[:version], d[:datetime] ? d[:datetime].to_s : ""] }
      end

      def delete(handle, version = nil)
        ssh_session do |ssh|
          handle_dir = remote_handle_path(handle)

          if version
            version_dir = File.join(handle_dir, version.to_s)
            ssh.exec!("rm -rf #{shell_escape(version_dir)}")
            versions_remaining = versions_for(ssh, handle)
            ssh.exec!("rmdir #{shell_escape(handle_dir)} 2>/dev/null || true") if versions_remaining.empty?
          else
            ssh.exec!("rm -rf #{shell_escape(handle_dir)}")
          end
        end
      end

      private

      def shell_escape(path)
        Shellwords.shellescape(path.to_s)
      end

      def ssh_session
        host = @source["host"] || "localhost"
        user = @source["username"].to_s.strip
        user = ENV["USER"] if user.empty?

        Net::SSH.start(host, user) do |ssh|
          yield ssh
        end
      end

      def versions_for(ssh, handle)
        remote_dir = remote_handle_path(handle)
        result = ssh.exec!("ls -1 #{shell_escape(remote_dir)} 2>/dev/null || true")
        parse_versions(result)
      end

      def parse_versions(ls_result)
        return [] if ls_result.nil? || ls_result.strip.empty?

        ls_result.strip.split("\n").map(&:to_i).select { |v| v.positive? }
      end

      def first_file_in_dir(ssh, dir)
        result = ssh.exec!("ls -1 #{shell_escape(dir)} 2>/dev/null || true")
        return nil if result.nil? || result.strip.empty?

        first = result.strip.split("\n").first
        first ? File.join(dir, first) : nil
      end

      def stat_mtime(ssh, path)
        # Linux: stat -c %Y; macOS: stat -f %m
        result = ssh.exec!("stat -c %Y #{shell_escape(path)} 2>/dev/null || stat -f %m #{shell_escape(path)} 2>/dev/null")
        result&.strip&.to_i
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
    end
  end
end
