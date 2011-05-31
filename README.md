# Provides Paperclip storage module for Mogilefs storage. #

In ActiveRecord model call for +has_attached_file+ Paperclip functions with 

    :storage => :mogilefs,
    :domain => "your_domain_name",
    :hosts => ["ip_1:port_1","ip_2:port_2"],
    :fetch_url_prefix => "your_prefix". Specifyed domain must be created in Mogilefs storage manualy.

- :domain : Mogilefs domain
- :hosts : array of strings representing Mofilefs trackers hosts.
   Example: ["192.168.42.13:7001"]
- :fetch_url_prefix : prefix that added to attachment.url field.
  Resulting url will be: "/prefix/:attachment/:id/:style/:filename"
    
Classes create in Mogilefs storage automaticaly with name of attchment.
Example: if you declared in ActiveRecord model has_attached_file :favpic...
then new class name will be "favpic"
    
TO GET FILES FROM MOGILEFS STORAGE ADDITIONAL FUNCTIONALITY IS REQUIRED:
You can use provided generator to add special controller to rails application
for fetching files or build your own app. 
Additional route must be added to routes.rb to connect attachment.url with this controller.
Use :fetch_url_prefix for connection.
Example: asume you generated controller Mogilefs < ApplicationController with +get+ method.
Add this route to routes.rb:  match 'mogilefs-get/*key', :to => "mogilefs#get"
Specify :fetch_url_prefix => "mogilefs-get" 
in +has_attached_file+ method params in ActiveRecord Model.
