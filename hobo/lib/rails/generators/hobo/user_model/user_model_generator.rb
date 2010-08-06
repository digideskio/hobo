module Hobo
  class UserModelGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    def self.banner
      "rails generate hobo:user_model #{self.arguments.map(&:usage).join(' ')} [--invite-only]"
    end

    class_option :invite_only, :type => :boolean

    def generate_user_model
      template 'model.rb.erb', File.join('app/models', "#{file_path}.rb")
    end

    def generate_mailer
      invoke 'hobo:user_mailer', [name], :invite_only => options[:invite_only]
    end

    hook_for :test_framework, :as => :model

  private

    def invite_only?
      options[:invite_only]
    end

  end
end