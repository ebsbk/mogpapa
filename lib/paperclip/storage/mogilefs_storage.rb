module Paperclip
  module Storage
    # Paperclip storage for Mogilefs.
    # Dependent on mogilefs-client gem.
    # :domain, :hosts, :fetch_url_prefix options must be provided through
    # +has_attached_file+ method params in ActiveRecord Model.
    # :domain : Mogilefs domain
    # :hosts : array of strings representing Mofilefs trackers hosts.
    # Example: ["192.168.42.13:7001"]
    # :fetch_url_prefix : prefix that added to attachment.url field.
    # Resulting url will be: "/prefix/:attachment/:id/:style/:filename"
    #
    # Classes created in Mogilefs storage automaticaly with name of attchment.
    # Example: if you declared in ActiveRecord model has_attached_file :favpic...
    # then new class name will be "favpic"
    #
    # TO GET FILES FROM MOGILEFS STORAGE ADDITIONAL FUNCTIONALITY IS REQUIRED:
    # You can use provided generator to add special controller to rails application
    # for fetching files or build your own app. 
    # Additional route must be added to routes.rb to connect attachment.url with this controller.
    # Use :fetch_url_prefix for connection.
    # Example: asume you generated controller Mogilefs < ApplicationController with +get+ method.
    # Add this route to routes.rb:  match 'mogilefs-get/*key', :to => "mogilefs#get"
    # Specify :fetch_url_prefix => "mogilefs-get" 
    # in +has_attached_file+ method params in ActiveRecord Model.
    #
    # For better perfomance connections stored in Mogilefs module.

    module Mogilefs

      # Hash of MogileFS::MogileFS objects. Keys are +connection_options+ method call result
      # of extendend ActiveRecord object. Returns hash of hosts and domain options params.
      @connections = {}
      # Hash of MogileFS::Admin objects. Keys are options of +has_attached_file+
      @admin_connections = {}
      # Classes defined in Mogilefs storage. 
      @storage_classes = {}

      def self.clear
        @connections.clear
        @admin_connections.clear
        @storage_classes.clear
      end

      # Creates new class if it does not exists.
      # Checks @storage_classes before to skeep redundat queryes to Mogilefs.
      def self.create_class(options, domain, class_name, dev_count)
        if !((@storage_classes[options] ||= []).include?(class_name))
          ac =  @admin_connections[options] ||= MogileFS::Admin.new(:hosts => options[:hosts])
          begin
            ac.create_class(domain, class_name, dev_count)
            @storage_classes[options] << class_name
          rescue MogileFS::Backend::ClassExistsError => e
            @storage_classes[options] << class_name
          rescue MogileFS::Error => e
            raise
          end
        end
      end
      
      # Returns MogileFS::MogileFS objects for specified options object. 
      # Creates new objects only if it does not exists.
      def self.connection_for(options)
        @connections[options] ||= MogileFS::MogileFS.new(:domain => options[:domain], 
                                                         :hosts => options[:hosts])
      end

      def self.delete_connection(options)
        @connections.delete(options)
      end

      def self.connections
        @connections
      end

      def self.extended(base)
        begin
          require 'mogilefs'
        rescue LoadError => e
          e.message << " (You may need to install the mogilefs-client gem)"
          raise e
        end unless defined?(MogileFS::MogileFS)

        base.instance_eval do
          @options.reverse_merge!(parse_yaml_config(@options[:config])) if @options[:config]
          @url = ":mogilefs_url"
          @path = ":mogilefs_path"
          @dev_count = @options[:dev_count] || 1
          @domain = @options[:domain] or (raise ArgumentError, "Domain must be provided")
          @hosts = @options[:hosts] or (raise ArgumentError, "Hosts must be provided")
          @fetch_url_prefix = @options[:fetch_url_prefix] || "mogilefs-get"
        end

        Paperclip.interpolates(:mogilefs_url) do |attachment, style|
          # TODO: sanitize filename
          "/#{attachment.fetch_url_prefix}/:attachment/:id/#{style.to_s}/:filename"
        end
        Paperclip.interpolates(:mogilefs_path) do |attachment, style|
          # TODO: sanitize filename
          "/:attachment/:id/#{style.to_s}/:filename"
        end
      end

      # Asks Mogilefs module for MogileFS::MogileFS object 
      # for this object's connection_options object.
      def connection
        Mogilefs.connection_for(connection_options)
      end

      # Asks Mogilefs module to create new class. Creates new class only if it does not exists.
      def create_class_if_required(class_name)
        Mogilefs.create_class(admin_connection_options, 
                              domain, 
                              class_name, 
                              dev_count)
      end

      def flush_deletes
        log("queued: #{@queued_for_delete}")
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            connection.delete(path)
          rescue MogileFS::Error => e
            raise
          end
        end
        @queued_for_delete = {}
      end

      def flush_writes
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")
            create_class_if_required name.to_s
            connection.store_content(path(style), name.to_s, file.read)
          rescue MogileFS::Error => e
            raise
          end
        end
        @queued_for_wirte = {}
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file(style = default_style)
        return @queued_for_write[style] if @queued_for_write[style]
        filename = path(style)
        extname  = File.extname(filename)
        basename = File.basename(filename, extname)
        file = Tempfile.new([basename, extname])
        file.binmode
        begin
          file.write(connection.get_file_data(path(style))) 
        rescue MogileFS::Error => e
          raise
        end
        file.rewind
        return file
      end

      def exists?(style = default_style)
        if original_filename
          begin
            return !connection.list_keys(path(style)).nil?
          rescue MogileFS::Error => e
            raise
          end
        else
          false
        end
      end

      def fetch_url_prefix
        @fetch_url_prefix
      end

      def domain
        @domain
      end
      
      def hosts
        @hosts
      end

      def dev_count
        @dev_count
      end

      # Parses yaml config and sets configuration values.
      def parse_yaml_config(file_or_path = "config/mogilefs.yml")
        options = 
          case file_or_path
          when File
            YAML::load(ERB.new(File.read(file_or_path.path)).result)
          when String, Pathname
            YAML::load(ERB.new(File.read(file_or_path)).result)
          else
            raise ArgumentError, "Argument is not a path or file"
          end
        options.symbolize_keys
      end

      # Returns connections options for this object
      def connection_options
        {:domain => domain, :hosts => hosts}
      end

      def admin_connection_options
        {:hosts => hosts}
      end

      private :parse_yaml_config

    end
  end
end

