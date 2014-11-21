# app.rb
require 'rubygems'
require 'jdbc/mysql'
require 'sinatra'
require 'mysql-connector-java-5.1.34-bin.jar'
require 'slim'
require 'date'
require 'bigdecimal'

def select(query)
	Java::com.mysql.jdbc.Driver
	userurl = 'jdbc:mysql://academic-mysql.cc.gatech.edu/cs4400_Group_37'
	connection = java.sql.DriverManager.get_connection(userurl, 'cs4400_Group_37', "sObFxNXG")
	# Define the query
	selectquery = query

	# Execute the query
	rows = connection.create_statement.execute_query(selectquery)
  result = resultset_to_hash(rows)

  connection.close

  result
end

get '/' do
  slim :login
end

post '/' do
  username = params[:username]
  password = params[:password]
  query = 'SELECT Username, Role
           FROM User
           WHERE (Username = \'%{Username}\' AND Password = \'%{Password}\');' %
           {:Username => username, :Password => password}
  user = select(query)
  unless user.empty?
    puts user
    if user[0]["Username"].equal?(username)
      slim :application
    end
  else
    # Login failed
    slim :login
  end
end

# Convert JDBC ResultSet to Ruby Hash
# Source: https://gist.github.com/rwjblue/1366047
def resultset_to_hash(resultset)
  meta = resultset.meta_data
  rows = []

  while resultset.next
    row = {}

    (1..meta.column_count).each do |i|
      name = meta.column_name i
      row[name]  =  case meta.column_type(i)
                      when -6, -5, 5, 4
                        # TINYINT, BIGINT, INTEGER
                        resultset.get_int(i).to_i
                      when 41
                        # Date
                        resultset.get_date(i)
                      when 92
                        # Time
                        resultset.get_time(i).to_i
                      when 93
                        # Timestamp
                        resultset.get_timestamp(i)
                      when 2, 3, 6
                        # NUMERIC, DECIMAL, FLOAT
                        case meta.scale(i)
                          when 0
                            resultset.get_long(i).to_i
                          else
                            BigDecimal.new(resultset.get_string(i).to_s)
                        end
                      when 1, -15, -9, 12
                        # CHAR, NCHAR, NVARCHAR, VARCHAR
                        resultset.get_string(i).to_s
                      else
                        resultset.get_string(i).to_s
                    end
    end

    rows << row
  end
  rows
end