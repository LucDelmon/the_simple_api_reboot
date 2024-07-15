> This repository is a reboot of the [the_simple_api]( https://github.com/LucDelmon/the_simple_api) project. The main change being the use of a squash and merge strategy associated with semantic versioning instead of the git flow strategy with 2 branches. Also aiming for a better automation of the deployment process that will remove the need to preconfigure the server before deploying and try 
> to make full usage of all the new AI tools.

[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

[![Ruby Style Guide](https://img.shields.io/badge/code_style-community-brightgreen.svg)](https://rubystyle.guide)

[![GitHub tag](https://img.shields.io/github/tag/LucDelmon/the_simple_api_reboot.svg)](https://GitHub.com/LucDelmon/the_simple_api_reboot/tags/)
[![GitHub commits](https://badgen.net/github/commits/LucDelmon/the_simple_api_reboot)](https://GitHub.com/Naereen/LucDelmon/the_simple_api_reboot/commit/)
[![GitHub latest commit](https://badgen.net/github/last-commit/LucDelmon/the_simple_api_reboot)](https://GitHub.com/LucDelmon/the_simple_api_reboot/commit/)

# Introduction
The goal of this project is to create the simplest API possible and add on top of it the most complex and complete CI/CD pipeline while applying best practices and add everything that a serious project should have.

The project is intended to be used as a reference for other projects and as a starting point for my own project.

# Best practises
- Commits follow the [Conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) standard.

# Local Installation (development)

## Requirements
- Ruby version 3.3.0
- PostgresSQL with a user `rails` created, the password associated with this user must be added to the credentials file (`rails credentials:edit`) under the name `db_password`
- Redis installed locally

## Make it work
After cloning
- ./bin/setup
- rspec to launch the specs
- rails c to start a console
- rails s to start the server

# CI
The CI is done with GitHub actions and is composed of 1 workflow.

`ci.yml` that is triggered on every push to the `master` branch. The CI checks the code with rubocop, brakeman, bundle-audit, runs the tests and checks the coverage. The CI must be green for merging and deploying.

# CD
The CD is done with GitHub actions in the same workflow as the CI. It is trigger only if the build and tests jobs are green. The release is done with the `semantic-release` tool that will create a new release on GitHub.

# Deployment

I'm planning to test several deployments:
- All EC2 with terraform + GA
- All EC2 with cloud formation + GA
- EC2 + S3 + RDS + GA
- EC2 + S3 + RDS + Capistrano
- ECS with the best combo from the others
- elastic beanstalk
