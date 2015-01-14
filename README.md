# fluent-plugin-file-alternative 

File output plugin alternative implementation.

FileAlternativeOutput slices data by time (for specified units), and store these data as plain text on local file. You can specify to:

* format whole data as serialized JSON, single attribute or separated multi attributes
* include time as line header, or not
* include tag as line header, or not
* change field separator (default: TAB)
* add new line as termination, or not

And you can specify output file path as:

* Standard out_file way
  * configure `path /path/to/dir/access`
  * and `time_slice_format %Y%m%d`
  * got `/path/to/dir/access.20120316.log`
* Standard out_file way (alternative)
  * configure `path /path/to/dir/access.*.log`
  * and `time_slice_format %Y%m%d`
  * got `/path/to/dir/access.20120316.log`
* Alternative style
  * configure `path /path/to/dir/access.%Y%m%d.log` only (don't include `*`)
  * got `/path/to/dir/access.20120316.log`

And, gzip compression is also supported.

## Configuration

### FileAlternativeOutput

Standard out_file way (hourly log, compression, time-tag-json):

    <match out.**>
      type file_alternative
      path /var/log/service/access.*.log
      time_slice_format %Y%m%d_%H
      compress gzip
    </match>

By this configuration, in gzip compressed file '/var/log/service/access.20120316_23.log.gz', you get:

    2012-03-16T23:59:40 [TAB] out.service.xxx [TAB] {"field1":"value1","field2":"value2"}
    2012-03-16T23:59:40 [TAB] out.service.xxx [TAB] {"field1":"value1","field2":"value2"}
    2012-03-16T23:59:40 [TAB] out.service.xxx [TAB] {"field1":"value1","field2":"value2"}
    2012-03-16T23:59:40 [TAB] out.service.xxx [TAB] {"field1":"value1","field2":"value2"}
    
If you don't want fluentd-time and tag in written file, and messages with single attribute (as raw full apache log with newline):

    <match out.**>
      type file_alternative
      path /var/log/service/access.%Y%m%d_%H.log
      compress gzip
      output_include_time false
      output_include_tag false
      output_data_type attr:message
      add_newline false
    </match>

Then, you will get:

    192.168.0.1 - - [16/Mar/2012:23:59:40 +0900] "GET /content/x HTTP/1.1" 200 -
    192.168.0.1 - - [16/Mar/2012:23:59:40 +0900] "GET /content/x HTTP/1.1" 200 -
    192.168.0.1 - - [16/Mar/2012:23:59:40 +0900] "GET /content/x HTTP/1.1" 200 -

## TODO

* consider what to do next
* patches welcome!

## Copyright

Copyright:: Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
License::   Apache License, Version 2.0
