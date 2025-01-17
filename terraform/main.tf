terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "region" {
  default = "eu-west-2"
}

locals {
  # TODO: Change this to the real host
  website_protocol    = "https"
  website_host        = "exercism.lol"
  http_port           = 80
  websockets_protocol = "wss"
  websockets_port     = 80

  efs_submissions_mount_point  = "/mnt/efs/submissions"
  efs_repositories_mount_point = "/mnt/efs/repos"

  s3_assets_bucket_name = "exercism-assets-staging"
  s3_attachments_bucket_name = "exercism-attachments-staging"

  ecr_tooling_repos = toset([
    "bash-test-runner",
    "c-test-runner",
    "c-representer",
    "cfml-test-runner",
    "clojure-analyzer",
    "clojure-representer",
    "clojure-test-runner",
    "clojurescript-test-runner",
    "crystal-test-runner",
    "coffeescript-test-runner",
    "common-lisp-analyzer",
    "common-lisp-representer",
    "common-lisp-test-runner",
    "cpp-test-runner",
    "csharp-analyzer",
    "csharp-representer",
    "csharp-test-runner",
    "d-test-runner",
    "dart-test-runner",
    "elixir-analyzer",
    "elixir-representer",
    "elixir-test-runner",
    "elm-analyzer",
    "elm-representer",
    "elm-test-runner",
    "emacs-lisp-test-runner",
    "erlang-analyzer",
    "erlang-test-runner",
    "fsharp-representer",
    "fsharp-test-runner",
    "generic-test-runner",
    "go-analyzer",
    "go-test-runner",
    "groovy-test-runner",
    "haskell-test-runner",
    "j-representer",
    "j-test-runner",
    "java-analyzer",
    "java-representer",
    "java-test-runner",
    "javascript-analyzer",
    "javascript-representer",
    "javascript-test-runner",
    "julia-test-runner",
    "kotlin-test-runner",
    "lfe-test-runner",
    "lua-test-runner",
    "mips-test-runner",
    "nim-analyzer",
    "nim-representer",
    "nim-test-runner",
    "ocaml-test-runner",
    "perl5-test-runner",
    "php-test-runner",
    "prolog-test-runner",
    "purescript-test-runner",
    "python-analyzer",
    "python-representer",
    "python-test-runner",
    "r-test-runner",
    "racket-test-runner",
    "raku-test-runner",
    "reasonml-test-runner",
    "red-test-runner",
    "ruby-analyzer",
    "ruby-representer",
    "ruby-test-runner",
    "rust-analyzer",
    "rust-representer",
    "rust-test-runner",
    "scala-analyzer",
    "scala-test-runner",
    "scheme-test-runner",
    "sml-test-runner",
    "stub-analyzer",
    "swift-test-runner",
    "tcl-test-runner",
    "typescript-analyzer",
    "typescript-representer",
    "typescript-test-runner",
    "vimscript-test-runner",
    "wren-test-runner",
    "x86-64-assembly-test-runner"
  ])


  ecr_lambda_repos = toset([
    "snippet-extractor"
  ])

  ecr_language_server_repos = toset([
    "ruby-language-server"
  ])
}

provider "aws" {
  region = var.region
}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

module "webservers" {
  source = "./webservers"

  region            = var.region
  ecr_tooling_repos = local.ecr_tooling_repos
  website_protocol  = local.website_protocol
  website_host      = local.website_host
  s3_assets_bucket_name = local.s3_assets_bucket_name
  s3_attachments_bucket_name = local.s3_attachments_bucket_name

  aws_iam_policy_document_assume_role_ecs      = data.aws_iam_policy_document.assume_role_ecs
  aws_iam_policy_read_dynamodb_config          = aws_iam_policy.read_dynamodb_config
  aws_iam_policy_write_to_cloudwatch           = aws_iam_policy.write_to_cloudwatch
  aws_iam_policy_access_s3_bucket_submissions  = aws_iam_policy.access_s3_bucket_submissions
  aws_iam_policy_access_s3_bucket_tooling_jobs = aws_iam_policy.access_s3_bucket_tooling_jobs
  aws_iam_policy_read_secret_config            = aws_iam_policy.read_secret_config
  aws_iam_role_ecs_task_execution              = aws_iam_role.ecs_task_execution
  aws_security_group_efs_repositories_access   = aws_security_group.efs_repositories_access
  aws_security_group_efs_submissions_access    = aws_security_group.efs_submissions_access
  aws_security_group_rds_main                  = aws_security_group.rds_main
  aws_efs_file_system_repositories             = aws_efs_file_system.repositories
  aws_efs_file_system_submissions              = aws_efs_file_system.submissions
  efs_submissions_mount_point                  = local.efs_submissions_mount_point
  efs_repositories_mount_point                 = local.efs_repositories_mount_point

  aws_vpc_main       = aws_vpc.main
  aws_subnet_publics = aws_subnet.publics

  container_cpu    = 1024
  container_memory = 3072
  container_count  = 1

  # TODO: Choose a websockets port for HTTPS
  # https://support.cloudflare.com/hc/en-us/articles/200169156-Identifying-network-ports-compatible-with-Cloudflare-s-proxy
  http_port       = local.http_port
  websockets_port = local.websockets_port
}

module "sidekiq" {
  source = "./sidekiq"

  region = var.region

  aws_ecr_repository_webserver_rails           = module.webservers.ecr_repository_rails
  aws_iam_policy_document_assume_role_ecs      = data.aws_iam_policy_document.assume_role_ecs
  aws_iam_policy_read_dynamodb_config          = aws_iam_policy.read_dynamodb_config
  aws_iam_policy_write_to_cloudwatch           = aws_iam_policy.write_to_cloudwatch
  aws_iam_policy_access_s3_bucket_submissions  = aws_iam_policy.access_s3_bucket_submissions
  aws_iam_policy_access_s3_bucket_tooling_jobs = aws_iam_policy.access_s3_bucket_tooling_jobs
  aws_iam_policy_read_secret_config            = aws_iam_policy.read_secret_config
  aws_iam_role_ecs_task_execution              = aws_iam_role.ecs_task_execution
  aws_security_group_elasticache_sidekiq       = module.webservers.security_group_elasticache_sidekiq
  aws_security_group_elasticache_anycable      = module.webservers.security_group_elasticache_anycable
  aws_security_group_efs_repositories_access   = aws_security_group.efs_repositories_access
  aws_security_group_efs_submissions_access    = aws_security_group.efs_submissions_access
  aws_security_group_rds_main                  = aws_security_group.rds_main
  aws_efs_file_system_repositories             = aws_efs_file_system.repositories
  aws_efs_file_system_submissions              = aws_efs_file_system.submissions
  efs_submissions_mount_point                  = local.efs_submissions_mount_point
  efs_repositories_mount_point                 = local.efs_repositories_mount_point

  aws_vpc_main       = aws_vpc.main
  aws_subnet_publics = aws_subnet.publics

  container_cpu    = 512
  container_memory = 1024
  container_count  = 1
}

module "bastion" {
  source = "./bastion"

  region            = var.region
  ecr_tooling_repos = local.ecr_tooling_repos

  aws_iam_policy_read_dynamodb_config          = aws_iam_policy.read_dynamodb_config
  aws_iam_policy_access_s3_bucket_submissions  = aws_iam_policy.access_s3_bucket_submissions
  aws_iam_policy_access_s3_bucket_tooling_jobs = aws_iam_policy.access_s3_bucket_tooling_jobs
  aws_iam_policy_read_secret_config            = aws_iam_policy.read_secret_config
  aws_security_group_efs_repositories_access   = aws_security_group.efs_repositories_access
  aws_security_group_efs_submissions_access    = aws_security_group.efs_submissions_access
  aws_security_group_elasticache_sidekiq       = module.webservers.security_group_elasticache_sidekiq
  aws_security_group_elasticache_tooling       = aws_security_group.elasticache_tooling
  aws_security_group_ssh                       = aws_security_group.ssh
  aws_security_group_rds_main                  = aws_security_group.rds_main
  aws_efs_file_system_repositories             = aws_efs_file_system.repositories
  aws_efs_file_system_submissions              = aws_efs_file_system.submissions

  aws_vpc_main       = aws_vpc.main
  aws_subnet_publics = aws_subnet.publics
}

module "tooling_orchestrator" {
  source = "./tooling_orchestrator"

  region = var.region

  aws_account_id                               = data.aws_caller_identity.current.account_id
  aws_iam_policy_document_assume_role_ecs      = data.aws_iam_policy_document.assume_role_ecs
  aws_iam_policy_read_dynamodb_config          = aws_iam_policy.read_dynamodb_config
  aws_iam_policy_write_to_cloudwatch           = aws_iam_policy.write_to_cloudwatch
  aws_iam_policy_access_s3_bucket_tooling_jobs = aws_iam_policy.access_s3_bucket_tooling_jobs
  aws_iam_role_ecs_task_execution              = aws_iam_role.ecs_task_execution

  aws_vpc_main       = aws_vpc.main
  aws_subnet_publics = aws_subnet.publics

  container_cpu    = 512
  container_memory = 1024
  container_count  = 1

  http_port = local.http_port
}

module "tooling_invoker" {
  source = "./tooling_invoker"

  region            = var.region
  ecr_tooling_repos = local.ecr_tooling_repos

  # aws_account_id                                         = data.aws_caller_identity.current.account_id
  # aws_iam_policy_read_dynamodb_config                         = aws_iam_policy.read_dynamodb_config
  # aws_iam_policy_write_to_cloudwatch                     = aws_iam_policy.write_to_cloudwatch
  # aws_iam_role_ecs_task_execution                        = aws_iam_role.ecs_task_execution
  aws_iam_policy_read_dynamodb_config_arn                  = aws_iam_policy.read_dynamodb_config.arn
  aws_iam_policy_read_dynamodb_tooling_language_groups_arn = aws_iam_policy.read_dynamodb_tooling_language_groups.arn
  aws_iam_policy_write_s3_bucket_tooling_jobs              = aws_iam_policy.write_s3_bucket_tooling_jobs

  aws_vpc_main       = aws_vpc.main
  aws_subnet_publics = aws_subnet.publics
}

module "github_deploy" {
  source = "./github_deploy"

  region = var.region

  aws_ecr_repo_arns = [
    module.snippet_extractor.ecr_repository_snippet_extractor.arn,

    module.tooling_orchestrator.ecr_repository_application.arn,
    module.tooling_orchestrator.ecr_repository_nginx.arn,

    module.webservers.ecr_repository_rails.arn,
    module.webservers.ecr_repository_nginx.arn,
    module.webservers.ecr_repository_anycable_go.arn
  ]
  aws_s3_bucket_name_webservers_assets = module.webservers.s3_bucket_assets.bucket
  aws_s3_bucket_name_webservers_icons = module.webservers.s3_bucket_icons.bucket
}

module "tooling" {
  source = "./tooling"

  region            = var.region
  ecr_tooling_repos = local.ecr_tooling_repos
}

module "language_servers" {
  source = "./language_servers"

  region                    = var.region
  ecr_language_server_repos = local.ecr_language_server_repos

  aws_account_id                          = data.aws_caller_identity.current.account_id
  aws_iam_policy_document_assume_role_ecs = data.aws_iam_policy_document.assume_role_ecs
  aws_iam_policy_read_dynamodb_config     = aws_iam_policy.read_dynamodb_config
  aws_iam_policy_write_to_cloudwatch      = aws_iam_policy.write_to_cloudwatch
  aws_iam_role_ecs_task_execution         = aws_iam_role.ecs_task_execution

  aws_vpc_main       = aws_vpc.main
  aws_subnet_publics = aws_subnet.publics

  container_cpu    = 256
  container_memory = 512
  container_count  = 1

  http_port       = local.http_port
  websockets_port = local.websockets_port
}

module "git_server" {
  source = "./git_server"
}

module "snippet_extractor" {
  source = "./snippet_extractor"

  region         = var.region
  aws_account_id = data.aws_caller_identity.current.account_id
}
