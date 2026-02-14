# frozen_string_literal: true

require_relative "test_helper"

class TestStoreTypes < Minitest::Test
  def test_store_types_returns_ssh_config
    store_types = Filedepot::Storage::Base.store_types

    assert store_types.key?(:ssh)
    assert store_types[:ssh].key?(:config)

    config = store_types[:ssh][:config]
    assert_equal "test", config["name"]
    assert_equal "ssh", config["type"]
    assert_equal "127.0.0.1", config["host"]
    assert config.key?("username")
    assert config.key?("base_path")
    assert config.key?("public_base_url")
  end

  def test_store_types_first_is_ssh
    store_types = Filedepot::Storage::Base.store_types
    first_type = store_types.keys.first

    assert_equal :ssh, first_type
  end
end
