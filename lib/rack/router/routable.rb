class Rack::Router
  module Routable
    
    def routes
      @routes ||= []
    end
    
    def named_routes
      @named_routes ||= {}
    end
    
    def prepare(options = {}, &block)
      builder = options.delete(:builder) || Builder::Simple
      @routes = builder.run(options, &block)
      @named_routes = {}
      
      @routes.each do |route|
        route.compile
        @named_routes[route.name] = route if route.name
      end
      
      self
    end
    
    # TODO: Figure out the API of this method
    def handle(env, context = nil)
      request  = Rack::Request.new(env)
      
      for route in routes
        route, params, response = route.handle(request, context)
        return route, params, response if route
      end
      
      return nil, {}, nil
    end
    
    def url(name, params = {})
      unless route = named_routes[name]
        raise ArgumentError, "Cannot find route named '#{name}'"
      end
      
      route.generate(params)
    end
    
  end
end