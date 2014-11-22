# Select and Insert statements modified from https://github.com/jruby/jruby/wiki/JDBC
def select(query)
  Java::com.mysql.jdbc.Driver
  userurl = settings.db_url
  connection = java.sql.DriverManager.get_connection(userurl, settings.db_name, settings.db_password)
  # Define the query
  selectquery = query

  # Execute the query
  rows = connection.create_statement.execute_query(selectquery)
  result = resultset_to_hash(rows)
  connection.close

  result
end

def insert(query)
  Java::com.mysql.jdbc.Driver
  userurl = settings.db_url
  connection = java.sql.DriverManager.get_connection(userurl, settings.db_name, settings.db_password)
  # Define the query
  insertquery = query

  # Execute the query
  num_rows_inserted = connection.create_statement.execute_update(insertquery)
  connection.close

  num_rows_inserted
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