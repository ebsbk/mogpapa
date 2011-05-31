require File.dirname(__FILE__) + '/spec_helper'

class Model < BasicModel
  attr_accessor :avatar_file_name, :avatar_content_type,
    :avatar_file_size, :avatar_updated_at, :id

  has_attached_file :avatar,
                    :storage => :mogilefs,
                    :domain => 'storage.com',
                    :hosts => ['127.0.0.1:4343', '127.0.0.1:4345']
end

describe Paperclip::Storage::Mogilefs do

  before(:each) do
    Paperclip::Storage::Mogilefs.clear
  end

  it 'allow to upload file to mogile fs' do
    file = create_upload_file filename: 'test.jpg',
                              type: 'image/jpeg',
                              head: '',
                              tempfile: create_tmp_file
    mgfs_expect_creation :domain=>"storage.com",
                         :hosts=>["127.0.0.1:4343", "127.0.0.1:4345"]
    mgfs_expect_admin_creation
    mgfs_expect_class_creation 'storage.com', 'avatar', 1
    mgfs_expect_store '/avatars/12/original/test.jpg',
                 'avatar',
                 'binary data:great looking picture of naked woman'

    m = Model.new
    m.id = 12
    m.avatar = file

    m.avatar_file_name.should == 'test.jpg'
    m.avatar_content_type.should == 'image/jpeg'
    m.avatar_file_size.should == 48
    m.avatar_updated_at.should_not be_nil
    url = 'avatars/12/original/test.jpg'
    m.avatar.url.should == "/mogilefs-get/#{url}?#{m.avatar.updated_at}"
    m.avatar.path.should == "/#{url}"

    m.save
  end

  it 'allows to url for storage' do
    m = Model.new
    m.id = 12
    m.avatar_file_name = 'test.jpg'
    m.avatar_content_type = 'image/jpeg'
    m.avatar_file_size = 48
    m.avatar_updated_at = time = Time.new('2010-02-05')
    
    url = 'avatars/12/original/test.jpg'
    m.avatar.url.should == "/mogilefs-get/#{url}?#{time.to_i}"
    m.avatar.path.should == "/#{url}"
    m.avatar.path('test_class').should == '/avatars/12/test_class/test.jpg'
  end

  it 'properly implements to_file' do
    mgfs_expect_creation :domain=>"storage.com",
                         :hosts=>["127.0.0.1:4343", "127.0.0.1:4345"]
    mgfs_expect_read 'some_binary_data', "/avatars/12/original/test.jpg"
    
    m = Model.new
    m.id = 12
    m.avatar_file_name = 'test.jpg'
    file = m.avatar.to_file
    
    file.read.should == 'some_binary_data'
    file.close
  end
  
  it 'checks domain and credentials to be present in attachment defenition' do
    class NoCredModel_ < BasicModel
      attr_accessor :avatar_file_name, :avatar_content_type,
      :avatar_file_size, :avatar_updated_at, :id
      
      has_attached_file :avatar,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
    end

    lambda {
      m = NoCredModel_.new
      m.avatar = 'test.jpg'
    }.should raise_error(ArgumentError)
  end
  
  it 'allows to specify number of copies for each attachment defenition' do
    class DefCountModel_ < BasicModel
      attr_accessor :avatar_file_name, :avatar_content_type,
      :avatar_file_size, :avatar_updated_at, :id
      
      has_attached_file :avatar,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
                        :hosts => ['127.0.0.1:4343', '127.0.0.1:4345'],
                        :dev_count => 5
    end
    
    file = create_upload_file filename: 'test.jpg',
                              type: 'image/jpeg',
                              head: '',
                              tempfile: create_tmp_file
    mgfs_expect_creation :domain=>"storage.com",
                         :hosts=>["127.0.0.1:4343", "127.0.0.1:4345"]    
    mgfs_expect_admin_creation
    mgfs_expect_class_creation 'storage.com', 'avatar', 5
    mgfs_expect_store '/avatars/12/original/test.jpg',
                      'avatar',
                      'binary data:great looking picture of naked woman'

    m = DefCountModel_.new
    m.id = 12
    m.avatar = file
    m.save
  end

  it 'stores model with multiple attachments' do
    class MultipleAttachmentsModel_ < BasicModel
      attr_accessor :avatar_file_name, :avatar_content_type,
      :avatar_file_size, :avatar_updated_at, :id

      attr_accessor :icon_file_name, :icon_content_type,
      :icon_file_size, :icon_updated_at
      
      
      has_attached_file :avatar,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
                        :hosts => ['127.0.0.1:4343', '127.0.0.1:4345']

      has_attached_file :icon,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
                        :hosts => ['127.0.0.1:4343', '127.0.0.1:4345']
    end

    file1 = create_upload_file filename: 'test.jpg',
                              type: 'image/jpeg',
                              head: '',
                              tempfile: create_tmp_file

    file2 = create_upload_file filename: 'test.jpg',
                              type: 'image/jpeg',
                              head: '',
                              tempfile: create_tmp_file

    mgfs_expect_creation(:domain=>"storage.com",
                         :hosts=>["127.0.0.1:4343", "127.0.0.1:4345"]).once

    mgfs_expect_admin_creation.once
    mgfs_expect_class_creation(any_args).twice
    mgfs_expect_store(any_args).twice
    
    m = MultipleAttachmentsModel_.new
    m.id = 33
    m.avatar = file1
    m.icon = file2
    m.save
  end

  it 'deletes attachment' do
    m = Model.new
    m.id = 12
    m.avatar_file_name = 'test.jpg'
    m.avatar_content_type = 'image/jpeg'
    m.avatar_file_size = 48
    m.avatar_updated_at = time = Time.new('2010-02-05')

    mgfs_expect_creation(any_args)
    url = '/avatars/12/original/test.jpg'
    mgfs_expect_list_keys(url, [[url], url])
    mgfs_expect_delete(url)    

    m.destroy
  end

  it 'should not try to delete not existing attachment' do
    m = Model.new
    m.id = 12
    m.avatar_file_name = 'test.jpg'
    m.avatar_content_type = 'image/jpeg'
    m.avatar_file_size = 48
    m.avatar_updated_at = time = Time.new('2010-02-05')

    mgfs_expect_creation(any_args)
    url = '/avatars/12/original/test.jpg'
    mgfs_expect_list_keys(url, nil)

    m.destroy
  end

  it 'stores attachment with two styles' do
    class StylesModel_ < BasicModel
      attr_accessor :avatar_file_name, :avatar_content_type,
      :avatar_file_size, :avatar_updated_at, :id

      has_attached_file :avatar,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
                        :hosts => ['127.0.0.1:4343', '127.0.0.1:4345'],
                        :styles => {:medium => "300x300>"}
    end


    file = create_upload_file filename: 'test.jpg',
                              type: 'image/jpeg',
                              head: '',
                              tempfile: create_tmp_file

    mgfs_expect_creation :domain=>"storage.com",
                         :hosts=>["127.0.0.1:4343", "127.0.0.1:4345"]
    mgfs_expect_admin_creation
    mgfs_expect_class_creation 'storage.com', 'avatar', 1
    mgfs_expect_store '/avatars/12/original/test.jpg',
                      'avatar',
                      'binary data:great looking picture of naked woman'
    mgfs_expect_store '/avatars/12/medium/test.jpg',
                      'avatar',
                      'More attractive woman'
    
    Paperclip.stub_chain(:processor, :make, :read){ 'More attractive woman' }
    
    m = StylesModel_.new
    m.id = 12
    m.avatar = file
    m.save
  end

  it 'reuses connections' do
    class SecondModel_ < BasicModel
      attr_accessor :something_file_name, :something_content_type,
      :something_file_size, :something_updated_at, :id

      has_attached_file :something,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
                        :hosts => ['127.0.0.1:4343', '127.0.0.1:4345'],
    end

    class ThirdModel_ < BasicModel
      attr_accessor :bank_data_file_name, :bank_data_content_type,
      :bank_data_file_size, :bank_data_updated_at, :id

      has_attached_file :bank_data,
                        :storage => :mogilefs,
                        :domain => 'storage.com',
                        :hosts => ['127.0.0.1:2222']
    end

    mgfs_expect_creation :domain=>"storage.com",
                         :hosts=>["127.0.0.1:4343", "127.0.0.1:4345"]

    mgfs_expect_creation(any_args)
    mgfs_expect_admin_creation.twice
    mgfs_expect_class_creation(any_args).exactly(3).times
    mgfs_expect_store(any_args).exactly(3).times
    
    file1 = create_upload_file filename: 'test.jpg',
                               type: 'image/jpeg',
                               head: '',
                               tempfile: create_tmp_file

    file2 = create_upload_file filename: 'test.txt',
                               type: 'text/text',
                               head: '',
                               tempfile: create_tmp_file

    file3 = create_upload_file filename: 'test.csv',
                               type: 'text/text',
                               head: '',
                               tempfile: create_tmp_file
    
    m1 = Model.new
    m2 = SecondModel_.new
    m3 = ThirdModel_.new

    m1.avatar = file1
    m2.something = file2
    m3.bank_data = file3

    m1.save
    m2.save
    m3.save
    
  end
  
  it 'properly forms url and path'  
  it 'check reading config from yaml file'

end
