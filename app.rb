# app.rb
require 'sinatra'
require 'sinatra/config_file'
require 'rubygems'
require 'jdbc/mysql'
require 'mysql-connector-java-5.1.34-bin.jar'
require 'slim'
require 'date'
require 'bigdecimal'

#import JDBC/MySQL functions from mysql.rb
require_relative('mysql')

config_file 'database.yml'


get '/' do
  redirect to ('/login')
end

get '/login' do
  slim :login
end

post '/login' do
  query = "SELECT Username, Role
           FROM User
           WHERE ('#{params[:username]}' = Username AND  '#{params[:password]}' = Password);"
  user = select(query)
  if user.empty?
    # No users retrieved with query
    redirect to('/login')
  elsif user[0]["Username"] === params[:username]
    #@current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
    redirect to('/application')
  else
    redirect to('/login')
  end
end


get '/register' do
  slim :register
end

post '/register' do
  query = "INSERT INTO User(Username, Password, DOB, Role) VALUES
          ('#{params[:username]}',
           '#{params[:password]}',
           '#{params[:confirm_password]}',
           'Resident');"
  result = insert(query)
  if (result == 1 & (params[:password] == params[:confirm_password]))
    #@current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
    redirect to('/application')
  else
    redirect to('/register')
  end
end

get '/home' do
  slim :home
end

get '/application' do
  slim :application
end

post '/application' do
  query = "INSERT INTO User(Username, Password, DOB, Gender, Role) VALUES
          ('#{params[:username]}',
           '#{params[:password]}'
           '#{params[:dob]}'
           '#{params[:gender]}'
           'Resident');"
  query = "INSERT INTO Resident(Name, DOB, Gender, Monthly_income, Pref_apt_category, Pref_rent_range_min, Pref_rent_range_max, Move_in_date, Lease_term, Previous_address) VALUES
          ('#{params[:name]}',
           '#{params[:dob]}',
           '#{params[:gender]}'
           '#{params[:monthly_income]}',
           '#{params[:pref_apt_category]}',
           '#{params[:pref_rent_range_min]}',
           '#{params[:pref_rent_range_max]}',
           '#{params[:move_in_date]}',
           '#{params[:lease_term]}',
           '#{params[:previous_address]}');"
  result = insert(query)
  if result == 1
    #@current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
    redirect to('/home')
  else
    redirect to('/application')
  end
end
