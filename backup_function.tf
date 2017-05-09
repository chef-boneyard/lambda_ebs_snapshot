resource "aws_iam_role" "ebs_backup_role" {
  name = "ebs_backup_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ebs_backup_policy" {
  name = "ebs_backup_policy"
  role = "${aws_iam_role.ebs_backup_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["logs:*"],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:CreateTags",
                "ec2:ModifySnapshotAttribute",
                "ec2:ResetSnapshotAttribute"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
}

data "archive_file" "schedule_ebs_snapshot_backups_zip" {
  type        = "zip"
  source_file = "${path.module}/schedule-ebs-snapshot-backups.py"
  output_path = "${path.module}/schedule-ebs-snapshot-backups.zip"
}

resource "aws_lambda_function" "schedule_ebs_snapshot_backups" {
  filename         = "${path.module}/schedule-ebs-snapshot-backups.zip"
  function_name    = "schedule_ebs_snapshot_backups"
  description      = "Automatically backs up instances tagged with backup: true"
  role             = "${aws_iam_role.ebs_backup_role.arn}"
  timeout          = 60
  handler          = "schedule-ebs-snapshot-backups.lambda_handler"
  runtime          = "python2.7"
  source_code_hash = "${data.archive_file.schedule_ebs_snapshot_backups_zip.output_base64sha256}"
}

data "archive_file" "ebs_snapshot_janitor_zip" {
  type        = "zip"
  source_file = "${path.module}/ebs-snapshot-janitor.py"
  output_path = "${path.module}/ebs-snapshot-janitor.zip"
}

resource "aws_lambda_function" "ebs_snapshot_janitor" {
  filename         = "${path.module}/ebs-snapshot-janitor.zip"
  function_name    = "ebs_snapshot_janitor"
  description      = "Cleans up old EBS backups"
  role             = "${aws_iam_role.ebs_backup_role.arn}"
  timeout          = 60
  handler          = "ebs-snapshot-janitor.lambda_handler"
  runtime          = "python2.7"
  source_code_hash = "${data.archive_file.ebs_snapshot_janitor_zip.output_base64sha256}"
}

resource "aws_cloudwatch_event_rule" "schedule_ebs_snapshot_backups" {
  name                = "schedule_ebs_snapshot_backups"
  description         = "Schedule for ebs snapshot backups"
  schedule_expression = "${var.ebs_snapshot_backups_schedule}"
}

resource "aws_cloudwatch_event_rule" "schedule_ebs_snapshot_janitor" {
  name                = "schedule_ebs_snapshot_janitor"
  description         = "Schedule for ebs snapshot janitor"
  schedule_expression = "${var.ebs_snapshot_janitor_schedule}"
}

resource "aws_cloudwatch_event_target" "schedule_ebs_snapshot_backups" {
  rule      = "${aws_cloudwatch_event_rule.schedule_ebs_snapshot_backups.name}"
  target_id = "schedule_ebs_snapshot_backups"
  arn       = "${aws_lambda_function.schedule_ebs_snapshot_backups.arn}"
}

resource "aws_cloudwatch_event_target" "schedule_ebs_snapshot_janitor" {
  rule      = "${aws_cloudwatch_event_rule.schedule_ebs_snapshot_janitor.name}"
  target_id = "ebs_snapshot_janitor"
  arn       = "${aws_lambda_function.ebs_snapshot_janitor.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_backup" {
  statement_id  = "AllowExecutionFromCloudWatch_schedule_ebs_snapshot_backups"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.schedule_ebs_snapshot_backups.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.schedule_ebs_snapshot_backups.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_janitor" {
  statement_id  = "AllowExecutionFromCloudWatch_ebs_snapshot_janitor"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ebs_snapshot_janitor.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.schedule_ebs_snapshot_janitor.arn}"
}
