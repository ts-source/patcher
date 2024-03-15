
require 'octokit'

##############################################################################################################
def log(file,msg,screenEcho)
  File.open(file, "a") do |file|
    file.puts(msg)
  end
  if screenEcho
    puts msg
  end
end

##############################################################################################################
def setupOctokit
  access_token = ENV['GH_PAT']
  if access_token.nil?
    puts "You need to set the GH_PAT environment variable to run this script"
    exit
  end
  $client = Octokit::Client.new(access_token: access_token)
  $client.auto_paginate = true
end

##############################################################################################################
def branch_exists?(client, repo, branch)
  client.ref(repo, "heads/#{branch}")
  true
rescue Octokit::NotFound
  false
end

##############################################################################################################
def retrieveRepos(org)
  repos = []

  # Read the list of repositories from a text file
  reposFile = 'include-repos.txt'
  if File.exist?(reposFile)
    puts "\nFile #{reposFile} exists, using it to filter Repos in the Source Org\n\n"
    repos = File.readlines(reposFile).map(&:chomp).reject { |line| line.start_with?("#") }
    repos.map! { |repo| "#{org}/#{repo}" } # add in org/ to each repo name
  else
    puts "\nFile #{reposFile} does not exist. Processing ALL Repos in the Source Org\n\n"
    repos = $client.org_repos(org).map(&:full_name)
  end
  repos.sort!
  return repos
end # retrieveRepos

##############################################################################################################
def create_pull_request(repoFullName, mainBranch, patchBranchName, commitMsgPrName)
  # Create a pull request from the new branch to the default branch
  begin
    thePR = $client.create_pull_request(repoFullName, mainBranch.name, patchBranchName, commitMsgPrName)
    log($output_csv,"#{repoFullName},success,PR created: #{thePR.html_url}", true)
    return thePR
  rescue Octokit::UnprocessableEntity => e
    log($output_csv,"#{repoFullName},notice,PR already exists or failed to create", true)
  end
end

##############################################################################################################
def mergePR(repoFullName, thePR)
    return if thePR.nil?

    begin
      # $client.create_pull_request_review(repoFullName, thePR.number, event: 'APPROVE')
      $client.merge_pull_request(repoFullName, thePR.number)
      log($output_csv,"#{repoFullName},success,PR approved", true)
      $client.delete_branch(repoFullName, thePR.head.ref)
      # log($output_csv,"#{repoFullName},success,branch deleted", true)
    rescue Octokit::UnprocessableEntity => e
      # find an open PR for the branch with the right name
      log($output_csv,"#{repoFullName},warning,erorr occured: #{e.message}", true)
    end
end

##############################################################################################################
def create_output_file(org)
  create_output_folders()
  #sring for date and time for file name
  time = Time.new
  time = time.strftime("%Y%m%d_%H%M%S")
  $output_csv = "#{$output_folder}/#{org}_#{time}_output.csv"
  File.open($output_csv, "w") do |file|
    file.puts("Repo,Message Type,Message")
  end
end

##############################################################################################################
def create_output_folders()
  $output_folder = "_out"
  unless File.directory?($output_folder)
    Dir.mkdir($output_folder)
  end
end #end of create_output_folders

##############################################################################################################
def repo_exists?(client, repo)
  client.repository(repo)
  true
rescue Octokit::NotFound
  false
end

##############################################################################################################
##############################################################################################################
def main()
  setupOctokit()
  org = 'ts-source'
  branchName = 'workflow_patch'
  commitMsgPrName = "add Checkmarx SARIF upload workflow [skip ci]"
  create_output_file(org)
  repos = retrieveRepos(org)

  repos.each do |repo|
    # if repo does not exist, skip it
    if !repo_exists?($client, repo)
     log($output_csv,"#{repo},warning,Repo does not exist", true)
     next
    end

    mainBranch = $client.branch(repo, $client.repository(repo).default_branch)

    if !branch_exists?($client, repo, branchName)
      $client.create_ref(repo, "refs/heads/#{branchName}", mainBranch.commit.sha)
    end

    workflowFile = File.read('sarif.yml') # read in the workflow file

    begin
      $client.create_contents(repo, '.github/workflows/sarif.yml', commitMsgPrName, workflowFile, branch: branchName)
    rescue Octokit::UnprocessableEntity => e
      # puts "file exists, dont need to create it"
    end

    thePR = create_pull_request(repo, mainBranch, branchName, commitMsgPrName)
    mergePR(repo, thePR)
  end # repos.each
end # main

main()
