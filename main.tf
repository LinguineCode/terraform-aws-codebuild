locals {
  defaults = {
    additional_iam_policies = []
    badge_enabled           = true
    artifacts = {
      type = "NO_ARTIFACTS"
    }
    environment = {
      type                  = "LINUX_CONTAINER"
      compute_type          = "BUILD_GENERAL1_SMALL"
      image                 = "aws/codebuild/standard:2.0"
      environment_variables = []
    }
    source = {
      buildspec           = null
      git_clone_depth     = null
      location_prefix     = "https://github.com/"
      report_build_status = true
      type                = "GITHUB"
    }
  }
}

resource "aws_s3_bucket" "main" {
  acl    = "private"
  bucket = "${var.name}"
}

resource "aws_codebuild_project" "main" {
  count = length(var.git_projects[*].name)

  name          = var.git_projects[count.index].name
  service_role  = aws_iam_role.main[count.index].arn
  badge_enabled = lookup(var.git_projects[count.index], "badge_enabled", lookup(local.defaults, "badge_enabled"))

  artifacts {
    type = lookup(var.git_projects[count.index], "artifacts_type", lookup(local.defaults.artifacts, "type"))
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.main.bucket}/${var.git_projects[count.index].name}/cache/archives" #don't get bit by bug: cache location is required when cache type is "S3"
  }

  environment {
    compute_type = lookup(var.git_projects[count.index], "environment_compute_type", lookup(local.defaults.environment, "compute_type"))
    image        = lookup(var.git_projects[count.index], "environment_image", lookup(local.defaults.environment, "image"))
    type         = lookup(var.git_projects[count.index], "environment_type", lookup(local.defaults.environment, "type"))

    dynamic "environment_variable" {
      for_each = lookup(var.git_projects[count.index], "environment_variables", lookup(local.defaults.environment, "environment_variables"))
      content {
        name  = lookup(environment_variable.value, "name")
        value = lookup(environment_variable.value, "value")
        type  = lookup(environment_variable.value, "type")
      }
    }
  }

  source {
    buildspec           = lookup(var.git_projects[count.index], "source_buildspec", lookup(local.defaults.source, "buildspec"))
    type                = lookup(var.git_projects[count.index], "source_type", lookup(local.defaults.source, "type"))
    location            = "${lookup(var.git_projects[count.index], "source_location_prefix", lookup(local.defaults.source, "location_prefix"))}${var.git_projects[count.index].org}/${var.git_projects[count.index].name}"
    git_clone_depth     = lookup(var.git_projects[count.index], "source_git_clone_depth", lookup(local.defaults.source, "git_clone_depth"))
    report_build_status = lookup(var.git_projects[count.index], "source_report_build_status", lookup(local.defaults.source, "report_build_status"))
  }
}

resource "aws_iam_role" "main" {
  count              = length(var.git_projects[*].name)
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codebuild.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "main" {
  count = length(var.git_projects[*].name)

  role   = aws_iam_role.main[count.index].name
  policy = "${data.aws_iam_policy_document.main[count.index].json}"
}

data "aws_iam_policy_document" "main" {
  count = length(var.git_projects[*].name)

  statement {
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.main.bucket}",
    ]
  }

  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.main.bucket}/${var.git_projects[count.index].name}",
      "arn:aws:s3:::${aws_s3_bucket.main.bucket}/${var.git_projects[count.index].name}/*",
    ]
  }

  dynamic "statement" {
    for_each = lookup(var.git_projects[count.index], "additional_iam_policies", lookup(local.defaults, "additional_iam_policies"))
    content {
      actions   = lookup(statement.value, "actions")
      resources = lookup(statement.value, "resources")
    }
  }
}
