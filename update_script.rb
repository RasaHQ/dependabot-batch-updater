# This script is designed to be copied into an interactive Ruby session, to
# give you an idea of how the different classes in Dependabot Core fit together.
#
# It's used regularly by the Dependabot team to manually debug issues, so should
# always be up-to-date.

require "dependabot/file_fetchers"
require "dependabot/file_parsers"
require "dependabot/update_checkers"
require "dependabot/file_updaters"
require "dependabot/omnibus"
require "/dist/src/pull_request_creator"
require "/dist/src/file_updaters"

if ARGV.length != 5
  abort("Arguments need to be specified. See `README.md` for the details.")
end

token = ARGV[0]
repo_name = ARGV[1]
directory = ARGV[2]
# Name of the package manager you'd like to do the update for. Options are:
# - bundler
# - pip (includes pipenv)
# - npm_and_yarn
# - maven
# - gradle
# - cargo
# - hex
# - composer
# - nuget
# - dep
# - go_modules
# - elm
# - submodules
# - docker
# - terraform
package_manager = ARGV[3]
batch_size = ARGV[4].to_i

# GitHub credentials with write permission to the repo you want to update
# (so that you can create a new branch, commit and pull request).
# If using a private registry it's also possible to add details of that here.
credentials =
  [{
    "type" => "git_source",
    "host" => "github.com",
    "password" => "xxx"
  }]


source = Dependabot::Source.new(
  provider: "github",
  repo: repo_name,
  directory: directory,
  branch: nil
)

##############################
# Fetch the dependency files #
##############################
fetcher = Dependabot::FileFetchers.for_package_manager(package_manager).
          new(source: source, credentials: credentials)

files = fetcher.files
commit = fetcher.commit

##############################
# Parse the dependency files #
##############################
parser = Dependabot::FileParsers.for_package_manager(package_manager).new(
  dependency_files: files,
  source: source,
  credentials: credentials,
)

dependencies = parser.parse
number_of_updated_dependencies = 0
deps = []
updater = nil

dependencies.select(&:top_level?).each do |dep|
  break if number_of_updated_dependencies == batch_size

  checker = Dependabot::UpdateCheckers.for_package_manager(package_manager).new(
      dependency: dep,
      dependency_files: files,
      credentials: credentials,
  )

  next if checker.up_to_date?

  requirements_to_unlock =
      if !checker.requirements_unlocked_or_can_be?
        if checker.can_update?(requirements_to_unlock: :none)
          :none
        else
          :update_not_possible
        end
      elsif checker.can_update?(requirements_to_unlock: :own) then
        :own
      elsif checker.can_update?(requirements_to_unlock: :all) then
        :all
      else
        :update_not_possible
      end

  next if requirements_to_unlock == :update_not_possible

  updated_deps = checker.updated_dependencies(requirements_to_unlock: :own)

  print "- Updating #{dep.name} (from #{dep.version})\n"
  deps = deps | updated_deps
  number_of_updated_dependencies = number_of_updated_dependencies + 1

  updater = Dependabot::FileUpdaters.for_package_manager(package_manager).new(
      dependencies: updated_deps,
      dependency_files: files,
      credentials: credentials,
  )

  updated_files = updater.updated_dependency_files
  updated_files_names = updated_files.map { |file| file.name }
  other_files = files.select { |file| not updated_files_names.include?(file.name) }
  files = other_files | updated_files
end

if updater
  # we might need to update the lockfile
  # after we finish updating all the dependencies
  files = updater.finalize
end

if number_of_updated_dependencies > 0
  print "Create PR...\n"
  pr_creator = Dependabot::MultipleDepsPullRequestCreator.new(
      source: source,
      base_commit: commit,
      dependencies: deps,
      files: files,
      credentials: credentials,
      label_language: true,
  )
  pr_creator.create
end