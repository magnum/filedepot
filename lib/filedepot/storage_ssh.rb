# frozen_string_literal: true

require "shellwords"
require "net/ssh"
require "net/scp"

module Filedepot
  module Storage
    class SshStorage < Base
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

      def push(handle)
        local_path = File.expand_path(handle)
        raise "File not found: #{handle}" unless File.file?(local_path)

        ssh_session do |ssh|
          remote_dir = remote_handle_path(handle)
          ssh.exec!("mkdir -p #{shell_escape(remote_dir)}")

          next_version = next_version_for(ssh, handle)
          remote_file = File.join(remote_dir, next_version.to_s)

          ssh.scp.upload!(local_path, remote_file)
        end
      end

      def pull(handle, version = nil)
        ssh_session do |ssh|
          versions_list = versions_for(ssh, handle)
          raise "No versions found for handle: #{handle}" if versions_list.empty?

          version_num = version ? version.to_i : versions_list.max
          raise "Version #{version} not found" unless versions_list.include?(version_num)

          remote_file = File.join(remote_handle_path(handle), version_num.to_s)
          local_filename = File.basename(handle)
          local_path = File.join(Dir.pwd, local_filename)

          ssh.scp.download!(remote_file, local_path)
          local_path
        end
      end

      def versions(handle)
        ssh_session do |ssh|
          versions_for(ssh, handle).sort
        end
      end

      def delete(handle, version = nil)
        ssh_session do |ssh|
          remote_dir = remote_handle_path(handle)

          if version
            remote_file = File.join(remote_dir, version.to_s)
            ssh.exec!("rm -f #{shell_escape(remote_file)}")
            # Check if dir is empty and remove it
            versions_remaining = versions_for(ssh, handle)
            ssh.exec!("rm -rf #{shell_escape(remote_dir)}") if versions_remaining.empty?
          else
            ssh.exec!("rm -rf #{shell_escape(remote_dir)}")
          end
        end
      end

      private

      def remote_base_path
        @source["base_path"] || "/tmp/filedepot"
      end

      def remote_handle_path(handle)
        safe_handle = handle.to_s.gsub(%r{[^\w\-./]}, "_")
        File.join(remote_base_path, safe_handle)
      end

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
        return [] if result.nil? || result.strip.empty?

        result.strip.split("\n").map(&:to_i).select { |v| v.positive? }
      end

      def next_version_for(ssh, handle)
        versions = versions_for(ssh, handle)
        versions.empty? ? 1 : versions.max + 1
      end
    end
  end
end
