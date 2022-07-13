require 'redmine'
require 'github_commit_logger_journal_patch'


Redmine::Plugin.register :github_commit_logger do
  name        'Github Commit Logger'
  author      'Matt Smith'
  description "When Github tries to updates an issue, create a changeset instead."
end
