require 'rails_admin/abstract_model'

module RailsAdmin
  class ModelNotFound < ::StandardError
  end

  class ObjectNotFound < ::StandardError
  end

  class ApplicationController < ActionController::Base
    # For APIs, you may want to use :null_session instead.
    # protect_from_forgery with: :exception
    force_ssl unless: :should_not_use_ssl?

    rescue_from CanCan::AccessDenied do |exception|
      redirect_to main_app.new_admin_session_path, :alert => exception.message
    end

    newrelic_ignore if defined?(NewRelic) && respond_to?(:newrelic_ignore)

    before_filter :_authenticate!
    before_filter :_authorize!
    before_filter :_audit!

    helper_method :_current_user, :_get_plugin_name

    attr_reader :object, :model_config, :abstract_model

    def get_model
      @model_name = to_model_name(params[:model_name])
      fail(RailsAdmin::ModelNotFound) unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
      fail(RailsAdmin::ModelNotFound) if (@model_config = @abstract_model.config).excluded?
      @properties = @abstract_model.properties
    end

    def get_object
      fail(RailsAdmin::ObjectNotFound) unless (@object = @abstract_model.get(params[:id]))
    end

    def to_model_name(param)
      param.split('~').collect(&:camelize).join('::')
    end

  private

    def should_not_use_ssl?
      Rails.env.development? || Rails.env.test?
    end

    def _get_plugin_name
      @plugin_name_array ||= [RailsAdmin.config.main_app_name.is_a?(Proc) ? instance_eval(&RailsAdmin.config.main_app_name) : RailsAdmin.config.main_app_name].flatten
    end

    def _authenticate!
      instance_eval(&RailsAdmin::Config.authenticate_with)
    end

    def _authorize!
      instance_eval(&RailsAdmin::Config.authorize_with)
    end

    def _audit!
      instance_eval(&RailsAdmin::Config.audit_with)
    end

    def _current_user
      instance_eval(&RailsAdmin::Config.current_user_method)
    end

    alias_method :user_for_paper_trail, :_current_user

    rescue_from RailsAdmin::ObjectNotFound do
      flash[:error] = I18n.t('admin.flash.object_not_found', model: @model_name, id: params[:id])
      params[:action] = 'index'
      index
    end

    rescue_from RailsAdmin::ModelNotFound do
      flash[:error] = I18n.t('admin.flash.model_not_found', model: @model_name)
      params[:action] = 'dashboard'
      dashboard
    end

    def not_found
      render file: Rails.root.join('public', '404.html'), layout: false, status: :not_found
    end

    def rails_admin_controller?
      true
    end

    rescue_from CanCan::AccessDenied do |exception|
      flash[:error] = exception.message
      redirect_to main_app.new_admin_session_url
    end
  end
end
