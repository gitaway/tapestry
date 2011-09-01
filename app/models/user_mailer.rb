class UserMailer < ActionMailer::Base

  def signup_notification(user)
    @url  = "http://#{ROOT_URL}/activate/#{user.activation_code}"
    @user = user
    @recipient = user.email
    @recipient = SEND_ALL_USER_EMAIL_TO if defined? SEND_ALL_USER_EMAIL_TO
    mail(:from => ADMIN_EMAIL,
         :to => @recipient,
         :subject => 'Please activate your new account')
  end

  def error_notification(user,message)
    @user = user
    if @user.nil? then
      @user = User.new()
      @user.first_name = 'Anonymous'
      @user.last_name = 'user'
    end
    @message = message
    mail(:from => SYSTEM_EMAIL,
         :to => SYSTEM_EMAIL,
         :subject => "Critical error at #{ROOT_URL}")
  end

  def delete_request(user)
    if defined? WITHDRAWAL_NOTIFICATION_EMAIL
      @recipients = "#{WITHDRAWAL_NOTIFICATION_EMAIL}"
    else
      @recipients = "#{ADMIN_EMAIL}"
    end
    setup_email
    @subject     = "PGP account deletion request"
    @body[:url]  = "http://#{ROOT_URL}/admin/users"
    @body[:user] = user
    user.log("PGP account deletion request")
  end

  def password_reset(user)
    setup_email(user)
    @subject    += 'Reset your password'
    @body[:url]  = edit_password_url(:id => user.id, :key => user.crypted_password)
    user.log("Sent password reset link: #{@body[:url]}")
  end

  def family_relation_notification(family_relation)
    setup_email(family_relation.relative)
    @subject += 'You have been added as a family member'
    @family_relation = family_relation
    @body[:url] = "http://#{ROOT_URL}/family_relations"
    @body[:login_url]  = "http://#{ROOT_URL}/login"
    family_relation.relative.log("Sent family relation notification: added as a family member (#{@family_relation.relation}) by #{@family_relation.user.hex}")
  end

  def family_relation_rejection(family_relation)
    setup_email(family_relation.user)
    @subject += 'Your family relation request was rejected'
    @body[:user] = family_relation.relative
    family_relation.user.log("Sent family relation notification: family relation request was rejected by #{family_relation.relative.hex}")
  end

  def family_relation_deletion(family_relation)
    setup_email(family_relation.user)
    @subject += 'Your family relation was deleted'
    @body[:user] = family_relation.relative
    family_relation.user.log("Sent family relation notification: family relation was deleted by #{family_relation.relative.hex} (#{FamilyRelation::relations[family_relation.relation]})")
  end

  def safety_questionnaire_reminder(user)
    setup_email(user)
    @subject += 'PGP Safety Questionnaire'
    # DO NOT modify the user.log line below without also modifying script/send_safety_questionnaire_reminders.rb which depends on it!
    user.log("Sent PGP Safety Questionnaire Reminder")
  end

  def enrollment_decision_notification(user)
    setup_email(user)
    @subject += 'PGP Enrollment decision'
    user.log("Sent PGP Enrollment decision notification")
  end

  def withdrawal_notification(user)
    setup_email(user)
    @subject += 'PGP withdrawal'
    user.log("Sent PGP withdrawal notification")
  end

  def withdrawal_staff_notification(user)
    if defined? WITHDRAWAL_NOTIFICATION_EMAIL
      @recipients = "#{WITHDRAWAL_NOTIFICATION_EMAIL}"
    else
      @recipients = "#{ADMIN_EMAIL}"
    end
    setup_email
    @subject += 'PGP withdrawal'
    @body[:user] = user
  end

  protected

  def setup_email(user=nil)
    @recipients  = "#{user.email}" if user
    @from        = "#{ADMIN_EMAIL}"
    @subject     = "[#{ROOT_URL}] "
    @sent_on     = Time.now
    @body[:user] = user if user
    @recipients = SEND_ALL_USER_EMAIL_TO if defined? SEND_ALL_USER_EMAIL_TO
  end
end
