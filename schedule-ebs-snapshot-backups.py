# Copyright 2015 Ryan S Brown
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import boto3
import collections
import datetime

ec = boto3.client('ec2')

def lambda_handler(event, context):
    reservations = ec.describe_instances(
        Filters=[
            {'Name': 'tag:Backup', 'Values': ['true', 'yes', '1']},
        ]
    ).get(
        'Reservations', []
    )

    instances = sum(
        [
            [i for i in r['Instances']]
            for r in reservations
        ], [])

    print("Found %d instances that need backing up" % len(instances))

    to_tag = collections.defaultdict(list)

    for instance in instances:
        try:
            retention_days = [
                int(t.get('Value')) for t in instance['Tags']
                if t['Key'] == 'Retention'][0]
        except IndexError:
            retention_days = 7

        # See https://github.com/boto/boto3/issues/264#issuecomment-213573980
        tags = dict([(x['Key'], x['Value']) for x in instance['Tags'] or []])

        for dev in instance['BlockDeviceMappings']:
            if dev.get('Ebs', None) is None:
                continue
            vol_id = dev['Ebs']['VolumeId']
            print("Found EBS volume %s on instance %s" % (
                vol_id, instance['InstanceId']))

            snap = ec.create_snapshot(
                VolumeId=vol_id,
                Description="%s:%s" % (tags['Name'], dev['DeviceName'])
            )

            to_tag[retention_days].append(snap['SnapshotId'])

            print("Retaining snapshot %s of volume %s from instance %s for %d days" % (
                snap['SnapshotId'],
                vol_id,
                instance['InstanceId'],
                retention_days,
            ))


    for retention_days in list(to_tag.keys()):
        delete_date = datetime.date.today() + datetime.timedelta(days=retention_days)
        delete_fmt = delete_date.strftime('%Y-%m-%d')
        print("Will delete %d snapshots on %s" % (len(to_tag[retention_days]), delete_fmt))
        ec.create_tags(
            Resources=to_tag[retention_days],
            Tags=[
                {'Key': 'DeleteOn', 'Value': delete_fmt},
            ]
        )
