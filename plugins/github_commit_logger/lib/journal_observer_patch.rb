# patch the journal observer to handle updates from github
module JournalObserverPatch

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable # prevent unloading in development mode
    end
  end


  module InstanceMethods


    # TODO: Move this to a settings page for this plugin
    GITHUB_USERNAME = 'github'


    # Convert github updates into Changesets
    def before_create(journal)

      if journal.user.login == GITHUB_USERNAME
        create_changeset(journal)
        return false # don't create the journal entry
      end

      return true # let normal journal entries pass
    end


    private


    def create_changeset(journal)
      commit = parse_commit_message(journal.notes)

      Changeset.create(
        :repository   => journal.issue.project.repository,
        :revision     => commit[:sha],
        :scmid        => commit[:sha],
        :committer    => commit[:author],
        :committed_on => commit[:time],
        :comments     => commit[:message]
      )
    end


    def parse_commit_message(notes)
      message = []
      commit  = {}
      logging = false

      notes.split("\n").each_with_index do |line|
        line = line.strip

        if logging
          message.push(line) unless line == "-----------"
          next
        end

        if    line =~ /^Commit:(.*)/  then commit[:sha]     = $1.strip
        elsif line =~ /^Author:(.*)/  then commit[:author]  = $1.strip
        elsif line =~ /^Date:(.*)/    then commit[:time]    = Time.parse($1.strip)
        elsif line =~ /^Log Message:/ then logging = true
        end
      end

      commit[:message] = message.join("\n")

      return commit
    end


  end

end

