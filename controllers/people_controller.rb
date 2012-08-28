class PeopleController < ApplicationController

  def index
	@managers=User.find_all_by_role_and_company_id(2,@current_user.company_id,:limit=>8)
	@manager_count=User.find_all_by_role_and_company_id(2,@current_user.company_id).count
	@workers=User.find_all_by_role_and_company_id(3,@current_user.company_id,:limit=>8)
	@worker_count=User.find_all_by_role_and_company_id(3,@current_user.company_id).count
	@client=Client.find_all_by_company_id(@current_user.company_id,:limit=>8,:order=>'organization asc')
	@client_count=Client.find_all_by_company_id(@current_user.company_id).count
	@page_title = 'PEOPLE'
  end
  
  def delete
	# Validate and delete the user 
	user=User.find_by_id_and_company_id(params[:id],@current_user.company_id)
	unless user.nil?
		if current_user.can_delete?(user)
			# If current user can delete user
			if current_user.id==user.id
				user.destroy
				redirect_to(:controller=>'company',:action=>'logout') and return
			else
				user.destroy
			end
		else
			# invalid operation
			return error_redirect
		end
		flash[:notice]="User deleted successfully"
		redirect_to(:controller=>'people',:action=>'index') and return
	else
		flash[:error]="User doesn't exist"
		redirect_to(:controller=>'people',:action=>'index') and return
	end
	render nil
  end
  
  def list
	roles=user_type_front
	roles=roles.invert
	role_id=params[:view].to_i()
	@role=roles[role_id]
	unless @role.nil?
		@users=User.find_all_by_role_and_company_id(role_id,@current_user.company_id)
	else
		redirect_to (:controller=>'people',:action=>'index') and return
	end
  end
  
  def add
  
	unless session[:user][:role] < 3
		return error_redirect
	end
	if request.post?
		string=random_string
		params[:user][:password]=string
		params[:user][:password_confirmation]=string
		@user=User.new(params[:user])
		@user.role=params[:user][:role].to_i()
		@user.company_id=@current_user.company_id
		if current_user.can_create?(@user)
			if @user.save()
				# Sending Email
				# Assigning back unhashed password to send in email
				@user.password=string
				Notifier.deliver_signup_notification(@user)
				redirect_to (:controller=>'people',:action=>'index') and return
			end
		else
			# invalid operation
			return error_redirect
		end
	end
	@role=user_type_front
	@page_title = 'NEW PERSON'
	render 'user'
  end
  
  def edit
	# Validate and edit the user 
	if !params[:id].nil?
		id=params[:id]
	elsif !params[:user].nil? && !params[:user][:id].nil?
		id=params[:user][:id]
	end
	
	if( @current_user.role==0)
		@user=User.find_by_id(id)
	else
		@user=User.find_by_id_and_company_id(id,@current_user.company_id)
	end
	
	unless @user
		flash[:error]="There is some problem accessing user data"
		redirect_to (:controller=>'people',:action=>'index') and return	
	end
	if current_user.can_edit?(@user)
	# If current user can edit user
		if request.post?
				@user.update_attributes(:first_name => params[:user][:first_name],:last_name=>params[:user][:last_name],:contact_no=>params[:user][:contact_no],:email=>params[:user][:email])
				if current_user.role == 3 && params[:user][:role].to_i() != 3
					# invalid operation
					return error_redirect 
				end 
				unless current_user.role >= 3
					@user.role=params[:user][:role].to_i()
				end
				if @user.save
					flash[:notice]="Changes saved successfully"
					redirect_to (:controller=>'people',:action=>'index') and return
				end
		end
	else
		# invalid operation
		return error_redirect
	end	
	
	@role=user_type_front
	if(@current_user.role==3)
		@role=@role.invert
		@role.delete(2)
		@role=@role.invert
	end
	@page_title = 'EDIT PERSON'
	render 'user'
  end  
end
