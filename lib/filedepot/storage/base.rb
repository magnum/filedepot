# frozen_string_literal: true

module Filedepot
  module Storage
    class Base
      def self.for(source)
        if source["ssh"]
          SshStorage.new(source)
        else
          raise ArgumentError, "Unknown storage type for source: #{source["name"]}"
        end
      end

      def initialize(source)
        @source = source
      end

      def current_version(handle)
        path = current_version_path(handle)
        path.nil? || path.to_s.empty? ? 0 : File.basename(path).to_i
      end

      def next_version(handle)
        current_version(handle) + 1
      end

      def next_version_path(handle)
        File.join(remote_handle_path(handle), next_version(handle).to_s)
      end

      def current_version_path(handle)
        raise "not implemented"
      end

      def test
        raise "not implemented"
      end

      def ls
        raise "not implemented"
      end

      def push(handle, local_path)
        raise "not implemented"
      end

      def pull(handle, version = nil, local_path = nil)
        raise "not implemented"
      end

      def versions(handle)
        raise "not implemented"
      end

      def delete(handle, version = nil)
        raise "not implemented"
      end

      protected

      def remote_base_path
        @source["base_path"] || "/tmp/filedepot"
      end

      def remote_handle_path(handle)
        safe_handle = handle.to_s.gsub(%r{[^\w\-./]}, "_")
        File.join(remote_base_path, safe_handle)
      end
    end
  end
end
