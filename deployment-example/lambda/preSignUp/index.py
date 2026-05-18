import boto3

def handler(event, context):
    try:
        client = boto3.client('cognito-idp')
        user_pool_id = event['userPoolId']
        email = event['request']['userAttributes'].get('email')

        if not email:
            return event

        # Check if an UNCONFIRMED user with this email already exists
        response = client.list_users(
            UserPoolId=user_pool_id,
            Filter=f'email = "{email}"',
        )

        for user in response.get('Users', []):
            if user['UserStatus'] == 'UNCONFIRMED':
                client.admin_delete_user(
                    UserPoolId=user_pool_id,
                    Username=user['Username'],
                )
                print(f"Deleted UNCONFIRMED user: {user['Username']}")
    
    except Exception as error:
        print(f'Error in pre-signup trigger: {error}')

    return event
