module SmallCage::Commands
  class Auto < SmallCage::Commands::Base
    
    def initialize(opts)
      super(opts)
      @target = Pathname.new(opts[:path])
      @port = opts[:port]
      @sleep = 1
      @mtimes = {}
    end

    def execute
      puts_banner

      start_http_server unless @port.nil?
      init_sig_handler

      @loader = SmallCage::Loader.new(@target)

      first_loop = true
      @update_loop = true
      while @update_loop
        if first_loop
          first_loop = false
          update_target
        else
          update_modified_files
        end
        sleep @sleep
      end
    end
    
    def modified_special_files
      root = @loader.root
      
      result = []
      Dir.chdir(root) do
        Dir.glob("_smc/{templates,filters,helpers}/*") do |f|
          f = root + f
          mtime = File.stat(f).mtime
          if @mtimes[f] != mtime
            @mtimes[f] = mtime
            result << f
          end
        end
      end
      
      return result
    end
    private :modified_special_files

    def modified_files
      result = []
      @loader.each_smc_file do |f|
        mtime = File.stat(f).mtime
        if @mtimes[f] != mtime
          @mtimes[f] = mtime
          result << f
        end
      end
      return result
    end
    private :modified_files
    
    def update_target
      # load @mtimes
      modified_special_files
      target_files = modified_files 

      runner = SmallCage::Runner.new({ :path => @target })
      begin
        runner.update
      rescue Exception => e
        STDERR.puts e.to_s
        STDERR.puts $@[0..4].join("\n")
        STDERR.puts ":"
      end
      
      update_http_server(target_files)
      puts_line
    end
    private :update_target

    def update_modified_files
      reload = false
      if modified_special_files.empty?
        target_files = modified_files
      else
        # update root directory.
        target_files = [@loader.root + "./_dir.smc"]
        reload = true
      end
      
      return if target_files.empty?
      target_files.each do |tf|
        if tf.basename.to_s == "_dir.smc"
          runner = SmallCage::Runner.new({ :path => tf.parent })
        else
          runner = SmallCage::Runner.new({ :path => tf })
        end
        runner.update
      end
      
      if reload
        @http_server.reload
      else
        update_http_server(target_files)
      end
      puts_line
    rescue Exception => e
      STDERR.puts e.to_s
      STDERR.puts $@[0..4].join("\n")
      STDERR.puts ":"
      print "\a" unless quiet? # Bell
      puts_line
    end
    private :update_modified_files
    
    def puts_banner
      return if quiet?
      puts "SmallCage Auto Update"
      puts "http://localhost:#{@port}/_smc/auto" unless @port.nil?
      puts
    end
    private :puts_banner
    
    def puts_line
      return if quiet?
      puts "-" * 60
      print "\a" # Bell
    end
    private :puts_line
    
    def update_http_server(target_files)
      return unless @http_server
      path = target_files.find {|p| p.basename.to_s != "_dir.smc" }
      if path.nil?
        dir = target_files.shift
        dpath = SmallCage::DocumentPath.new(@loader.root, dir.parent)
        @http_server.updated_uri = dpath.uri
      else
        dpath = SmallCage::DocumentPath.new(@loader.root, path)
        @http_server.updated_uri = dpath.outuri
      end
    end
    private :update_http_server

    def init_sig_handler
      shutdown_handler = Proc.new do |signal|
        @http_server.shutdown unless @http_server.nil?
        @update_loop = false
      end
      SmallCage::Application.add_signal_handler(["INT", "TERM"], shutdown_handler)
    end
    private :init_sig_handler

    def start_http_server 
      document_root = @opts[:path]
      port = @opts[:port]
        
      @http_server = SmallCage::HTTPServer.new(document_root, port)
       
      Thread.new do
        @http_server.start    
      end
    end
    private :start_http_server
    
  end
end