# frozen_string_literal: true

require "filedepot/version"
require "filedepot/config"
require "filedepot/storage/base"
require "filedepot/storage_ssh"
require "filedepot/cli"

module Filedepot
  class Error < StandardError; end
end
