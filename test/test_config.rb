# frozen_string_literal: true

require_relative "test_helper"

class TestConfig < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("filedepot_config_test")
    @config_dir = File.join(@tmpdir, ".filedepot")
    @config_path = File.join(@config_dir, "config.yml")
    FileUtils.mkdir_p(@config_dir)

    @original_config_path = Filedepot::Config::CONFIG_PATH
    Filedepot::Config.send(:remove_const, :CONFIG_PATH)
    Filedepot::Config.const_set(:CONFIG_PATH, @config_path)
  end

  def teardown
    Filedepot::Config.send(:remove_const, :CONFIG_PATH)
    Filedepot::Config.const_set(:CONFIG_PATH, @original_config_path)
    FileUtils.rm_rf(@tmpdir) if Dir.exist?(@tmpdir)
  end

  def test_exists_returns_false_for_nonexistent_path
    File.delete(@config_path) if File.exist?(@config_path)
    refute Filedepot::Config.exists?
  end

  def test_exists_returns_true_when_file_exists
    File.write(@config_path, "default_store: test\nstores: []\n")
    assert Filedepot::Config.exists?
  end

  def test_load_returns_nil_when_file_does_not_exist
    File.delete(@config_path) if File.exist?(@config_path)
    assert_nil Filedepot::Config.load
  end

  def test_load_returns_parsed_config_when_file_exists
    File.write(@config_path, <<~YAML)
      default_store: test
      stores:
        - name: test
          type: ssh
          host: 127.0.0.1
          base_path: /tmp/filedepot
    YAML

    config = Filedepot::Config.load
    assert config
    assert_equal "test", config["default_store"]
    assert_equal 1, config["stores"].size
    assert_equal "test", config["stores"].first["name"]
    assert_equal "ssh", config["stores"].first["type"]
  end
end
