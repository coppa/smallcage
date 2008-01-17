module SmallCage
  module MenuHelper
    
    def menu_active(name)
      p = @obj["menu_path"]
      p ||= uri
      return p =~ %r{^/#{name}/} ? "active" : "inactive"
    end
    
    def menu_active_rex(rex)
      p = @obj["menu_path"]
      p ||= uri
      return p =~ rex ? "active" : "inactive"
    end
    
    def topic_dirs
      @page ||= {}
      return @page[:topic_dirs].dup unless @page[:topic_dirs].nil?

      result = dirs.dup
      # result.pop # remove current
      result.reject! {|d| d["topic"].nil? }
      @page[:topic_dirs] = result
      
      return @page[:topic_dirs].dup
    end
    
  end
end