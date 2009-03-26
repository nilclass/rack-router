class Rack::Router
  
  SEGMENT_REGEXP         = /(:([a-z](_?[a-z0-9])*))/
  OPTIONAL_SEGMENT_REGEX = /^.*?([\(\)])/i
  SEGMENT_CHARACTERS     = "[^\/.,;?]".freeze
  
  class Condition
    
    attr_reader :segments, :pattern, :captures
    
    def initialize(pattern, conditions = {})
      @segments   = {}
      @captures   = {}
      @conditions = conditions
      
      @conditions.default = /#{SEGMENT_CHARACTERS}+/
      
      case pattern
      when String
        @segments = parse_segments_with_optionals(pattern.dup)
        @pattern  = Regexp.new("^#{compile(@segments)}$")
        @captures = @segments.flatten.select { |s| s.is_a?(Symbol) }
      else
        @pattern = convert_to_regexp(pattern)
      end
    end
    
    def match(other)
      if data = @pattern.match(other)
        captures = {}
        offsets.each do |key, value|
          captures[key] = data[value] if data[value]
        end
        captures
      end
    end
    
    def generate(params)
      generate_from_segments(@segments, params) or raise ArgumentError, "Condition cannot be generated with #{params.inspect}"
    end
    
    def inspect
      @pattern.inspect
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
          condition = @conditions[segment]
          condition = Regexp.escape(condition) unless condition.is_a?(Regexp)
          "(#{condition})"
        when Array
          "(?:#{compile(segment)})?"
        end
      end
      
      # The URI spec states that sequential slashes is equivalent to a
      # single slash and that trailing slashes can be ignored.
      compiled.join.gsub(%r'/+', '/').sub(%r'/+$', '')
    end
    
    def offsets
      @offsets ||= begin
        offsets = {}
        counter = 1
        
        captures.each do |capture|
          offsets[capture] = counter
          counter += 1 + regexp_arity(@conditions[capture])
        end
        
        offsets
      end
    end
    
    def generate_from_segments(segments, params)
      generated = segments.map do |segment|
        case segment
        when String
          segment
        when Symbol
          return unless params[segment] && params[segment].to_s =~ @conditions[segment]
          params[segment]
        when Array
          generate_from_segments(segment, params) || ""
        end
      end
      
      # Delete any used items from the params
      segments.each { |s| params.delete(s) if s.is_a?(Symbol) }
      
      generated.join
    end
    
    # ==== UTILITIES ====
    
    def convert_to_regexp(item)
      case item
      when Array  then Regexp.new("^(?:#{item.map { |i| convert_to_regexp(i) }.join("|")})$")
      when Regexp then item
      else Regexp.new("^#{Regexp.escape(item.to_s)}$")
      end
    end
    
    def regexp_arity(regexp)
      return 0 unless regexp.is_a?(Regexp)
      regexp.source.scan(/(?!\\)[(](?!\?[#=:!>-imx])/).length
    end
    
  end
end