# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/local_storage"

class TestVersionsData < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("filedepot_test")
    @store = { "base_path" => @tmpdir }
    @storage = Filedepot::Storage::LocalStorage.new(@store)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if Dir.exist?(@tmpdir)
  end

  def test_versions_data_includes_handle_filename_path
    handle_dir = File.join(@tmpdir, "myhandle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "doc.pdf"), "content")

    data = @storage.versions_data("myhandle")

    assert_equal 1, data.size
    assert_equal "myhandle", data.first[:handle]
    assert_equal 1, data.first[:version]
    assert_equal "doc.pdf", data.first[:filename]
    assert_includes data.first[:path], "doc.pdf"
    assert data.first[:datetime].is_a?(Time)
  end

  def test_versions_data_url_when_public_base_path_set
    @store["public_base_path"] = "https://example.com/files"
    storage = Filedepot::Storage::LocalStorage.new(@store)

    handle_dir = File.join(@tmpdir, "test")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "file.txt"), "content")

    data = storage.versions_data("test")

    assert_equal "https://example.com/files/test/1/file.txt", data.first[:url]
  end

  def test_versions_data_url_nil_without_public_base_path
    handle_dir = File.join(@tmpdir, "test")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "file.txt"), "content")

    data = @storage.versions_data("test")

    assert_nil data.first[:url]
  end

  def test_info_includes_updated_at_and_url
    @store["public_base_path"] = "https://example.com/files"
    storage = Filedepot::Storage::LocalStorage.new(@store)

    handle_dir = File.join(@tmpdir, "info_handle")
    FileUtils.mkdir_p(File.join(handle_dir, "1"))
    File.write(File.join(handle_dir, "1", "data.txt"), "content")

    info = storage.info("info_handle")

    assert_equal "info_handle", info[:handle]
    assert_equal @tmpdir, info[:remote_base_path]
    assert_equal 1, info[:current_version]
    assert info[:updated_at].is_a?(Time)
    assert_equal "https://example.com/files/info_handle/1/data.txt", info[:latest_version_url]
  end
end
