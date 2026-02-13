# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/local_storage"

class TestInfo < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("filedepot_test")
    @source = { "base_path" => @tmpdir }
    @storage = Filedepot::Storage::LocalStorage.new(@source)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if Dir.exist?(@tmpdir)
  end

  def test_info_returns_handle_remote_base_path_and_current_version
    handle_dir = File.join(@tmpdir, "myhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "file.txt"), "content")

    info = @storage.info("myhandle")

    assert_equal "myhandle", info[:handle]
    assert_equal @tmpdir, info[:remote_base_path]
    assert_equal 1, info[:current_version]
  end

  def test_info_includes_updated_at
    handle_dir = File.join(@tmpdir, "handle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "data.txt"), "content")

    info = @storage.info("handle")

    assert info[:updated_at].is_a?(Time)
  end

  def test_info_includes_latest_version_url_when_public_base_path_set
    @source["public_base_path"] = "https://example.com/files"
    storage = Filedepot::Storage::LocalStorage.new(@source)

    handle_dir = File.join(@tmpdir, "handle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "doc.pdf"), "content")

    info = storage.info("handle")

    assert_equal "https://example.com/files/handle/1/doc.pdf", info[:latest_version_url]
  end

  def test_info_latest_version_url_nil_without_public_base_path
    handle_dir = File.join(@tmpdir, "handle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "file.txt"), "content")

    info = @storage.info("handle")

    assert_nil info[:latest_version_url]
  end

  def test_info_current_version_is_latest_with_multiple_versions
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "v1")
    @storage.push("handle", test_file)
    File.write(test_file, "v2")
    @storage.push("handle", test_file)
    File.write(test_file, "v3")
    @storage.push("handle", test_file)

    info = @storage.info("handle")

    assert_equal 3, info[:current_version]
  end

  def test_info_with_empty_handle
    info = @storage.info("nonexistent")

    assert_equal "nonexistent", info[:handle]
    assert_equal @tmpdir, info[:remote_base_path]
    assert_equal 0, info[:current_version]
    assert_nil info[:updated_at]
    assert_nil info[:latest_version_url]
  end
end
