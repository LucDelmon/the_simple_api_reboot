> This repository is a reboot of the [the_simple_api]( https://github.com/LucDelmon/the_simple_api) project. The main change being the use of a squash and merge strategy associated with semantic versioning instead of the git flow strategy with 2 branches. Also aiming for a better automation of the deployment process that will remove the need to preconfigure the server before deploying and try 
> to make full usage of all the new AI tools.

[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

[![Ruby Style Guide](https://img.shields.io/badge/code_style-community-brightgreen.svg)](https://rubystyle.guide)

# Introduction
The goal of this project is to create the simplest API possible and add on top of it the most complex and complete CI/CD pipeline while applying best practices and add everything that a serious project should have.

The project is intended to be used as a reference for other projects and as a starting point for my own project.

# Local Installation (development)

## Requirements
- Ruby version 3.3.0
- PostgresSQL with a user `rails` created, the password associated with this user must be added to the credentials file (`rails credentials:edit`) under the name `db_password`
- Redis installed locally
