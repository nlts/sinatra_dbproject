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

configure do
  @@user = ""
  @@apartment_number = ""
  @@role = ""
end


get '/' do
  redirect to ('/login')
end

get '/login' do
  slim :login
end

post '/login' do
  query = "SELECT Username, Role
           FROM User
           WHERE ('#{params[:username]}' = Username AND '#{params[:password]}' = Password);"
  user = select(query)

  if user.empty?
    redirect to('/login')
  elsif user[0]["Role"] === "Manager" or user[0]["Role"] === "Administrator"
    redirect to('/management')
  elsif user[0]["Role"] === "Resident"
    status_query = "SELECT Status FROM Resident WHERE ('#{params[:username]}' = Username)"
    status = select(status_query)
    if status.empty?
      redirect to('/login')
    elsif status[0]["Status"] === "Prospective"
      slim :under_review
    elsif status[0]["Status"] === "Rejected"
      slim :rejected
    elsif status[0]["Status"] === "Resident"
      @@user = user[0]["Username"]
      @@role = user[0]["Role"]
      redirect to('/home')
    end
  else
    redirect to('/login')
  end
end


#new resident registration and application (combined)

get '/application' do
  slim :application
end

post '/application' do
  user_query = "INSERT INTO User(Username, Password, Name, DOB, Gender, Role) VALUES
               ('#{params[:username]}',
               '#{params[:password]}',
               '#{params[:name]}',
               '#{params[:dob]}',
               '#{params[:gender]}',
               'Resident');"

  old_resident_query = "INSERT INTO Resident(Username, Status, Lease_term, Monthly_income, Move_in_date, Pref_apt_category, Pref_rent_range_min, Pref_rent_range_max, Date_of_application, Previous_address, Approved, Balance, Payment_status, Move_out_date) VALUES
          ('#{params[:username]}',
           'Prospective',
           '#{params[:lease_term]}',
           '#{params[:monthly_income]}',
           '#{params[:move_in_date]}',
           '#{params[:pref_apt_category]}',
           '#{params[:pref_rent_range_min]}',
           '#{params[:pref_rent_range_max]}',
           '1994-02-02',
           '#{params[:previous_address]}',
           '0',
           '0.00',
           'Not yet approved',
           '#{params[:move_in_date]}');"
  resident_query = "INSERT INTO Resident(Username, Status, Lease_term,
                   Monthly_income, Move_in_date, Pref_apt_category, Pref_rent_range_min,
                   Pref_rent_range_max, Date_of_application, Previous_address, Approved, Balance,
                   Payment_status, Move_out_date) VALUES ('#{params[:username]}', 'Prospective',
                   '#{params[:lease_term]}', '#{params[:monthly_income]}', '#{params[:move_in_date]}',
                   '#{params[:pref_apt_category]}', '#{params[:pref_rent_range_min]}', '#{params[:pref_rent_range_max]}', CURDATE(), '#{params[:previous_address]}',
                   (CASE WHEN '#{params[:move_in_date]}' > CURDATE()+ INTERVAL 2 MONTH
                   THEN 'Rejected'
                   WHEN EXISTS(SELECT 1 FROM Apartment
                   WHERE Apartment.Category = '#{params[:pref_apt_category]}'
                   and Apartment.Date_available > '#{params[:move_in_date]}')
                   and '#{params[:monthly_income]}' > (SELECT Apartment.Rent FROM Apartment
                   WHERE Apartment.Category = '#{params[:pref_apt_category]}'
                   and Apartment.Date_available > '#{params[:move_in_date]}'
                   ORDER BY Apartment.Rent ASC Limit 1) * 3 THEN 'Approved'
                   ELSE 'Rejected'
                   END),
                   0.00,
                   'Current',
                   NULL)"
  user_result = insert(user_query)
  if user_result == 1
    resident_result = insert(resident_query)
  end
  if user_result == 1 && resident_result == 1
    @@user = params[:username]
    @@dob = params[:dob]
    @@role = 'Resident'
    slim :under_review
  else
    # register failed - display message?
    redirect to('/application')
  end

end

# get '/register' do
#   slim :register
# end
#
# post '/register' do
#   query = "INSERT INTO User(Username, Password, DOB, Role) VALUES
#           ('#{params[:username]}',
#            '#{params[:password]}',
#            '#{params[:confirm_password]}',
#            'Resident');"
#   result = insert(query)
#   if (result == 1 & (params[:password] == params[:confirm_password]))
#     #@current_user = {username: user[0]["Username"], dob: params[:dob], role: user[0]["Role"] }
#     redirect to('/application')
#   else
#     redirect to('/register')
#   end
# end

get '/home' do
  @user = @@user
  @role = @@role
  apartment_query = "SELECT Apartment_num FROM Apartment A
                     WHERE A.Tenant = '#{@user}'"
  result = select(apartment_query)
  @@apartment_number = result[0]["Apartment_num"]
  @apartment_number = @@apartment_number

  # check role and status
  # get messages count
  messages_query = "SELECT Apartment_num, COUNT(*) FROM Reminder R
                    WHERE R.Apartment_num = '#{@apartment_number}'"
  messages_result = select(messages_query)
  @messages_count = messages_result[0]["COUNT(*)"]

  slim :home
end

#2 different homepage layouts, one for resident and one for management
#Resident can click "Pay Rent", "Request Maintenance", or "Payment Information" and has a notification when they have a message
#Management can click "Application Review", "Maintenance Requests", "Rent Reminder", or choose a report from a dropdown menu

#resident functionalities
get '/rent' do
  apartment_query = "SELECT Apartment_num FROM Apartment A WHERE A.Tenant = '#{@@user}'"
  @apartment_number = select(apartment_query)
  @apartment_number = @apartment_number[0]["Apartment_num"]
  last_4_query = "SELECT Last_4_digits FROM Credit_Card WHERE Username = '#{@@user}'"
  @last4 = select(last_4_query)
  slim :rent
end

post '/rent' do
  query = "INSERT INTO Rent_Payment(Apartment_num, Month, Year, Date_due, Amount_due,
          Late_fee, Date_paid, Amount_paid, Username, CC_last_4_digits) VALUES
          ('#{params[:apartment_num]}',
           '#{params[:month]}',
           '#{params[:year]}',
           '#{params[:date_due]}',
           CAST('#{params[:amount_due]}' AS DECIMAL(10, 4)),
           '#{params[:late_fee]}',
           CURDATE(),
           CAST('#{params[:amount_due]}' AS DECIMAL(10, 4)),
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
  @date = Time.now.to_date
  apartment_request ="SELECT Apartment_num FROM Apartment A WHERE A.Tenant = '#{@@user}'"
  @apartment_number = select(apartment_request)
  @apartment_number = @apartment_number[0]["Apartment_num"]
  issues_request = "SELECT * FROM Issue"
  @issues = select(issues_request)
  puts @issues

  slim :maintenance_request
end

post '/maintenance_request' do
  @date = Time.now.to_date
  query = "INSERT INTO Maintenance_Request(Apartment_num, Date_time_requested,
          Date_resolved, Status, Issue_type) VALUES
          ('#{params[:apartment_number]}',
           NOW(),
           NULL,
           'Unresolved',
           '#{params[:issue]}');"
  result = insert(query)
  if result == 1
    redirect to('/home')
  end

end

get '/payment_info' do
  last_4_query = "SELECT Last_4_digits FROM Credit_Card WHERE Username = '#{@@user}'"
  @last4 = select(last_4_query)
  slim :payment_info
end

post '/new_card' do
  new_query = "INSERT INTO Credit_Card(Username, Last_4_digits, Name_on_Card, Card_number, Expiration_Date, CVV)
               VALUES ('#{@@user}', '#{params["last_4_digits"]}',
              '#{params["name_on_card"]}', '#{params["card_number"]}',
              '#{params["expiration_date"]}', '#{params["cvv"]}')"
  result = insert(new_query)
  redirect to('/home')
end

post '/delete_card' do
  delete = "DELETE FROM Credit_Card WHERE Username = '#{@@user}'
            AND Last_4_digits = '#{params["last_4_digits"]}'"
  result = insert(delete)
  redirect to('/payment_info')
end
#management functionalities

get '/management' do
  slim :management
end

get '/application_review' do
  query = "SELECT U.Username, U.Name, U.DOB, U.Gender, R.Monthly_income,
          R.Pref_apt_category, R.Move_in_date, R.Lease_term, R.Approved
          FROM Resident R JOIN User U ON U.Username = R.Username
          WHERE R.Status = 'Prospective'"
  @applications = select(query)
  slim :application_review
end

post '/application_review' do
  redirect to("/apartment_allot/#{params["username"]}")
end

get '/apartment_allot/:username' do
  @username = params[:username]
  name_query = "SELECT Name FROM User WHERE Username = '#{@username}'"
  name = select(name_query)
  @name = name[0]["Name"]
  apartment_query = "SELECT A.Apartment_num, A.Date_available, A.Category, A.Square_footage, A.Rent
                    FROM Apartment A, Resident R
                    WHERE Tenant IS NULL
                    AND (SELECT DATEDIFF(R.Move_in_date, A.Date_available)) <= 0
                    AND R.Username = '#{@username}'"
  @apartments = select(apartment_query)
  slim :apartment_allot
end

post '/apartment_allot/:username' do
  @username = params[:username]
  @apartment_number = params['apartment_num']
  update_query = "UPDATE Apartment SET Tenant = '#{@username}' WHERE Apartment_num = '#{@apartment_number}'"
  result = insert(update_query)
  redirect to('/management')
end

get '/view_maintenance_req' do
  unresolved_query = "SELECT MONTHNAME(M.Date_time_requested) AS Month, Date_time_requested, Apartment_num, Issue_type
                    FROM Maintenance_Request M
                    WHERE Status = 'Unresolved'
                    GROUP BY Month, Issue_type"
  @unresolved = select(unresolved_query)
  resolved_query = "SELECT MONTHNAME(M.Date_time_requested) AS Month, Date_time_requested, Apartment_num, Issue_type, Date_resolved
                    FROM Maintenance_Request M
                    WHERE Status = 'Resolved'
                    GROUP BY Month, Issue_type"
  @resolved = select(resolved_query)
  slim :view_maintenance_req
end

post '/view_maintenance_req' do
  apartment_num = params["Apartment_num"]
  date_time_requested = params["Date_time_requested"]

  update_query = "UPDATE Maintenance_Request
   SET Date_resolved = CURDATE(), Status = 'Resolved'
   WHERE Apartment_num = '#{apartment_num}' and Date_time_requested = '#{date_time_requested}'"
  result = insert(update_query)
  redirect to('/view_maintenance_req')
end;

get '/reminders' do
  reminder_query = 'SELECT A.Apartment_num
                    FROM Apartment A
                    WHERE A.Tenant IS NOT NULL
                    AND NOT EXISTS (SELECT * FROM Rent_Payment P
                    WHERE P.Apartment_num = A.Apartment_num
                    AND P.Month = MONTH(CURDATE())
                    AND P.Year = YEAR(CURDATE()))'
  @date = Time.now.to_date
  @apartments = select(reminder_query)
  puts @apartments
  slim :reminders
end

post '/reminders' do
  insert_query = "INSERT INTO Reminder (Apartment_num, Date_time, Subject, Content, Opened_status)
                  VALUES ('#{params['apartment_number']}',
                          NOW(),
                          'Late Rent',
                          '#{params['content']}',
                          'Unopened')"
  result = insert(insert_query)
  redirect to('/management')
end

#reports (management only)

get '/leasing_rep' do
  leasingrep_query = "SELECT MONTHNAME(R.Move_in_date) AS Month, R.Pref_apt_category, COUNT(R.Username) AS 'No of Apartments' FROM Resident R
    GROUP BY MONTHNAME(R.Move_in_date), R.Pref_apt_category
    HAVING Month IN ('August', 'September', 'October')
    ORDER BY Move_in_date;"
  @leasingrep = select(leasingrep_query)
  slim :leasing_rep
end

post '/leasing_rep' do
  month = params["Month"]
  category = params["Category"]
end

get '/service_req_res_rep' do   #service request resolution report
  servicerep_query = "SELECT MONTHNAME(Date_resolved) AS Month, Issue_type, CAST(AVG(DATEDIFF(Date_resolved, DATE(Date_time_requested))) AS UNSIGNED) AS 'Average No of Days'
    FROM Maintenance_Request
    GROUP BY Month, Issue_type
    HAVING Month IN ('August', 'September', 'October')
    ORDER BY Month, Issue_type;"
  @servicerep = select(servicerep_query)
  slim :service_req_res_rep
end

post '/service_req_res_rep' do

end

get '/defaulters' do
  slim :defaulters
end




