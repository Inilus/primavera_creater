require 'rubygems'
require 'active_record'   # http://snippets.dzone.com/posts/show/3097 # http://habrahabr.ru/blogs/ruby/98751/
require 'yaml'
 
# Загружаем файл настройки соединения с БД
dbconfig = YAML::load( File.open( 'config/database.yml' ) )
 
# Ошибки работы с БД направим в стандартный поток (консоль)
#ActiveRecord::Base.logger = Logger.new(STDERR) # Simple logging utility. logger.rb -- standart lib
 
# Соединяемся с БД
ActiveRecord::Base.establish_connection(dbconfig)
