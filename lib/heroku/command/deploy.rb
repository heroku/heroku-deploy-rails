module Heroku::Command
  # automated Rails-based deploys
  #
  class Deploy < BaseWithApp

    # deploy
    #
    # Deploy the current branch
    #
    # A deploy wraps a push + migrate while toggling the maintenance page.
    # Confirmation is required prior to pushing.
    #
    # -f, --force      # force push if heroku rejects the push
    #
    def index
      # selected_application returns the app specified by --app or the default
      push_with_confirmation(app)
    end

    Heroku::Command::Base.new.send(:git_remotes).each do |name, app|
      next if instance_methods.include?(name.to_sym)
      define_method(name) do
        push_with_confirmation(app)
      end
      help = {
        :summary => " Deploy the current branch to #{name} (app: #{app})",
        :description => " A deploy wraps a push + migrate while toggling the maintenance page.\n Confirmation is required prior to pushing."
      }
      help[:help] = ["deploy:#{name}", help[:summary], help[:description]].join("\n\n")
      Heroku::Command.commands["deploy:#{name}"].merge!(help)
    end

private ######################################################################

    def push_with_confirmation(app)
      remote = git_remotes.invert[app]
      raise CommandFailed, "Unknown application" unless remote

      display "This will push the #{current_branch} branch to the application #{app}"

      # confirm prompts for yes/no
      if confirm
        run_command "maintenance:on", ["--app", app]

        if git_push(remote, current_branch)
          display "Running Migrations"
          run_command "run:rake", ["db:migrate", "--app", app]
          run_command "ps:restart", ["--app", app]
        end

        run_command "maintenance:off", ["--app", app]
      end
    end

    # gets the current git branch
    def current_branch
      %x{ git branch -a }.split("\n").detect { |b| b =~ /^\*/ }[2..-1]
    end

    # push to git, return boolean success
    def git_push(remote, branch)
      command = ["git", "push"]
      if options[:force]
        command << "--force"
      end
      command << [remote, "#{branch}:master"]
      display "Pushing repository"
      run_local_command command
    end

    def run_local_command(*args)
      args.flatten!
      begin
        PTY.spawn(*args) do |stdout, stdin, pid|
          begin
            stdout.each { |line| puts line.chomp }
          rescue Errno::EIO
            # ignore EIO errors, as they do not influence the result
          end
          Process.wait(pid)
        end
        $?.exitstatus == 0
      rescue PTY::ChildExited
        false
      end
    end

  end

end
