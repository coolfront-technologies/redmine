require 'redmine'
require 'journal_observer'


Redmine::Plugin.register :github_commit_logger do
  name        'Github Commit Logger'
  author      'Matt Smith'
  description "When Github tries to updates an issue, create a changeset instead."

  JournalObserver.send(:include, JournalObserverPatch)
end
