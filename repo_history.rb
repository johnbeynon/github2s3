#!/usr/bin/ruby

# Amazon S3 credentials
AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']

# S3 Bucket to place backups in
S3_BUCKET = ENV['S3_BUCKET']

# Github credentials
GITHUB_USERNAME = ENV['GITHUB_USERNAME']
GITHUB_PASSWORD = ENV['GITHUB_PASSWORD']

# Github Organisation name to backup
GITHUB_ORGANISATION_NAME = ENV['GITHUB_ORGANISATION_NAME']

# Github options
USE_SSL = true

require 'rubygems'
require 'fileutils'
require  'aws/s3'
require 'Json'
require 'time'
require 'github_api'

AWS::S3::Base.establish_connection!(
    :access_key_id     => AWS_ACCESS_KEY_ID,
    :secret_access_key => AWS_SECRET_ACCESS_KEY,
    :use_ssl => USE_SSL
  )

class Bucket < AWS::S3::Bucket
end

class S3Object < AWS::S3::S3Object
end

def list_repos_from_github 
  github = Github.new login: GITHUB_USERNAME, password: GITHUB_PASSWORD
  repos = github.repos.list org: GITHUB_ORGANISATION_NAME

  while repos.has_next_page?
    repos.each do |repo| 
      last_pushed = Date.parse(repo['pushed_at'])
      puts "#{repo['name']},#{last_pushed}"
    end
    repos = repos.next_page
  end
end

begin
	list_repos_from_github
ensure	
end
