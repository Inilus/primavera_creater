require 'rubygems'
require 'active_record'   # http://snippets.dzone.com/posts/show/3097 # http://habrahabr.ru/blogs/ruby/98751/
require 'yaml'
require 'logger'
 
# Загружаем файл настройки соединения с БД
dbconfig = YAML::load( File.open( 'config/database.yml' ) )
 
# Ошибки работы с БД
#ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger = Logger.new("log/active_record.log")
 
# Соединяемся с БД
ActiveRecord::Base.establish_connection(dbconfig)
