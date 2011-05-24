require 'rubygems'
require 'active_record'   # http://snippets.dzone.com/posts/show/3097 # http://habrahabr.ru/blogs/ruby/98751/
require 'yaml'
require 'logger'

# Загружаем файл настройки соединения с БД
dbconfig = YAML::load( File.open( File.expand_path( "../../config/database.yml", __FILE__ ) ) )
dbconfig["database"] = File.expand_path( "../../#{ dbconfig["database"] }", __FILE__ )

# Ошибки работы с БД
ActiveRecord::Base.logger = Logger.new( File.expand_path( "../../log/active_record.log", __FILE__ ) )

# Соединяемся с БД
ActiveRecord::Base.establish_connection( dbconfig )

