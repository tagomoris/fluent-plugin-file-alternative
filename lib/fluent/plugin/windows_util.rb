module Fluent
  module FileAlternative
    module WindowsUtil
      def windows?
        RUBY_PLATFORM =~ /mswin(?!ce)|mingw|cygwin|bccwin/
      end
    end
  end
end
