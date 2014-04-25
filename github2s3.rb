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
require "colorize"
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

  def clone_and_upload_to_s3(options)
    puts "\n\nChecking out #{options[:name]} ...".green
    clone_command = "cd #{S3_BUCKET} && git clone --bare #{options[:clone_url]} #{options[:name]}"
    puts clone_command.yellow
    system(clone_command)
    puts "\n Compressing #{options[:name]} ".green
    system("cd #{S3_BUCKET} && tar czf #{compressed_filename(options[:name])} #{options[:name]}")

    upload_to_s3(compressed_filename(options[:name]))
 end

  def backup_exists?(name)
    S3Object.exists? compressed_filename(name), S3_BUCKET
  end

  def backup_object_date(name)
    object = S3Object.find compressed_filename(name), S3_BUCKET
    Time.parse(object.about['last_modified'])
  end

  def need_to_backup?(name, date)
    if !backup_exists?(name)
      puts "Backup doesn't exist".red
      return true
    elsif skip?(name)
      puts "Skipping #{name}"
      return false
    elsif backup_exists?(name) && (backup_object_date(name) < date)
      puts "Backup exists but is older than last push date".red
      puts "Last Backup: #{backup_object_date(name)}".red
      return true
    else
      puts "Backup date: #{backup_object_date(name)}".green
      return false
    end
  end

  def skip?(name)
    ENV['REPOS_TO_SKIP'].include?(name)
  end
 
 def compressed_filename(str)
	 str+".tar.gz"
 end	 
 
 def upload_to_s3(filename)
	 begin
		puts "** Uploading #{filename} to S3".green
		path = File.join(S3_BUCKET, filename)
		S3Object.store(filename, File.read(path), s3bucket)
	 rescue Exception => e
		puts "Could not upload #{filename} to S3".red
		puts e.message.red
	 end
 end
  
def delete_dir_and_sub_dir(dir)
  Dir.foreach(dir) do |e|
    # Don't bother with . and ..
    next if [".",".."].include? e
    fullname = dir + File::Separator + e
    if FileTest::directory?(fullname)
      delete_dir_and_sub_dir(fullname)
    else
      File.delete(fullname)
    end
  end
  Dir.delete(dir)
end

def ensure_bucket_exists
	 begin
		bucket = Bucket.find(s3bucket)
	 rescue AWS::S3::NoSuchBucket => e
		puts "Bucket '#{s3bucket}' not found."
		puts "Creating Bucket '#{s3bucket}'. "
		
		begin 
			Bucket.create(s3bucket)
			puts "Created Bucket '#{s3bucket}'. "
		rescue Exception => e
			puts e.message
		end
	 end
 
 end

def s3bucket
	s3bucket = S3_BUCKET 
end

def backup_repos_from_github 
  github = Github.new login: GITHUB_USERNAME, password: GITHUB_PASSWORD
  repos = github.repos.list org: GITHUB_ORGANISATION_NAME

  while repos.has_next_page?
    puts "Moving to the next page of repos"
    repos.each do |repo| 
      last_pushed = Time.parse(repo['pushed_at'])
      puts "\n\n#{repo['name']}"
      puts "Last Github push received at #{last_pushed}".green
      if need_to_backup?(repo['name'], last_pushed)
        puts "Backing up..."
        clone_and_upload_to_s3(:name => repo['name'], :clone_url => repo['ssh_url'])
      else
        puts "Skipping...".yellow
      end
    end
    repos = repos.next_page
  end

end

begin
	# create temp dir
	Dir.mkdir(S3_BUCKET) rescue nil
	ensure_bucket_exists
	backup_repos_from_github
ensure	
	# remove temp dir
	delete_dir_and_sub_dir(S3_BUCKET)
end
