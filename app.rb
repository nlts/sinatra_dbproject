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
    @current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
    redirect to('/application')
  else
    redirect to('/login')
  end
end

get '/register' do
  slim :register
end

get '/application' do
  slim :application
end

post '/register' do
  query = "INSERT INTO User(Username, Password, Name, DOB, Gender, Role) VALUES
          ('#{params[:username]}',
           '#{params[:password]}',
           '#{params[:name]}',
           '#{params[:dob]}',
           '#{params[:gender]}',
           'Resident');"
  result = insert(query)
  if result == 1
    @current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
    redirect to('/application')
  else
    redirect to('/register')
  end
end