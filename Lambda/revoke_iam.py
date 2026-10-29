import boto3

iam = boto3.client("iam")

# Users that must never be auto-disabled
PROTECTED_USERS = ["siem-admin"]


def lambda_handler(event, context):
    details = event.get("detail", {}).get("resource", {}).get("accessKeyDetails", {})
    key_id = details.get("accessKeyId")
    user_name = details.get("userName")

    if not key_id or not user_name:
        return {"status": "no access key in finding"}

    if user_name in PROTECTED_USERS:
        return {"status": "skipped protected user", "user": user_name}

    iam.update_access_key(
        UserName=user_name,
        AccessKeyId=key_id,
        Status="Inactive",
    )
    return {"status": "key disabled", "user": user_name, "key": key_id}