#!/bin/bash

#### VARIABLES ####
BUCKET_S3_PART_NAME="-prd-app-logs-glacier";
PROFILE_LIST_AND_REGION_FILE="profilesList.txt";
POLICY_NAME="s3-createGlacierBucketPolicy";

#### FUNCTIONS ####

function getAWSProfile(){
   AWS_PROFILE=$(echo "$AWS_PROFILE_LIST" | cut -d ":" -f1);
}

function getAWSRegion(){
   AWS_REGION=$(echo "$AWS_PROFILE_LIST" | cut -d ":" -f2); 
}

function getAWSIDAccount(){
   ACCOUNT_ID_AWS=$(aws sts get-caller-identity --query "Account" --profile $AWS_PROFILE --output text);
}

function getInstanceIDNagios(){
   INSTANCE_ID_NAGIOS=$(aws ec2 describe-instances --profile $AWS_PROFILE --region $AWS_REGION --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value]" --output text | egrep -i "prd|prod|production|producao" -B1 | egrep -i "nagios" -B1 | head -n1);
}

function getInstanceARN(){
   INSTANCE_ARN=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID_NAGIOS --profile $AWS_PROFILE --region "$AWS_REGION" --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text);
}

function getRoleNameNagiosInstance(){
   ROLE_NAME=$(echo $INSTANCE_ARN | awk -F '/' '{print $2}');
   #echo "$ROLE_NAME";
}

function verifyIfPolicyExist(){
   aws iam get-policy --policy-arn arn:aws:iam::$ACCOUNT_ID_AWS:policy/$POLICY_NAME --profile $AWS_PROFILE 2> /dev/null;
}

function createPolicy(){
   aws iam create-policy --profile $AWS_PROFILE --policy-name $POLICY_NAME --policy-document "$POLICY_DOCUMENT";
}

function verifyAttachedPolicy(){
   RESULT_COMMAND_ATTACHED_POLICY=$(aws iam list-attached-role-policies --profile $AWS_PROFILE --role-name $ROLE_NAME --query "AttachedPolicies[?PolicyName=='${POLICY_NAME}']" --output text);
}

function AttachPolicy(){
   aws iam attach-role-policy --profile $AWS_PROFILE --role-name $ROLE_NAME --policy-arn "arn:aws:iam::$ACCOUNT_ID_AWS:policy/$POLICY_NAME";
}

for AWS_PROFILE_LIST in $(cat "$PROFILE_LIST_AND_REGION_FILE");
do
    getAWSProfile;
    getAWSRegion;
    getAWSIDAccount;
    getInstanceIDNagios;
    getInstanceARN;
    getRoleNameNagiosInstance;
    verifyIfPolicyExist;
    if [ $? != 0 ];
    then
	POLICY_DOCUMENT='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": [
                    "s3:PutLifecycleConfiguration",
                    "s3:PutBucketPolicy",
                    "s3:CreateBucket",
                    "s3:ListBucket",
                    "s3:GetBucketAcl"
                ],
                "Resource": "arn:aws:s3:::'$AWS_PROFILE$BUCKET_S3_PART_NAME'"
            },
            {
                "Sid": "VisualEditor1",
                "Effect": "Allow",
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::'$AWS_PROFILE$BUCKET_S3_PART_NAME'"
            }
          ]
        }'

        createPolicy;
    fi
    verifyAttachedPolicy;
    if [ -z "$RESULT_COMMAND_ATTACHED_POLICY" ];
    then
	AttachPolicy;
    fi
done
