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

#2 different homepage layouts, one for resident and one for management
#Resident can click "Pay Rent", "Request Maintenance", or "Payment Information" and has a notification when they have a message
#Management can click "Application Review", "Maintenance Requests", "Rent Reminder", or choose a report from a dropdown menu

#resident functionalities
get '/rent' do
  slim :rent
end

post '/rent' do
  query = "INSERT INTO Rent_Payment(Apartment_num, Month, Year, Date_due, Amount_due, Late_fee, Date_paid, Amount_paid, Username, CC_last_4_digits) VALUES
          ('#{params[:apartment_num]}',
           '#{params[:month]}',
           '#{params[:year]}',
           '#{params[:date_due]}',
           '#{params[:amount_due]}',
           '#{params[:late_fee]}',
           '#{params[:date_paid]}',
           '#{params[:amount_paid]}',
           '#{params[:username]}',
           '#{params[:cc_last_4_digits]}');"
  result = insert(query)
  if result == 1
    redirect to {'/home'}
  else
    redirect to {'/rent'}
  end
end

get '/maintenance_request' do
  slim :maintenance_request
end

get '/payment_info' do
  slim :payment_info
end

#management functionalities
get '/application_review' do
  slim :application_review
end

get '/apartment_allot' do
  slim :apartment_allot
end

get '/view_maintenance_req' do
  slim :view_maintenance_req
end

get '/reminders' do
  slim :reminders
end

#reports (management only)

get '/leasing_rep' do
  slim :leasing_rep
end

get '/service_req_res_rep' do   #service request resolution report
  slim :service_req_res_rep
end

get '/defaulters' do
  slim :defaulters
end





#new resident registration and application (combined)


get '/application' do
  slim :application
end

post '/application' do
  query = "INSERT INTO User(Username, Password, Name, DOB, Gender, Role) VALUES
          ('#{params[:username]}',
           '#{params[:password]}',
           '#{params[:name]}',
           '#{params[:dob]}',
           '#{params[:gender]}',
           'Resident');"

  query = "INSERT INTO Resident(Name, Status, Approved, Balance, Payment_status, Move_out_date, DOB, Gender, Monthly_income, Pref_apt_category, Pref_rent_range_min, Pref_rent_range_max, Move_in_date, Lease_term, Previous_address) VALUES
          ('#{params[:name]}',
           'Pending',
           0,
           0.00,
           'Pending',
           '0000-00-00',
           '#{params[:dob]}',
           '#{params[:gender]}',
           '#{params[:monthly_income]}',
           '#{params[:pref_apt_category]}',
           '#{params[:pref_rent_range_min]}',
           '#{params[:pref_rent_range_max]}',
           '#{params[:move_in_date]}',
           '#{params[:lease_term]}',
           '#{params[:previous_address]}'};"
  result = insert(query)
  if result == 1
    #@current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
    redirect to('/home')
  else
    redirect to('/application')
  end
end

