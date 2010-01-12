module Heroku::Command
  class Deploy < Base

    # heroku deploy
    def index
      push_with_confirmation selected_application
    end

    # build heroku deploy:<remote>
    applications.each do |app, remote|
      define_method remote do
        push_with_confirmation app
      end
    end

private ######################################################################

    def push_with_confirmation(app)
      raise CommandFailed, "Unknown application" unless applications[app]

      display "This will push the #{current_branch} branch to the application #{app}"

      remote = applications[app]

      if confirm
        command "maintenance:on", "--app", app

        if git_push(remote, current_branch)
          display "Running Migrations"
          command :rake, "db:migrate", "--app", app
          command :restart,            "--app", app
          command "maintenance:off",   "--app", app
        end
      end
    end

    def current_branch
      %x{ git branch -a }.split("\n").detect { |b| b =~ /^\*/ }[2..-1]
    end

    def git_push(remote, branch)
      command = "git push #{remote} #{branch}:master"
      puts "Executing: #{command}"
      puts %x{ #{command} 2>&1 }
      $?.exitstatus == 0
    end

## help ######################################################################

   Help.group 'Deployment' do |group|

     # create a default deploy task for the default app if one exists
     app = selected_application
     group.command 'deploy', "Deploy your application #{app} app" if app

     # create a deploy task for each recognized app remote
     applications.each do |app, remote|
       group.command "deploy:#{remote}", "Deploy to the #{app} app"
     end

   end if applications.length > 0

  end

end