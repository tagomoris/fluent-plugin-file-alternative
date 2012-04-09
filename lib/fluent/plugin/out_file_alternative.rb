module FluentExt; end
module FluentExt::PlainTextFormatterMixin
  # config_param :output_data_type, :string, :default => 'json' # or 'attr:field' or 'attr:field1,field2,field3(...)'

  attr_accessor :output_include_time, :output_include_tag, :output_data_type
  attr_accessor :add_newline, :field_separator
  attr_accessor :remove_prefix, :default_tag
  
  attr_accessor :f_separator

  def configure(conf)
    super

    @output_include_time = Fluent::Config.bool_value(conf['output_include_time'])
    @output_include_time = true if @output_include_time.nil?

    @output_include_tag = Fluent::Config.bool_value(conf['output_include_tag'])
    @output_include_tag = true if @output_include_tag.nil?

    @output_data_type = conf['output_data_type']
    @output_data_type = 'json' if @output_data_type.nil?

    @f_separator = case conf['field_separator']
                   when 'SPACE' then ' '
                   when 'COMMA' then ','
                   else "\t"
                   end
    @add_newline = Fluent::Config.bool_value(conf['add_newline'])
    if @add_newline.nil?
      @add_newline = true
    end

    @remove_prefix = conf['remove_prefix']
    if @remove_prefix
      @removed_prefix_string = @remove_prefix + '.'
      @removed_length = @removed_prefix_string.length
    end
    if @output_include_tag and @remove_prefix and @remove_prefix.length > 0
      @default_tag = conf['default_tag']
      if @default_tag.nil? or @default_tag.length < 1
        raise Fluent::ConfigError, "Missing 'default_tag' with output_include_tag and remove_prefix."
      end
    end

    # default timezone: utc
    if conf['localtime'].nil? and conf['utc'].nil?
      @utc = true
      @localtime = false
    elsif not @localtime and not @utc
      @utc = true
      @localtime = false
    end
    # mix-in default time formatter (or you can overwrite @timef on your own configure)
    @timef = @output_include_time ? Fluent::TimeFormatter.new(@time_format, @localtime) : nil

    @custom_attributes = []
    if @output_data_type == 'json'
      self.instance_eval {
        def stringify_record(record)
          record.to_json
        end
      }
    elsif @output_data_type =~ /^attr:(.*)$/
      @custom_attributes = $1.split(',')
      if @custom_attributes.size > 1
        self.instance_eval {
          def stringify_record(record)
            @custom_attributes.map{|attr| (record[attr] || 'NULL').to_s}.join(@f_separator)
          end
        }
      elsif @custom_attributes.size == 1
        self.instance_eval {
          def stringify_record(record)
            (record[@custom_attributes[0]] || 'NULL').to_s
          end
        }
      else
        raise Fluent::ConfigError, "Invalid attributes specification: '#{@output_data_type}', needs one or more attributes."
      end
    else
      raise Fluent::ConfigError, "Invalid output_data_type: '#{@output_data_type}'. specify 'json' or 'attr:ATTRIBUTE_NAME' or 'attr:ATTR1,ATTR2,...'"
    end

    if @output_include_time and @output_include_tag
      if @add_newline and @remove_prefix
        self.instance_eval {
          def format(tag,time,record)
            if (tag[0, @removed_length] == @removed_prefix_string and tag.length > @removed_length) or
                tag == @remove_prefix
              tag = tag[@removed_length..-1] || @default_tag
            end
            @timef.format(time) + @f_separator + tag + @f_separator + stringify_record(record) + "\n"
          end
        }
      elsif @add_newline
        self.instance_eval {
          def format(tag,time,record)
            @timef.format(time) + @f_separator + tag + @f_separator + stringify_record(record) + "\n"
          end
        }
      elsif @remove_prefix
        self.instance_eval {
          def format(tag,time,record)
            if (tag[0, @removed_length] == @removed_prefix_string and tag.length > @removed_length) or
                tag == @remove_prefix
              tag = tag[@removed_length..-1] || @default_tag
            end
            @timef.format(time) + @f_separator + tag + @f_separator + stringify_record(record)
          end
        }
      else
        self.instance_eval {
          def format(tag,time,record)
            @timef.format(time) + @f_separator + tag + @f_separator + stringify_record(record)
          end
        }
      end
    elsif @output_include_time
      if @add_newline
        self.instance_eval {
          def format(tag,time,record);
            @timef.format(time) + @f_separator + stringify_record(record) + "\n"
          end
        }
      else
        self.instance_eval {
          def format(tag,time,record);
            @timef.format(time) + @f_separator + stringify_record(record)
          end
        }
      end
    elsif @output_include_tag
      if @add_newline and @remove_prefix
        self.instance_eval {
          def format(tag,time,record)
            if (tag[0, @removed_length] == @removed_prefix_string and tag.length > @removed_length) or
                tag == @remove_prefix
              tag = tag[@removed_length..-1] || @default_tag
            end
            tag + @f_separator + stringify_record(record) + "\n"
          end
        }
      elsif @add_newline
        self.instance_eval {
          def format(tag,time,record)
            tag + @f_separator + stringify_record(record) + "\n"
          end
        }
      elsif @remove_prefix
        self.instance_eval {
          def format(tag,time,record)
            if (tag[0, @removed_length] == @removed_prefix_string and tag.length > @removed_length) or
                tag == @remove_prefix
              tag = tag[@removed_length..-1] || @default_tag
            end
            tag + @f_separator + stringify_record(record)
          end
        }
      else
        self.instance_eval {
          def format(tag,time,record)
            tag + @f_separator + stringify_record(record)
          end
        }
      end
    else # without time, tag
      if @add_newline
        self.instance_eval {
          def format(tag,time,record);
            stringify_record(record) + "\n"
          end
        }
      else
        self.instance_eval {
          def format(tag,time,record);
            stringify_record(record)
          end
        }
      end
    end
  end

  def stringify_record(record)
    record.to_json
  end

  def format(tag, time, record)
    if tag == @remove_prefix or (tag[0, @removed_length] == @removed_prefix_string and tag.length > @removed_length)
      tag = tag[@removed_length..-1] || @default_tag
    end
    time_str = if @output_include_time
                 @timef.format(time) + @f_separator
               else
                 ''
               end
    tag_str = if @output_include_tag
                tag + @f_separator
              else
                ''
              end
    time_str + tag_str + stringify_record(record) + "\n"
  end

end

class Fluent::FileAlternativeOutput < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('file_alternative', self)

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

  include FluentExt::PlainTextFormatterMixin

  config_set_default :output_include_time, true
  config_set_default :output_include_tag, true
  config_set_default :output_data_type, 'json'
  config_set_default :field_separator, "\t"
  config_set_default :add_newline, true
  config_set_default :remove_prefix, nil

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

  def format(tag, time, record)
    time_str = @timef.format(time)
    time_str + @f_separator + tag + @f_separator + record_to_string(record) + @line_end
  end

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
      FileUtils.mkdir_p File.dirname(path)

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
      $log.error "failed to write data: path #{path}"
      raise
    end
    path
  end
end
