begin
  require 'mini_racer' unless defined?(MiniRacer)
rescue LoadError => e
  warn "[WARNING] Please install gem 'mini_racer' to use Less."
  raise e
end

module Less
  module JavaScript
    
    class ExternalMiniRacer < MiniRacer::Context
      
      def [](key)
        @functions[key]
      end

      def []=(key, val)
        @functions[key] = val
      end

    end

    class V8Context

      def self.instance
        return new
      end

      def initialize(globals = nil)
        @mini_context = ExternalMiniRacer.new
        globals.each { |key, val| @mini_context[key] = val } if globals
      end

      def unwrap
        @mini_context
      end

      def exec(&block)
        lock(&block)
      end

      def eval(source, options = nil)
        source = source.encode('UTF-8') if source.respond_to?(:encode)

        lock do
          @mini_context.eval("(#{source})")
        end
      end

      def call(properties, *args)
        args.last.is_a?(::Hash) ? args.pop : nil

        lock do
          @mini_context.eval(properties).call(*args)
        end
      end

      def method_missing(symbol, *args)
        if @mini_context.respond_to?(symbol)
          @mini_context.send(symbol, *args)
        else
          super
        end
      end

      private

        def lock(&block)
          do_lock(&block)
        rescue MiniRacer::RuntimeError => e
          if e.value && ( e.value['message'] || e.value['type'].is_a?(String) )
            raise Less::ParseError.new(e, e.value)
          end
          if e.unwrap.to_s =~ /missing opening `\(`/
            raise Less::ParseError.new(e.unwrap.to_s)
          end
          if e.message && e.message[0, 12] == "Syntax Error"
            raise Less::ParseError.new(e)
          else
            raise Less::Error.new(e)
          end
        end

        def do_lock
          result, exception = nil, nil
          
          begin
            result = yield
          rescue Exception => e
            exception = e
          end

          if exception
            raise exception
          else
            result
          end
        end

    end
  end
end