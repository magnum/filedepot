# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/local_storage"

class TestDelete < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("filedepot_test")
    @store = { "base_path" => @tmpdir }
    @storage = Filedepot::Storage::LocalStorage.new(@store)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if Dir.exist?(@tmpdir)
  end

  def test_delete_all_versions
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "content")
    @storage.push("myhandle", test_file)
    @storage.push("myhandle", test_file)
    @storage.push("myhandle", test_file)

    handle_dir = File.join(@tmpdir, "myhandle")
    assert Dir.exist?(handle_dir), "Handle directory should exist before delete"
    assert_equal [3, 2, 1], @storage.versions("myhandle").map(&:first)

    @storage.delete("myhandle")

    refute Dir.exist?(handle_dir), "Handle directory should be removed"
    assert @storage.versions("myhandle").empty?
  end

  def test_delete_specific_version
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "v1")
    @storage.push("handle", test_file)
    File.write(test_file, "v2")
    @storage.push("handle", test_file)
    File.write(test_file, "v3")
    @storage.push("handle", test_file)

    @storage.delete("handle", 2)

    assert_equal [3, 1], @storage.versions("handle").map(&:first)
    assert_equal "v3", File.read(File.join(@tmpdir, "handle", "3", "testfile.txt"))
    assert_equal "v1", File.read(File.join(@tmpdir, "handle", "1", "testfile.txt"))
    refute Dir.exist?(File.join(@tmpdir, "handle", "2"))
  end

  def test_delete_last_version_removes_handle_directory
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "content")
    @storage.push("single", test_file)

    handle_dir = File.join(@tmpdir, "single")
    assert Dir.exist?(handle_dir)

    @storage.delete("single", 1)

    refute Dir.exist?(handle_dir), "Empty handle directory should be removed"
  end

  def test_delete_nonexistent_handle_does_not_raise
    @storage.delete("nonexistent")
    # rm_rf on nonexistent path is a no-op
  end

  def test_delete_nonexistent_version_does_not_raise
    test_file = File.join(@tmpdir, "testfile.txt")
    File.write(test_file, "content")
    @storage.push("handle", test_file)

    @storage.delete("handle", 99)
    # Version 1 should still exist
    assert_equal [1], @storage.versions("handle").map(&:first)
  end
end
