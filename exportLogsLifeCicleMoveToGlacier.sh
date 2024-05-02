#!/bin/bash

AWS_REGION="sa-east-1";
CLIENT_NAME=$(facter client);
USER_EMAIL_TO="mon.sor.$CLIENT_NAME@matera.com";
CLIENT_NAME_UPPER_CASE=$(echo $CLIENT_NAME | tr '[:lower:]' '[:upper:]');
USER_EMAIL_FROM="mtuser@matera.com";
SUBJECT_EMAIL_FAILED="[$CLIENT_NAME_UPPER_CASE-PRD] - Failed to Export Logs to S3 Glacier";
SUBJECT_EMAIL_SUCESS="[$CLIENT_NAME_UPPER_CASE-PRD] - Success to Export Logs to S3 Glacier";
S3_BUCKET_NAME="$CLIENT_NAME-prd-app-logs-glacier";
CURRENT_DATE=$(date +%Y-%m-%d-%H:%M:%S);
CURRENT_YEAR=$(date +%Y);
DATE_ISO_FORMAT=$(date "+%FT%T%z")
S3_PREFIX=$(echo "$CURRENT_YEAR/");
TRANSITION_DAYS=1;
EXPIRATION_DAYS=1874;
GLACIER_STORAGE_CLASS="GLACIER";
GLACIER_VAULT_NAME="backup-logs-app";
START_TIME=$(date -u -d "-7 days" '+%s%3N');
END_TIME=$(date -u '+%s%3N');

function send_email(){
  if [ "$?" == 0 ];
  then
     echo -e "Subject: $SUBJECT_EMAIL_SUCESS \n\nExport realizado com sucesso!." | /usr/sbin/sendmail -F "mtuser" -f $USER_EMAIL_FROM -t $USER_EMAIL_TO;
  else
     echo -e "Subject: $SUBJECT_EMAIL_FAILED \n\nFalha ao realizar o export dos logs. Por favor, verificar!" | /usr/sbin/sendmail -F "mtuser" -f $USER_EMAIL_FROM -t $USER_EMAIL_TO;
  fi
}

function listLogGroupsName(){
   aws logs describe-log-groups --region $AWS_REGION | jq -r '.logGroups[].logGroupName';
}

function verifyTagLogGroup(){
   aws logs list-tags-log-group --log-group-name $LOG_GROUP_NAME_LIST --region $AWS_REGION | jq -r '.tags.BACKUP_LOGS_GLACIER';
}

function getAccoutID(){
  ACCOUNT_ID_AWS=$(aws sts get-caller-identity --query "Account" --output text);
}

function createBucketS3(){
  aws s3api create-bucket --bucket $S3_BUCKET_NAME --create-bucket-configuration LocationConstraint=$AWS_REGION;
  aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "logs.'$AWS_REGION'.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::'$S3_BUCKET_NAME'"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "logs.'$AWS_REGION'.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::'$S3_BUCKET_NAME'/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "aws:SourceAccount": "'$ACCOUNT_ID_AWS'"
                }
            }
        }
    ]
}'  
}

function createDirectoryYear(){
   RESULT=$(aws s3 ls s3://"$S3_BUCKET_NAME"/"$CURRENT_YEAR/");
   if [ -z "$RESULT" ]; 
   then
       aws s3api put-object --bucket "$S3_BUCKET_NAME" --key "$CURRENT_YEAR/";
   else   
       echo "Ok: Directory Exist" > /dev/null;
   fi
}

#createDirectoryYear;

function exportLogsToS3(){
   EXPORT_TASK=$(aws logs create-export-task --region $AWS_REGION \
     --log-group-name "$LOG_GROUP_NAME_LIST" \
     --from "$START_TIME" \
     --to "$END_TIME" \
     --destination "$S3_BUCKET_NAME" \
     --destination-prefix "$S3_PREFIX$LOG_GROUP_NAME_LIST-$CURRENT_DATE" \
     --query 'taskId' \
     --output text);
   
   #sleep 200;

   TASK_STATUS=""
   while [ "$TASK_STATUS" != "COMPLET" ]; do
   TASK_STATUS=$(aws logs describe-export-tasks --region $AWS_REGION --task-id $EXPORT_TASK --query 'exportTasks[0].status' --output text);
   TASK_STATUS=$(echo "$TASK_STATUS" | cut -c1-7);
   if [ "$TASK_STATUS" == "FAILED" ]; then
   echo "A exportação falhou. Verifique as permissões e configurações." > /dev/null;
   fi
   echo "Aguardando a conclusão da exportação. Status atual: $TASK_STATUS";
   sleep 10
done

}

function configureLifeCycleS3BucketClass(){
   aws s3api put-bucket-lifecycle-configuration \
     --bucket "$S3_BUCKET_NAME" \
     --lifecycle-configuration '{
       "Rules": [
         {
	   "ID": "MoveToGlacierFlexible",
           "Status": "Enabled",
	   "Filter": {},
           "Transitions": [
             {
               "Days": '"${TRANSITION_DAYS}"',
               "StorageClass": "'"${GLACIER_STORAGE_CLASS}"'"
             }
           ],
	   "Expiration": {
           "Days": '"${EXPIRATION_DAYS}"'     
           }	
         }
       ]
     }'
}

aws s3api head-bucket --bucket $S3_BUCKET_NAME 2> /dev/null;
if [ $? -ne 0 ];
then
   getAccoutID;
   createBucketS3;
   createDirectoryYear;
   configureLifeCycleS3BucketClass;  
fi

for LOG_GROUP_NAME_LIST in $(listLogGroupsName);
do
    VERIFY_TAG_LOG_GROUP=$(verifyTagLogGroup);
    if [ "$VERIFY_TAG_LOG_GROUP" == "true" ];
    then
       exportLogsToS3;
       send_email;
    fi    
done
