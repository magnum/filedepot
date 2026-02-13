# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/local_storage"

class TestPull < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("filedepot_test")
    @source = { "base_path" => @tmpdir }
    @storage = Filedepot::Storage::LocalStorage.new(@source)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if Dir.exist?(@tmpdir)
  end

  def test_pull_gets_latest_version
    handle_dir = File.join(@tmpdir, "testhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "data.txt"), "latest content")

    Dir.chdir(@tmpdir) do
      result = @storage.pull("testhandle")
      expected = File.join(@tmpdir, "data.txt")
      assert_equal File.realpath(expected), File.realpath(result)
      assert File.exist?(result)
      assert_equal "latest content", File.read(result)
    end
  end

  def test_pull_specific_version
    handle_dir = File.join(@tmpdir, "testhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    FileUtils.mkdir_p(File.join(handle_dir, "2"))
    File.write(File.join(handle_dir, "1", "data.txt"), "version 1")
    File.write(File.join(handle_dir, "2", "data.txt"), "version 2")

    Dir.chdir(@tmpdir) do
      result = @storage.pull("testhandle", 1)
      expected = File.join(@tmpdir, "data.txt")
      assert_equal File.realpath(expected), File.realpath(result)
      assert_equal "version 1", File.read(result)
    end
  end

  def test_pull_to_specific_path
    handle_dir = File.join(@tmpdir, "testhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "remote.txt"), "content")

    target = File.join(@tmpdir, "output", "custom.txt")
    FileUtils.mkdir_p(File.dirname(target))

    result = @storage.pull("testhandle", nil, target)
    assert_equal target, result
    assert_equal "content", File.read(target)
  end

  def test_pull_raises_when_no_versions
    error = assert_raises(RuntimeError) do
      @storage.pull("nonexistent")
    end
    assert_match(/No versions found/, error.message)
  end

  def test_pull_raises_when_version_not_found
    handle_dir = File.join(@tmpdir, "testhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "data.txt"), "content")

    error = assert_raises(RuntimeError) do
      @storage.pull("testhandle", 99)
    end
    assert_match(/Version 99 not found/, error.message)
  end

  def test_pull_info_returns_correct_target_path
    handle_dir = File.join(@tmpdir, "testhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "myfile.txt"), "content")

    info = @storage.pull_info("testhandle", nil, "./custom/path/")
    assert_equal "myfile.txt", info[:remote_filename]
    assert_equal 1, info[:version_num]
    assert_equal File.expand_path("./custom/path/myfile.txt"), info[:target_path]
  end
end
