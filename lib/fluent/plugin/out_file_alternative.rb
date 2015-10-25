require 'fluent/mixin/plaintextformatter'

class Fluent::FileAlternativeOutput < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('file_alternative', self)

  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  SUPPORTED_COMPRESS = {
    :gz => :gz,
    :gzip => :gz,
  }

  config_set_default :time_slice_format, '%Y%m%d' # %Y%m%d%H

  config_param :path, :string  # /path/pattern/to/hdfs/file can use %Y %m %d %H %M %S

  config_param :compress, :default => nil do |val|
    c = SUPPORTED_COMPRESS[val.to_sym]
    unless c
      raise ConfigError, "Unsupported compression algorithm '#{compress}'"
    end
    c
  end

  config_param :symlink_path, :string, :default => nil

  config_param :dir_mode, :string, :default => '0777'

  config_param :enable_chmod, :bool, :default => true

  include Fluent::Mixin::PlainTextFormatter

  def initialize
    super
    require 'time'
    require 'zlib'
  end

  def configure(conf)
    if conf['path']
      if conf['path'].index('%S')
        conf['time_slice_format'] = '%Y%m%d%H%M%S'
      elsif conf['path'].index('%M')
        conf['time_slice_format'] = '%Y%m%d%H%M'
      elsif conf['path'].index('%H')
        conf['time_slice_format'] = '%Y%m%d%H'
      end
    end
    if pos = (conf['path'] || '').index('*')
      @path_prefix = conf['path'][0,pos]
      @path_suffix = conf['path'][pos+1..-1]
      conf['buffer_path'] ||= "#{conf['path']}"
    elsif (conf['path'] || '%Y') !~ /%Y|%m|%d|%H|%M|%S/
      if conf['path'] =~ /\.log\Z/
        @path_prefix = conf['path'][0..-4]
        @path_suffix = ".log"
      else
        @path_prefix = conf['path'] + "."
        @path_suffix = ".log"
      end
      conf['buffer_path'] ||= "#{conf['path']}.*"
    elsif (conf['path'] || '') =~ /%Y|%m|%d|%H|%M|%S/
      conf['buffer_path'] ||= conf['path'].gsub('%Y','yyyy').gsub('%m','mm').gsub('%d','dd').gsub('%H','HH').gsub('%M','MM').gsub('%S','SS')
    end

    super

    unless @path.index('/') == 0
      raise Fluent::ConfigError, "Path on filesystem MUST starts with '/', but '#{@path}'"
    end

    if @symlink_path
      unless @symlink_path.index('/') == 0
        raise Fluent::ConfigError, "Symlink path on filesystem MUST starts with '/', but '#{@symlink_path}'"
      end
      @buffer.symlink_path = @symlink_path
    end
  end

  def start
    super
    # init
  end

  def shutdown
    super
    # destroy
  end

  def record_to_string(record)
    record.to_json
  end

  # def format(tag, time, record)
  # end

  def path_format(chunk_key)
    suffix = case @compress
             when :gz
               '.gz'
             else
               ''
             end
    if @path_prefix and @path_suffix
      if @compress
        i = 0
        begin
          path = "#{@path_prefix}#{chunk_key}_#{i}#{@path_suffix}#{suffix}"
          i += 1
        end while File.exist?(path)
        path
      else
        "#{@path_prefix}#{chunk_key}#{@path_suffix}#{suffix}"
      end
    else
      if @compress
        path_base = Time.strptime(chunk_key, @time_slice_format).strftime(@path)
        path = path_base + suffix
        if File.exist?(path)
          i = 0
          begin
            path = "#{path_base}.#{i}#{suffix}"
            i += 1
          end while File.exist?(path)
        end
        path
      else
        Time.strptime(chunk_key, @time_slice_format).strftime(@path)
      end
    end
  end

  def write(chunk)
    path = path_format(chunk.key)

    begin
      require 'pathname'

      Pathname.new(path).descend {|p|
        FileUtils.mkdir_p( File.dirname(p)) unless File.directory?(p)
        if @enable_chmod
          FileUtils.chmod @dir_mode.to_i(8), File.dirname(p) unless File.directory?(p)
        end
      }

      case @compress
      when :gz
        Zlib::GzipWriter.open(path) {|f|
          chunk.write_to(f)
        }
      else
        File.open(path, "a") {|f|
          chunk.write_to(f)
        }
      end
    rescue
      log.error "failed to write data: path #{path}"
      raise
    end
    path
  end
end
