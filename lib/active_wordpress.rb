# RubyPress::WordpressConnectionName::ClassName
# RubyPress::WordpressConnection.establish_connection adapter: 'mysql2', username: 'myusername', password: 'myusername', host: 'localhost', database: 'wordpress_wordpress'
# ActiveWordPress.new 'WordpressConnection', {adapter: 'mysql2', username: 'mysqlusername', password: 'mysqlpassword', host: 'localhost', database: 'wordpress_wordpress'} # options are ActiveRecord::Base.establish_connection options...
# ActiveWordPress.new :wordpress_connection, {adapter: 'mysql2', username: 'mysqlusername', password: 'mysqlpassword', host: 'localhost', database: 'wordpress_wordpress'} # options are ActiveRecord::Base.establish_connection options...
require 'active_record'
require 'active_support/inflector'

module ActiveWordPress
  @@connections = []
  
  # Not sure if this is the correct way, but I #dup @@connections so nobody can directly modify @@connections
  def self.connections
    @@connections.dup
  end

  def self.new(connection_name, options)
    # Let's name the RubyPress::ClassName based on the connection_name
    classified_connection_name = connection_name.to_s.classify
    self.class_eval <<-EOF
      # Establish Connection for the parent class of our wordpress database
      class #{classified_connection_name} < ActiveRecord::Base
        @@tables = []
        
        self.abstract_class = true
        
        # Not sure if this is the correct way, but I #dup @@tables so nobody can directly modify @@tables
        def self.tables
          @@tables.dup
        end
        
        private
        
        def self.add_table(val)
          @@tables.push val
        end
      end
      #{classified_connection_name}.establish_connection options
    EOF
    
    connection_klass = eval(classified_connection_name)
    
    @@connections.push connection_klass

    # Get users table name.  If there's no users table name, then we have an invalid WordPress database.
    users_table_name = connection_klass.connection.tables.find{|t| t.match(/users/) }
    # Table name prefix is often "wp_".  We need this so we can accurately identify the names of the other tables...
    table_name_prefix = users_table_name.scan(/^(.*_)users$/).join
      
    # Get list of tables with prefix removed; This is to be the name of the class
    table_name_suffix_array = connection_klass.connection.tables.collect{|t| t.scan(/^#{table_name_prefix}(.*)$/)}.flatten
    table_name_suffix_array.collect do |database_table_name|
      database_table_name
      classified_database_table_name = database_table_name.gsub('meta','Meta').classify
      
      # Create a class name.  Important to note that Meta is plural, Metum is singular.  Table :postmeta becomes class PostMetum
      self.class_eval <<-EOF
        class #{classified_connection_name}::#{classified_database_table_name} < #{connection_klass}
          self.table_name = "#{table_name_prefix}#{database_table_name}"
        end
        
        # Add ActiveWordPress::ConnectionName::TableName to the @table class variable in the ActiveWordPress::ConnectionName
        #{classified_connection_name}.add_table #{classified_connection_name}::#{classified_database_table_name}
      EOF
    end
    
    # We return a list of table-classes for the newly-created connection...
    connection_klass.tables
  end
end
