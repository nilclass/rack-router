class Rack::Router::Builder
  class Simple
    
    def self.run(options = {})
      builder = new
      yield builder
      builder.routes
    end
    
    attr_reader :routes
    
    def initialize
      @routes = []
    end
    
    def map(path, *args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      method  = args.last || "GET"
      
      conditions = {}
      conditions[:path_info]      = path if path
      conditions[:request_method] = upcase_method(args.last) if args.last
      
      @routes << Rack::Router::Route.new(options[:to], conditions, options[:with] || {})
    end
    
  private
  
    def upcase_method(method)
      case method
      when String, Symbol then method.to_s.upcase
      when Array          then method.map { |m| upcase_method(m) }
      else "GET"
      end
    end
    
  end
end