# Repo Patcher
- This repo will upload (commit) anything under the patch_files folder to GitHub into a new branch that is contained in a variable that you can set.
- It has a prefix that can remain constant signifying that it's from the "DevOps" team, allowing for the PR's that are created to be searched for later
- After the files are committed, the PR is raised and auto merging is attempted, but it is expected that in many environments either checks or reviews will have to be done, preventing the merge to succeed - this has not been tested yet

## Files

- `addWorkflowToRepos.rb`: This is the main script in the repository. It includes several functions that perform tasks such as adding files to a repository, validating that files were added, and reporting on existing DevOps pull requests.

## Usage

- To run the script, you can use the following command: `ruby addWorkflowToRepos.rb`

### Prerequisites
- To use the script, you need to set up a GitHub access token: Follow the instructions in the [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) on how to create a Personal Access Token (PAT).
- Install Ruby. You can download it from the [official website](https://www.ruby-lang.org/en/downloads/).
- If you are using Windows, you will need to install the Ruby+Devkit version. You can download it from the [official website](https://rubyinstaller.org/downloads/). Or try: [Chocolatey](https://chocolatey.org/) by running `choco install ruby` in your terminal.
- If using Mac, you can install Ruby using Homebrew by running `brew install ruby` in your terminal.
- Install the `octokit` gem by running `bundle install` in this folder. If you don't have bundler installed, you can install it by running `gem install bundler` in your terminal.


## License

- Provided as is with no warranty