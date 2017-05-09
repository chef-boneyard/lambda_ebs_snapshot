# Terraform config for automatic EBS snapshots

This repo contains a terraform configuration that creates two lambda functions
that will take automatic EBS snapshots at regular intervals. It is based on
the code at
<https://serverlesscode.com/post/lambda-schedule-ebs-snapshot-backups/> and
<https://serverlesscode.com/post/lambda-schedule-ebs-snapshot-backups-2/>.

## Usage

Include this repository as a module in your existing terraform code:

```
module "lambda_ebs_snapshot" {
  source = "github.com/chef/lambda_ebs_snapshot"
  # Setting these variables is optional
  # ebs_snapshot_backups_schedule = "cron(00 19 * * ? *)"
  # ebs_snapshot_janitor_schedule = "cron(05 19 * * ? *)"
}
```

### Configuring your instances to be backed up

Tag any instances you want to be backed up with `Backup = true`.

By default, old backups will be removed after 7 days, to keep them longer, set
another tag: `Retention = 14`, where 14 is the number of days you want to keep
the backups for.
