
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
  reportRateLimit("beginning of run")
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
    repos = File.readlines(reposFile).map(&:chomp).reject { |line| line.strip.empty? || line.start_with?("#") }
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
      log($output_csv,"#{repoFullName},success,PR merged", true)
      $client.delete_branch(repoFullName, thePR.head.ref)
      # log($output_csv,"#{repoFullName},success,branch deleted", true)
    rescue Octokit::UnprocessableEntity => e
      # find an open PR for the branch with the right name
      log($output_csv,"#{repoFullName},warning,erorr occured: #{e.message}", true)
    end
end

##############################################################################################################
def create_output_files(org)
  create_output_folders()
  time = Time.new
  time = time.strftime("%Y%m%d_%H%M%S")

  $output_csv = "#{$output_folder}/#{org}_#{time}_output.csv"
  File.open($output_csv, "w") do |file|
    file.puts("Repo,Message Type,Message")
  end

  $prs_csv = "#{$output_folder}/#{org}_prs.csv"
  File.open($prs_csv, "w") do |file|
    file.puts("Repo,Branch,State,Merged At,URL")
  end
end #end of create_output_files

##############################################################################################################
def create_output_folders()
  $output_folder = "_out"
  unless File.directory?($output_folder)
    Dir.mkdir($output_folder)
  end
  $patch_files_folder = "patch_files"
  unless File.directory?($patch_files_folder)
    Dir.mkdir($patch_files_folder)
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
def addFilesToRepo(repo, branchName)
  fileCount = 0
  Dir.glob('patch_files/**/*' , File::FNM_DOTMATCH).each do |file|
    next if File.directory?(file) || File.basename(file) == '.DS_Store' #.DS_Store is a Mac thing
    fileContent = File.read(file)
    filePath = "#{File.basename(file)}"
    commitMsg = "DevOps adding/updating file #{file}"
    begin
      existing_file = $client.contents(repo, path: filePath, ref: branchName)
      $client.update_contents(repo, filePath, commitMsg, existing_file.sha, fileContent, branch: branchName)
      fileCount += 1
      # log($output_csv, "#{repo},success,File #{filePath} updated", true)
    rescue Octokit::NotFound
      $client.create_contents(repo, filePath, commitMsg, fileContent, branch: branchName)
      fileCount += 1
      # log($output_csv, "#{repo},success,File #{filePath} added", true)
    rescue Octokit::UnprocessableEntity => e
      log($output_csv, "#{repo},warning,Failed to add/update file #{filePath},#{e.message}", true)
    end
  end # end of Dir.glob
  log($output_csv, "#{repo},success,#{fileCount} files added to branch", true)
end # end of addFilesToRepo

##############################################################################################################
def reportOnExistingDevOpsPRs(repo, devopsPrefix)
  existingPRs = $client.pull_requests(repo, state: 'all')
  existingPRs.each do |pr|
    if pr.head.ref.start_with?(devopsPrefix)
      log($prs_csv, "#{repo},#{pr.head.ref},#{pr.state},#{pr.merged_at},#{pr.html_url}", false)
    end
  end
end # end of reportOnExistingDevOpsPRs

##############################################################################################################
# dump out api rate limit used, and remaining
def reportRateLimit(extraMsg)
  rateLimit = $client.rate_limit!
  # puts "::: #{rateLimit}"
  puts "::: API Rate Limit: #{extraMsg}: #{rateLimit.remaining} of #{rateLimit.limit} requests remaining. Resets at: #{rateLimit.resets_at}"
end

##############################################################################################################
##############################################################################################################
def main()
  setupOctokit()
  org = 'ts-source'
  devopsPrefix = 'qqqDevOps_' # if all branches we create have a unique prefix, we can find them later
  branchName =  devopsPrefix + 'patchNumber48'
  pr_name = "DevOps patching repo..."
  create_output_files(org)
  repos = retrieveRepos(org)

  repos.each do |repo|
    reportRateLimit("repo")
    suspend_s = 5
    begin
      if !repo_exists?($client, repo)
        log($output_csv,"#{repo},warning,Repo does not exist", true)
        next
      end

      mainBranch = $client.branch(repo, $client.repository(repo).default_branch)

      if !branch_exists?($client, repo, branchName)
        $client.create_ref(repo, "refs/heads/#{branchName}", mainBranch.commit.sha)
      end

      addFilesToRepo(repo, branchName)
      reportOnExistingDevOpsPRs(repo, devopsPrefix) # report on existing PRs before creating a new one
      thePR = create_pull_request(repo, mainBranch, branchName, pr_name)
      mergePR(repo, thePR)
    rescue Octokit::TooManyRequests
      puts "Rate limit exceeded, sleeping for #{suspend_s} seconds"
      sleep suspend_s
      suspend_s = [suspend_s * 2, client.rate_limit.resets_in + 1].min
      retry
    end # begin-rescue block
  end # repos.each

  reportRateLimit("end of run")
end # main

main()
