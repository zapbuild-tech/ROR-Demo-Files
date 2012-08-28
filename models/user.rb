require "digest/sha1"
class User < ActiveRecord::Base
  
  # Validation Starts
  validates_presence_of :first_name,:contact_no,:email,:password
  validates_format_of :email,   :allow_blank => true, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_format_of :first_name,:last_name, :allow_blank => true, :with => /^[a-zA-Z ]+$/
  validates_uniqueness_of :email,:scope => :company_id,  :allow_nil => true,:on=>:create
  validate :contact_no,:if=>:validate_phone
  validates_confirmation_of :password ,    :allow_nil => true
  validates_presence_of :password_confirmation ,:if => :password_changed?
  validates_length_of :password, :minimum=>6
  validates_length_of :first_name,:last_name, :maximum=>20
  #	Validation Ends
  
  attr_accessible :first_name, :last_name, :contact_no, :email, :password,:password_confirmation
  
  # Associations
  belongs_to :company
  has_many :project,:foreign_key => 'manager_id', :dependent => :destroy
  has_many :jobsheet,:foreign_key => 'worker_id'
  has_many :project_worker,:foreign_key => 'worker_id', :dependent => :destroy
  has_many :jobsheet_note, :dependent => :destroy
  
  # Callback functions
  before_create [:hash_password,:validate_exist_email] 
  before_update [:validate_email_except_own]
  
  # Validate phone number and add different validation message
  def validate_phone
	if self.contact_no.blank?
		return true
	end
	check_space=/[ ]/
	check_number=/[^0-9]/
	check_length=/\A\d{10,15}\z/
	if check_space.match(self.contact_no)
		errors.add(:contact_no,'is invalid, Please do not use spaces when entering a telephone number.')
		return false
	end
	if check_number.match(self.contact_no)
		errors.add(:contact_no, 'should be number')
		return false
	end
	if !check_length.match(self.contact_no)
		errors.add(:contact_no, 'should be between 10-15 digits')
		return false
	end
	return true
  end
 
  # Get all managers for selected project
  def self.managers_for_project(project_id,limit=nil)
	return User.find(:all, :joins => [:project], :conditions => ["projects.id = ? and users.role = ?", project_id,2],:limit=>limit)
  end
  
  # Add different error messages and validate
  def validate_exist_email
	if self.role != 1
		user=User.find(:all,:conditions=>['email = ? AND company_id = ? ',self.email,self.company_id]).count;
		error_msg='has already been taken'
	else
		user=User.find(:all,:conditions=>['email = ? AND role = 1 ',self.email]).count;
		error_msg='has already own another timeline'
	end
	
	unless user <=0
		 errors.add(:email, error_msg)
		return false
	end
  end
  
  # Check uniqueness of the email during modification
  def validate_email_except_own
	user=User.find(:all,:conditions=>['email = ? AND company_id = ? AND id != ?',self.email,self.company_id,self.id]).count;
	unless user <=0
		 errors.add(:email, "has already been taken")
		return false
	end
  end	
  def self.authenticate(email, password,company_id=nil)
    if company_id.nil?
		user = find_by_email(email)
    else
    	user = find_by_email_and_company_id(email,company_id)
    end
    if user && user.valid_password?(password)
      user
    else
      nil
    end
  end
  
  def can_be_created_by?(login_user)
     if login_user.role ==3
		return false
     elsif login_user.role ==2
		(login_user.role <= self.role)
     else
		(login_user.role < self.role)
     end
  end
  def can_be_edit_by?(login_user)
    if(login_user.id == self.id)
		return true
    else
		return (login_user.role < self.role) && login_user.role != self.role
	end
  end
  def can_be_delete_by?(login_user)
    if(login_user.id==self.id)
		true
    else
		(login_user.role < self.role) && login_user.role != self.role
	end
  end
  
  # Limit different resources on the application as per User Role 
  def can_create?(resource)
    resource.can_be_created_by?(self)
  end
  
  def can_edit?(resource)
	resource.can_be_edit_by?(self)
  end
  
  def can_view?(resource)
	resource.can_be_view_by?(self)
  end
  
  def can_delete?(resource)
    resource.can_be_delete_by?(self)
  end
  
  
  # Returns true if the password passed matches the password in the DB
  def valid_password?(password)
    self.password == self.class.hash_password(password)
  end
  
  # Sets the hashed version of self.password to password_hash, unless it's blank.
  def hash_password
    self.password = self.class.hash_password(self.password) unless self.password.blank?
  end

  private

  # Performs the actual password encryption. You want to change this salt to something else.
  def self.hash_password(password, salt = "ammyQuTe8Zucijoo7")
    Digest::SHA1.hexdigest(password+salt)
  end

  # Assert wether or not the password validations should be performed. Always on new records, only on existing
  # records if the .password attribute isn't blank.
  def perform_password_validation?
    self.new_record? ? true : !self.password.blank?
  end
end
