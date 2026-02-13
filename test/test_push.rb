# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/local_storage"

class TestPush < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("filedepot_test")
    @source = { "base_path" => @tmpdir }
    @storage = Filedepot::Storage::LocalStorage.new(@source)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if Dir.exist?(@tmpdir)
  end

  def test_push_creates_version_directory
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "hello world")

    @storage.push("myhandle", test_file)

    version_dir = File.join(@tmpdir, "myhandle", "1")
    assert Dir.exist?(version_dir), "Version directory should exist"
    assert File.exist?(File.join(version_dir, "testfile.txt")), "File should be copied"
    assert_equal "hello world", File.read(File.join(version_dir, "testfile.txt"))
  end

  def test_push_increments_version
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "v1")

    @storage.push("handle", test_file)
    File.write(test_file, "v2")
    @storage.push("handle", test_file)
    File.write(test_file, "v3")
    @storage.push("handle", test_file)

    assert_equal [3, 2, 1], @storage.versions("handle").map(&:first)
    assert_equal "v3", File.read(File.join(@tmpdir, "handle", "3", "testfile.txt"))
    assert_equal "v2", File.read(File.join(@tmpdir, "handle", "2", "testfile.txt"))
    assert_equal "v1", File.read(File.join(@tmpdir, "handle", "1", "testfile.txt"))
  end

  def test_push_raises_when_file_not_found
    error = assert_raises(RuntimeError) do
      @storage.push("handle", "/nonexistent/file.txt")
    end
    assert_match(/File not found/, error.message)
  end
end
