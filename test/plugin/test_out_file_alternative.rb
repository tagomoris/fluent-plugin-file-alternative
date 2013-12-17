require 'helper'

class FileAlternativeOutputTest < Test::Unit::TestCase
  TMP_DIR = File.dirname(__FILE__) + "/../tmp"

  CONFIG = %[
    path #{TMP_DIR}/accesslog.%Y-%m-%d
    compress gz
  ]

  SYMLINK_PATH = File.expand_path("#{TMP_DIR}/current")

  def setup
    Fluent::Test.setup
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
  end

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::TimeSlicedOutputTestDriver.new(Fluent::FileAlternativeOutput, tag).configure(conf)
  end

  # config_param :output_data_type, :string, :default => 'json' # or 'attr:field' or 'attr:field1,field2,field3(...)'

  # path
  # output_include_time , output_include_tag , output_data_type
  # add_newline , field_separator
  # remove_prefix , :default_tag
  def test_configure
    # many many many tests should be written, for PlainTextFormatterMixin ...

    d = create_driver %[
      path #{TMP_DIR}/accesslog.%Y-%m-%d-%H-%M-%S
    ]
    assert_equal '%Y%m%d%H%M%S', d.instance.time_slice_format
    assert_nil d.instance.compress
    assert_equal true, d.instance.output_include_time
    assert_equal true, d.instance.output_include_tag
    assert_equal 'json', d.instance.output_data_type
    assert_equal true, d.instance.add_newline
    assert_equal "TAB", d.instance.field_separator
    assert_nil d.instance.remove_prefix
  end

  def test_format
    d1 = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d1.emit({"a"=>1}, time)
    d1.emit({"a"=>2}, time)
    d1.expect_format %[2011-01-02T13:14:15Z\ttest\t{"a":1}\n]
    d1.expect_format %[2011-01-02T13:14:15Z\ttest\t{"a":2}\n]
    d1.run

    dx = create_driver(CONFIG + %[
      time_format %Y-%m-%d %H-%M-%S
    ])

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    dx.emit({"a"=>1}, time)
    dx.emit({"a"=>2}, time)
    dx.expect_format %[2011-01-02 13-14-15\ttest\t{"a":1}\n]
    dx.expect_format %[2011-01-02 13-14-15\ttest\t{"a":2}\n]
    dx.run

    d2 = create_driver %[
      path #{TMP_DIR}/accesslog.%Y-%m-%d-%H-%M-%S
      output_include_time false
      output_include_tag false
      output_data_type attr:message
    ]
    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d2.emit({"message" => "abc-xyz-123", "other" => "zzz"}, time)
    d2.emit({"message" => "123-456-789", "other" => "ppp"}, time)
    d2.expect_format %[abc-xyz-123\n]
    d2.expect_format %[123-456-789\n]
    d2.run

    d3 = create_driver %[
      path #{TMP_DIR}/accesslog.%Y-%m-%d-%H-%M-%S
      output_include_time false
      output_include_tag false
      output_data_type attr:server,level,log
      field_separator COMMA
      add_newline false
    ]
    assert_equal ',', d3.instance.f_separator

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d3.emit({"server" => "www01", "level" => "warn", "log" => "Exception\n"}, time)
    d3.emit({"server" => "app01", "level" => "info", "log" => "Send response\n"}, time)
    d3.expect_format %[www01,warn,Exception\n]
    d3.expect_format %[app01,info,Send response\n]
    d3.run
  end

  def test_write
    d2 = create_driver %[
      path #{TMP_DIR}/accesslog.%Y-%m-%d-%H-%M-%S
      output_include_time false
      output_include_tag false
      output_data_type attr:message
      utc
    ]
    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d2.emit({"message" => "abc-xyz-123", "other" => "zzz"}, time)
    d2.emit({"message" => "123-456-789", "other" => "ppp"}, time)
    d2.expect_format %[abc-xyz-123\n]
    d2.expect_format %[123-456-789\n]
    path = d2.run
    assert_equal "#{TMP_DIR}/accesslog.2011-01-02-13-14-15", path[0]
    
    d3 = create_driver %[
      path #{TMP_DIR}/accesslog.%Y-%m-%d-%H-%M-%S
      compress gzip
      output_include_time false
      output_include_tag false
      output_data_type attr:server,level,log
      field_separator COMMA
      add_newline false
      utc
    ]
    assert_equal ',', d3.instance.f_separator

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d3.emit({"server" => "www01", "level" => "warn", "log" => "Exception\n"}, time)
    d3.emit({"server" => "app01", "level" => "info", "log" => "Send response\n"}, time)
    d3.expect_format %[www01,warn,Exception\n]
    d3.expect_format %[app01,info,Send response\n]
    path = d3.run
    assert_equal "#{TMP_DIR}/accesslog.2011-01-02-13-14-15.gz", path[0]
  end

  def test_write_with_symlink
    conf = CONFIG + %[
      symlink_path #{SYMLINK_PATH}
    ]
    symlink_path = "#{SYMLINK_PATH}"

    Fluent::FileBuffer.clear_buffer_paths
    d = Fluent::Test::TestDriver.new(Fluent::FileOutput).configure(conf)

    begin
      d.instance.start
      10.times { sleep 0.05 }
      time = Time.parse("2011-01-02 13:14:15 UTC").to_i
      es = Fluent::OneEventStream.new(time, {"a"=>1})
      d.instance.emit('tag', es, Fluent::NullOutputChain.instance)

      assert File.exists?(symlink_path)
      assert File.symlink?(symlink_path)

      d.instance.enqueue_buffer

      assert !File.exists?(symlink_path)
      assert File.symlink?(symlink_path)
    ensure
      d.instance.shutdown
      FileUtils.rm_rf(symlink_path)
    end
  end
end
