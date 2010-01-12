class Heroku::Command::Deploy < Heroku::Command::Base

  def index
    default_app = Heroku::Util.default_application_name
    raise Heroku::Command::CommandFailed.new('foo') unless default_app
    push_with_confirmation default_app
  end

## help ######################################################################

  def self.build_help
    Heroku::Command::Help.group 'Deployment' do |group|

      # create a default deploy task for the default app if one exists
      app = Heroku::Util.default_application_name
      group.command 'deploy', "Deploy your application #{app} app" if app

      # create a deploy task for each recognized app remote
      Heroku::Util.applications.each do |app, remote|
        group.command "deploy:#{remote}", "Deploy to the #{app} app"
      end
    end
  end

private ######################################################################

  def push_with_confirmation(app)
    display "This will push the #{current_branch} branch to the application #{app}"

    remote = Heroku::Util.applications[app]

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

end
