class Uploader::UploadsController < ApplicationController

  session :cookie_only => false, :only => :swfupload

  before_filter :get_parent, :only => [:create, :swfupload]
  before_filter :set_upload_for_destroy, :only => [:destroy]
  skip_before_filter :verify_authenticity_token
  
  def create
    
    # Standard, one-at-a-time, upload action
    @upload = @parent.uploads.build(params[:upload])
    @upload.creator = current_user
    @upload.save!
    message = t('uploader.successful_upload')
    upload_json = basic_uploads_json(@upload)
    
    respond_to do |format|
      format.html do
        flash[:notice] = message
        redirect_to redirect_back_or_default(get_redirect)
      end            
      format.js do
        responds_to_parent do
          render :update do |page|
            page << "upload_file_callback('#{upload_json}');"
          end
        end
      end      
    end
  rescue => ex
    message = t('uploader.standard_file_upload_error', :error => ex)
    respond_to do |format|
      format.html do
        flash[:notice] = message
        redirect_back_or_default(get_redirect)
      end
      format.js do
        responds_to_parent do
          render :update do |page|
            page << "upload_file_fail_callback('#{message}');"
          end
        end
      end
    end
  end

  def swfupload
    @upload = @parent.uploads.build
    @upload.is_public = true if params[:is_public] == true
    @upload.creator = current_user
    @upload.swfupload_local = params[:Filedata]
    @upload.save!
    
    @parent.uploads << @upload

    respond_to do |format|
      format.json do
        render :text => basic_uploads_json(@upload)
      end
    end
  rescue => ex
    render :text => t("uploader.file_upload_error")
  end

  def destroy
    @parent = @upload.uploadable # set this for redirect
    if @upload.can_edit?(current_user)
      @upload.destroy 
      msg = t('uploader.file_deleted')
    else
      msg = t("uploader.file_delete_permission_denied")
    end
    
    respond_to do |format|
      format.html do
        flash[:notice] = msg
        redirect_back_or_default(get_redirect)
      end
      format.js { render :text => msg }
    end
  
  end
    
  protected
  
  def set_upload_for_destroy
    @upload = Upload.find(params[:id])
  end
  
  def permission_denied
    msg = t("uploader.permission_denied")
    respond_to do |format|
      format.html do
        flash[:notice] = msg
        redirect_to get_redirect
      end
      format.js do
        render :text => msg
      end
    end
  end

  # override this method in your controller to set the redirect file upload completion
  # alternatively set redirect_back_or_default
  def get_redirect
    @parent
  end
  
  def get_parent
    if !params[:parent_type] || !params[:parent_id]
      raise t('uploader.missing_parent_id_error')
      return
    end
    @klass = params[:parent_type].to_s.capitalize.constantize
    @parent = @klass.find(params[:parent_id])
    unless has_permission_to_upload(current_user, @parent)
      permission_denied
    end
  end
  
  def has_permission_to_upload(user, upload_parent)
    upload_parent.can_upload?(user)
  end
  
  def basic_uploads_json(upload)
    upload.to_json(:only => [:id, :data_file_name], :methods => [:icon])
  end
  
end