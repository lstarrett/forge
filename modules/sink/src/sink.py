import argparse
import boto3
from os import getenv
from os import path
from os import remove
import shutil
from sys import exit


# Process arguments
parser = argparse.ArgumentParser()
parser.add_argument('--datadir',
                    help='Path to workflow data directory')
parser.add_argument('--bucket',
                    help='S3 bucket to upload workflow data (defaults to env var S3_BUCKET)')
parser.add_argument('--dataobj',
                    help='Object name in S3 bucket for uploaded workflow data archive')
parser.add_argument('--bypass', action='store_true')
args = parser.parse_args()


# Zip workflow data directory, and upload archive to S3
def uploadWorkflowData():

    print(path.basename(__file__) + " - INFO: creating zip archive of data directory '" + args.datadir + "'")
    datadir_zip = shutil.make_archive(path.splitext(args.dataobj)[0], 'zip', args.datadir)

    print(path.basename(__file__) + " - INFO: uploading data archive to S3 bucket '" + args.bucket + "'")
    s3 = boto3.client('s3')
    s3.upload_file(datadir_zip, args.bucket, args.dataobj)

    # Clean up
    remove(datadir_zip)


if __name__ == '__main__':
    
    # If the --bypass flag is passed, exit without downloading/uploading workflow data from S3
    if (args.bypass):
        print(path.basename(__file__) + " - INFO: Bypassing S3 download/upload. Exiting.")
        exit(0)

    # Check for S3 Bucket in args or envrionment
    if (not args.bucket):
        if (not getenv('S3_BUCKET')):
            print(path.basename(__file__) + " - ERROR: S3 Bucket was not provided as a CLI argument or ENV variable. Aborting.")
            exit(1)
        else:
            args.bucket = getenv('S3_BUCKET')

    uploadWorkflowData()

