import boto3

ec2 = boto3.client("ec2")


def get_or_create_quarantine_sg(vpc_id):
    name = "siem-quarantine-sg"
    found = ec2.describe_security_groups(
        Filters=[
            {"Name": "group-name", "Values": [name]},
            {"Name": "vpc-id", "Values": [vpc_id]},
        ]
    )["SecurityGroups"]
    if found:
        return found[0]["GroupId"]

    sg_id = ec2.create_security_group(
        GroupName=name,
        Description="Quarantine: no traffic allowed",
        VpcId=vpc_id,
    )["GroupId"]

    # New security groups allow all outbound traffic by default, so remove it
    ec2.revoke_security_group_egress(
        GroupId=sg_id,
        IpPermissions=[
            {"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
        ],
    )
    return sg_id


def lambda_handler(event, context):
    detail = event.get("detail", {})
    instance_id = (
        detail.get("resource", {})
        .get("instanceDetails", {})
        .get("instanceId")
    )
    if not instance_id:
        return {"status": "no instance in finding"}

    instance = ec2.describe_instances(InstanceIds=[instance_id])
    vpc_id = instance["Reservations"][0]["Instances"][0]["VpcId"]

    sg_id = get_or_create_quarantine_sg(vpc_id)

    ec2.modify_instance_attribute(InstanceId=instance_id, Groups=[sg_id])
    ec2.create_tags(
        Resources=[instance_id],
        Tags=[{"Key": "Status", "Value": "quarantined"}],
    )
    return {"status": "isolated", "instance": instance_id}