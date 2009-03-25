class Rack::Router
  
  SEGMENT_REGEXP         = /(:([a-z](_?[a-z0-9])*))/
  OPTIONAL_SEGMENT_REGEX = /^.*?([\(\)])/i
  SEGMENT_CHARACTERS     = "[^\/.,;?]".freeze
  
  class Condition
    def initialize(pattern, conditions = {})
      if pattern.is_a?(String)
        @conditions = {}
        
        conditions.each do |k, v|
          @conditions[k] = Regexp.escape(v) unless v.is_a?(Regexp)
        end
        
        @segments   = parse_segments_with_optionals(pattern.dup)
        @pattern    = Regexp.new("^#{compile(@segments)}$")
        @captures   = @segments.flatten.select { |s| s.is_a?(Symbol) }
      else
        @pattern    = pattern
      end
    end
    
    def match(other)
      other =~ @pattern and {}
    end
    
  private
    
    def parse_segments_with_optionals(pattern, nest_level = 0)
      segments = []

      # Extract all the segments at this parenthesis level
      while segment = pattern.slice!(OPTIONAL_SEGMENT_REGEX)
        # Append the segments that we came across so far
        # at this level
        segments.concat parse_segments(segment[0..-2]) if segment.length > 1
        # If the parenthesis that we came across is an opening
        # then we need to jump to the higher level
        if segment[-1, 1] == '('
          segments << parse_segments_with_optionals(pattern, nest_level + 1)
        else
          # Throw an error if we can't actually go back down (aka syntax error)
          raise ArgumentError, "There are too many closing parentheses" if nest_level == 0
          return segments
        end
      end

      # Save any last bit of the string that didn't match the original regex
      segments.concat parse_segments(pattern) unless pattern.empty?

      # Throw an error if the string should not actually be done (aka syntax error)
      raise ArgumentError, "You have too many opening parentheses" unless nest_level == 0

      segments
    end
    
    def parse_segments(path)
      segments = []

      while match = (path.match(SEGMENT_REGEXP))
        segments << match.pre_match unless match.pre_match.empty?
        segments << match[2].intern
        path = match.post_match
      end

      segments << path unless path.empty?
      segments
    end
    
    def compile(segments)
      compiled = segments.map do |segment|
        case segment
        when String
          Regexp.escape(segment)
        when Symbol
          "(#{@conditions[segment] || SEGMENT_CHARACTERS + "+"})"
        when Array
          "(?:#{compile(segment)})?"
        end
      end
      
      # The URI spec states that sequential slashes is equivalent to a
      # single slash and that trailing slashes can be ignored.
      compiled.join.gsub(%r'/+', '/').sub(%r'/+$', '')
    end
    
  end
end