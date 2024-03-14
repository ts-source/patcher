# this scirpt was originally written to generate "fake" Repos with secrets and environments 
# for GOSM testing purposes


import os
import requests
from nacl import encoding, public
from random_word import RandomWords

org_to_use="ts-source"

############################################################################################################
# Function to create a repository
def create_and_initialize_repo(org, repo, token):
  url = f"https://api.github.com/orgs/{org}/repos"
  headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github.v3+json"}
  data = {"name": repo, "auto_init": True}
  response = requests.post(url, headers=headers, json=data)
  response.raise_for_status()

  print(f"{repo}")
  # append to include-repos.txt
  with open("include-repos.txt", "a") as f:
    f.write(f"{repo}\n")

############################################################################################################
# Function to create repositories
def create_repos_secrets_environments(org, token):
  r = RandomWords()
  for _ in range(1): # creates X repos
    repo = '_'.join([r.get_random_word() for _ in range(2)])
    create_and_initialize_repo(org, repo, token)


if __name__ == "__main__":
  token = os.getenv("GH_PAT")
  if not token:
    print("Token is empty. Please set the GH_PAT environment variable.")
  else:
    create_repos_secrets_environments(org_to_use, token)
