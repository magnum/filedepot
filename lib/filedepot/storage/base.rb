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

      def test
        raise "not implemented"
      end

      def ls
        raise "not implemented"
      end

      def push(handle)
        raise "not implemented"
      end

      def pull(handle, version = nil)
        raise "not implemented"
      end

      def versions(handle)
        raise "not implemented"
      end

      def delete(handle, version = nil)
        raise "not implemented"
      end
    end
  end
end
