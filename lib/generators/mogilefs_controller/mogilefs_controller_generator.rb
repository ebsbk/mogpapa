  class MogilefsControllerGenerator < Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)
    argument :name, :type => :string, :default => "mogilefs", :desc => "Controller name."
    argument :domain, :type => :string, :default => "testdomain", :desc => "Mogilefs domain name."
    argument :hosts, :type => :string, :default => "127.0.0.1:7001", :desc => "Example: --hosts 127.0.0.1:7001,127.0.0.1:7002"
    argument :fetch_url_prefix, :type => :string, :default => "mogilefs-get", :desc => "Route name that connected to controller being generated."
    argument :dev_count, :type => :string, :default => '1', :desc => "Nuber of devices in MogileFS storage to keep data"
    class_option :yaml, :type => :boolean, :default => true, :desc => "Generate yaml config file in config/mogilefs.yaml"


    def generate_controller
      template "mogilefs_controller_template.erb", "app/controllers/#{name}_controller.rb"
      append_route
      generate_yaml if options.yaml
    end


    private

    def generate_yaml
      template "mogilefs_yaml_template.erb", "config/mogilefs.yml"
    end

    # Builds route for controller being generated
    def build_route
      "get \'#{fetch_url_prefix}/*key\', :to => \"#{name}#get\""
    end

    # Appends route to routes.rb
    def append_route
      route build_route
    end

  end

