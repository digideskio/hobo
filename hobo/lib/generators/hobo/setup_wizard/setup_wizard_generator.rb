require 'generators/hobo_support/thor_shell'
module Hobo
  class SetupWizardGenerator < Rails::Generators::Base

    source_root File.expand_path('../templates', __FILE__)

    include Generators::Hobo::Helper
    include Generators::HoboSupport::ThorShell
    include Generators::Hobo::InviteOnly
    include Generators::Hobo::TestOptions

    def self.banner
      "rails generate hobo:test_framework NAME [options]"
    end

    class_option :main_title, :type => :boolean,
    :desc => "Shows the main title", :default => true

    class_option :wizard, :type => :boolean,
    :desc => "Ask instead using options", :default => true

    class_option :user_resource_name, :type => :string,
    :desc => "User Resource Name", :default => 'user'

    class_option :front_controller_name, :type => :string,
    :desc => "Front Controller Name", :default => 'front'

    class_option :admin_subsite_name, :type => :string,
    :desc => "Admin Subsite Name", :default => 'admin'

    class_option :migration_generate, :type => :boolean,
    :desc => "Generate migration only"

    class_option :migration_migrate, :type => :boolean,
    :desc => "Generate migration and migrate"

    class_option :default_locale, :type => :string,
    :desc => "Sets the default locale"

    class_option :git_repo, :type => :boolean,
    :desc => "Create the git repository with the initial commit"


    def startup
      if wizard?
        say_title options[:main_title] ? 'Hobo Setup Wizard' : 'Startup'
        say 'Installing basic Hobo Files...'
      end
      template  'application.dryml.erb', 'app/views/taglibs/application.dryml'
      copy_file 'application.css',       'public/stylesheets/application.css'
      copy_file 'dryml-support.js',      'public/javascripts/dryml-support.js'
      copy_file 'guest.rb',              'app/model/guest.rb'
    end

    def choose_test_framework
      if wizard?
        say_title 'Test Framework'
        return unless yes_no? "Do you want to customize the test_framework?"
        require 'generators/hobo/test_framework/test_framework_generator'
        f = Hobo::TestFrameworkGenerator::FRAMEWORKS * '|'
        test_framework = choose("Choose your preferred test framework: [<enter>=#{f}]:", /^(#{f})$/, 'test_unit')
        fixtures = yes_no?("Do you want the test framework to generate the fixtures?")
        fixture_replacement = ask("Type your preferred fixture replacement or <enter> for no replacement:")
      else
        # return if it is all default so no invoke is needed
        return if (options[:test_framework] == 'test_unit' && options[:fixtures] && options[:fixture_replacement].blank?)
        test_framework = options[:test_framework]
        fixtures = options[:fixtures]
        fixture_replacement = options[:fixture_replacement]
      end
      invoke 'hobo:test_framework', [test_framework], :fixture_replacement => fixture_replacement, :fixtures => fixtures
    end

    def invite_only_option
      if wizard?
        say_title 'Invite Only Option'
        return unless (@invite_only = yes_no?("Do you want to add the features for an invite only website?"))
        say %(
Invite-only website
  If you wish to prevent all access to the site to non-members, add 'before_filter :login_required'
  to the relevant controllers, e.g. to prevent all access to the site, add

    include Hobo::AuthenticationSupport
    before_filter :login_required

  to application_controller.rb (note that the include statement is not required for hobo_controllers)

  NOTE: You might want to sign up as the administrator before adding this!
), Color::YELLOW
      else
        @invite_only = invite_only?
      end
    end

    def rapid
      if wizard?
        say_title 'Hobo Rapid'
        say 'Installing Hobo Rapid and default theme...'
      end
      invoke 'hobo:rapid', [], :invite_only => @invite_only
    end

    def user_resource
      if wizard?
        say_title 'User Resource'
        @user_resource_name = ask("Choose a name for the user resource [<enter>=user|<custom_name>]:", 'user')
        say "Installing '#{@user_resource_name}' resources..."
      else
        @user_resource_name = options[:user_resource_name]
      end
      invoke 'hobo:user_resource', [@user_resource_name], :invite_only => @invite_only
    end

    def front_controller
      if wizard?
        say_title 'Front Controller'
        front_controller_name = ask("Choose a name for the front controller [<enter>=front|<custom_name>]:", 'front')
        say "Installing #{front_controller_name} controller..."
      else
        front_controller_name = options[:front_controller_name]
      end
      invoke 'hobo:front_controller', [front_controller_name], :invite_only => @invite_only
    end

    def admin_subsite
      if wizard?
        say_title 'Admin Subsite'
        admin = @invite_only ? true : yes_no?("Do you want to add an admin subsite?")
        return unless admin
        admin_subsite_name = ask("Choose a name for the admin subsite [<enter>=admin|<custom_name>]:", 'admin')
        say "Installing admin subsite..."
      else
        admin_subsite_name = options[:admin_subsite_name]
      end
      invoke 'hobo:admin_subsite', [admin_subsite_name, @user_resource_name], :invite_only => @invite_only
    end

    def migration
      if wizard?
        say_title 'DB Migration'
        action = choose('Initial Migration: [s]kip, [g]enerate migration file only, generate and [m]igrate [s|g|m]:', /^(s|g|m)$/)
        opt = case action
              when 's'
                return say('Migration skipped!')
              when 'g'
                {:generate => true}
              when 'm'
                {:migrate => true}
              end
        say action == 'g' ? 'Generating Migration...' : 'Migrating...'
      else
        return if options[:migration_generate].blank? && options[:migration_migrate].blank?
        opt = options[:migration_migrate].blank? ? {:generate => true} : {:migrate => true}
      end
      invoke 'hobo:migration', ['initial_migration'], opt
    end

    def i18n
      if wizard?
        say_title 'I18n'
        locales = Hobo::Engine.paths.config.locales.paths.map do |l|
          l =~ /hobo\.([^\/]+)\.yml$/
          $1.to_sym.inspect
        end
        say "The available Hobo internal locales are #{locales * ', '} (please, contribute to more translations)"
        default_locale = ask "Do you want to set a default locale? Type the locale or <enter> to skip:"
      else
        default_locale = options[:default_locale]
      end
      return if default_locale.blank?
      default_locale.gsub!(/\:/, '')
      environment "config.i18n.default_locale = #{default_locale.to_sym.inspect}"
      say "NOTICE: You should manually install in 'config/locales' the Rails locale file(s) that your application will use.", Color::YELLOW
    end

    def git_repo
      if wizard?
        say_title 'Git Repository'
        return unless yes_no?("Do you want to initialize a git repository now?")
        say 'Initializing git repository...'
      else
        return unless options[:git_repo]
      end
      hobo_routes_rel_path = Hobo::Engine.config.hobo.routes_path.relative_path_from Rails.root
      append_file '.gitignore', "app/views/taglibs/auto/**/*\n#{hobo_routes_rel_path}\n"
      git :init
      git :add => '.'
      git :commit => '-m "initial commit"'
      say "NOTICE: If you change the config.hobo.routes_path, you should update the .gitignore file accordingly.", Color::YELLOW
    end

    def cleanup_app_template
      say_title 'Cleanup' if wizard?
      # remove the template if one
      remove_file File.join(File.dirname(Rails.root), ".hobo_app_template")
    end

    def finalize
      return unless wizard?
      say_title 'Process completed!'
      say %(You can start your application with `rails server`
(run with --help for options). Then point your browser to
http://localhost:3000/

Follow the guidelines to start developing your application.
You can find the following resources handy:

* The Getting Started Guide: http://guides.rubyonrails.org/getting_started.html
* Ruby on Rails Tutorial Book: http://www.railstutorial.org/
)
end

private

  def wizard?
    options[:wizard]
  end

  end
end
