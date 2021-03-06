require 'fastlane/action'
require_relative '../helper/jira_set_fix_version_helper'

module Fastlane
  module Actions
    module SharedValues
      CREATE_JIRA_VERSION_VERSION_ID = :CREATE_JIRA_VERSION_VERSION_ID
    end

    class JiraSetFixVersionAction < Action

      def self.run(params)
        puts "Running jira_set_fix_version Plugin"
        Actions.verify_gem!('jira-ruby')
        require "jira-ruby"

        site         = params[:url]
        context_path = ''
        auth_type    = :basic
        username     = params[:username]
        password     = params[:password]
        project_name = params[:project_name]
        name         = params[:name]
        description  = params[:description]
        archived     = params[:archived]
        released     = params[:released]
        start_date   = params[:start_date]

        options = {
          username:     username,
          password:     password,
          site:         site,
          context_path: context_path,
          auth_type:    auth_type,
          read_timeout: 120
        }

        client = JIRA::Client.new(options)
        puts "Client created: "
        puts client


        unless project_name.nil?


          puts "Looking for a Project cookie " + project_name
          begin
            project = client.Project.find(project_name)
          rescue JIRA::HTTPError => e
            puts "Error during accesing to Project"
            puts e.response.code
            puts e.response.message
          end

          puts "Project found!"
          project_id = project.id
          puts "Project ID found: " +  project_id
        end

        if start_date.nil?
          start_date = Date.today.to_s
        end

        puts "Looking for Versions"
        version = project.versions.find { |version| version.name == name }
        if version.nil?
          puts "Trying to create a version with name: " + name
          version = client.Version.build
          begin
            version.save!({
              "description" => "",
              "name" => name,
              "archived" => archived,
              "released" => released,
              "startDate" => start_date,
              "projectId" => project_id
              })
              puts "Version saved: " + name
            rescue JIRA::HTTPError => e
              puts "Error during saving a version [" + e.response.code + "]"
              puts e.response.message
            end


          end
          Actions.lane_context[SharedValues::CREATE_JIRA_VERSION_VERSION_ID] = version.id

          if Actions.lane_context[SharedValues::FL_CHANGELOG].nil?
            changelog_configuration = FastlaneCore::Configuration.create(Actions::ChangelogFromGitCommitsAction.available_options, {})
            Actions::ChangelogFromGitCommitsAction.run(changelog_configuration)
          end
          ticket_numbers = Actions.lane_context[SharedValues::FL_CHANGELOG]
          puts "Received ticket numbers: "
          puts ticket_numbers
          #issue_ids = Actions.lane_context[SharedValues::FL_CHANGELOG].scan(/#{project_name}-\d+/i).uniq
          ticket_numbers.each do |issue_id|
            begin
              issue = client.Issue.find(issue_id)
              fixVersions = [version]
              issue.save({"fields"=>{ "fixVersions" => fixVersions }})
            rescue JIRA::HTTPError
              "Skipping issue #{issue_id}"
            end
          end
          version.id
        end

        def self.description
          "Tags all Jira issues mentioned in git changelog with with a fix version from parameter :name"
        end

        def self.authors
          ["Tommy Sadiq Hinrichsen"]
        end

        def self.return_value
          "Return the name of the created Jira version"
        end

        def self.details
          "This action requires jira-ruby gem"
          
        end

        def self.available_options
          [
            FastlaneCore::ConfigItem.new(key: :url,
              env_name: "FL_CREATE_JIRA_VERSION_SITE",
              description: "URL for Jira instance",
              type: String,
              verify_block: proc do |value|
                UI.user_error!("No url for Jira given, pass using `url: 'url'`") unless value and !value.empty?
              end),
              FastlaneCore::ConfigItem.new(key: :username,
                env_name: "FL_CREATE_JIRA_VERSION_USERNAME",
                description: "Username for JIRA instance",
                type: String,
                verify_block: proc do |value|
                  UI.user_error!("No username given, pass using `username: 'jira_user'`") unless value and !value.empty?
                end),
                FastlaneCore::ConfigItem.new(key: :password,
                  env_name: "FL_CREATE_JIRA_VERSION_PASSWORD",
                  description: "Password for Jira",
                  type: String,
                  verify_block: proc do |value|
                    UI.user_error!("No password given, pass using `password: 'T0PS3CR3T'`") unless value and !value.empty?
                  end),
                  FastlaneCore::ConfigItem.new(key: :project_name,
                    env_name: "FL_CREATE_JIRA_VERSION_PROJECT_NAME",
                    description: "Project ID for the JIRA project. E.g. the short abbreviation in the JIRA ticket tags",
                    type: String,
                    optional: true,
                    conflicting_options: [:project_id],
                    conflict_block: proc do |value|
                      UI.user_error!("You can't use 'project_name' and '#{project_id}' options in one run")
                    end,
                    verify_block: proc do |value|
                      UI.user_error!("No Project ID given, pass using `project_id: 'PROJID'`") unless value and !value.empty?
                    end),
                    FastlaneCore::ConfigItem.new(key: :name,
                      env_name: "FL_CREATE_JIRA_VERSION_NAME",
                      description: "The name of the version. E.g. 1.0.0",
                      type: String,
                      verify_block: proc do |value|
                        UI.user_error!("No version name given, pass using `name: '1.0.0'`") unless value and !value.empty?
                      end),
                      FastlaneCore::ConfigItem.new(key: :description,
                        env_name: "FL_CREATE_JIRA_VERSION_DESCRIPTION",
                        description: "The description of the JIRA project version",
                        type: String,
                        optional: true,
                        default_value: ''),
                        FastlaneCore::ConfigItem.new(key: :archived,
                          env_name: "FL_CREATE_JIRA_VERSION_ARCHIVED",
                          description: "Whether the version should be archived",
                          optional: true,
                          default_value: false),
                          FastlaneCore::ConfigItem.new(key: :released,
                            env_name: "FL_CREATE_JIRA_VERSION_CREATED",
                            description: "Whether the version should be released",
                            optional: true,
                            default_value: false),
                            FastlaneCore::ConfigItem.new(key: :start_date,
                              env_name: "FL_CREATE_JIRA_VERSION_START_DATE",
                              description: "The date this version will start on",
                              type: String,
                              is_string: true,
                              optional: true,
                              default_value: Date.today.to_s)
                            ]
                          end

                          def self.is_supported?(platform)
                            true
                          end
                        end
                      end
                    end
