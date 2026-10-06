# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'rsyncnow'
  # Must match the tag of a GitHub release (tag v1.0.0 for version 1.0.0)
  s.version     = '1.0.0'
  s.summary     = 'Fast rsync indexing/syncing for enormous data sets'
  s.description = 'Runs rsync processes which find the files to sync, and ' \
                  'syncs those files with other rsync processes as soon as ' \
                  'they are found, instead of waiting for the index of all ' \
                  'files to be built first.'
  s.authors     = ['Davor Ocelic']
  s.email       = ['docelic@crystallabs.io']
  s.homepage    = 'https://github.com/docelic/rsyncnow'
  s.license     = 'AGPL-3.0-only'
  s.metadata    = {
    'source_code_uri' => s.homepage,
    'bug_tracker_uri' => "#{s.homepage}/issues"
  }

  # The whole program is the script in the top directory (executables are
  # added to files automatically)
  s.files       = ['README.md', 'LICENSE']
  s.bindir      = '.'
  s.executables = ['rsyncnow']

  # Not a default gem since Ruby 3.4
  s.add_dependency 'getoptlong', '~> 0.1'

  s.requirements << 'rsync'
end
