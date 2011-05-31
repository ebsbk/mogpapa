require './lib/mogpapa.rb'
require "action_dispatch/http/upload"
require "active_record"
require "paperclip"
require "logger"

File.send(:include, Paperclip::Upfile)
ActiveRecord::Base.logger = Logger.new(nil)



module MogileFS
  MogileFS = Object.new
  Admin = Object.new
  def Admin.to_s ; 'AdminStub'; end
  def MogileFS.to_s ; 'MogileFSStub'; end
  class Error < StandardError; end
end unless defined? MogileFS::MogileFS


def mgfs_expect_creation(*args)
  MogileFS::MogileFS.should_receive(:new).with(*args){ MogileFS::MogileFS }
end

def mgfs_expect_admin_creation
  MogileFS::Admin.should_receive(:new).with( kind_of(Hash) ){ MogileFS::Admin }
end

def mgfs_expect_class_creation(*args)
  MogileFS::Admin.stub(:list_fids){ [] } #remove me please
  MogileFS::Admin.should_receive(:create_class).with(*args)
end

def mgfs_expect_delete(*args)
  MogileFS::MogileFS.should_receive(:delete).with(*args)
end

def mgfs_expect_store(*args)
  MogileFS::MogileFS.should_receive(:store_content).with(*args)
end

def mgfs_expect_read(data, *args)
  MogileFS::MogileFS.should_receive(:get_file_data).with(*args){ data }
end

def mgfs_expect_list_keys(key, result)
  MogileFS::MogileFS.should_receive(:list_keys).with(key){ result }  
end

class BasicModel
  extend ActiveModel::Naming
  extend ActiveModel::Callbacks
  include ActiveModel::Validations  
  include Paperclip::Glue

  define_model_callbacks :save, :destroy

  def save
    _run_save_callbacks do; end
  end

  def destroy
    _run_destroy_callbacks do; end
  end

  alias :save! :save
  alias :destroy! :destroy

  def to_model
    self
  end

  def errors
    @errors ||= {}
  end
  
end

def create_tmp_file
  tmp_file = Tempfile.new 'test.jpg'
  tmp_file.binmode
  tmp_file.write('binary data:great looking picture of naked woman')
  tmp_file.rewind
  tmp_file
end

def create_upload_file(*args)
  ActionDispatch::Http::UploadedFile.new(*args)
end

