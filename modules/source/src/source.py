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
                    help='Path to directory into which to extract archive with workflow data (defaults to \'/shared/data\')')
parser.add_argument('--bucket',
                    help='S3 bucket from which to download workflow data archive (defaults to env var S3_BUCKET)')
parser.add_argument('--dataobj',
                    help='Object name in S3 bucket for workflow data archive to download')
parser.add_argument('--bypass', action='store_true')
args = parser.parse_args()


# Download workflow data archive from S3, and extract it to local filesystem
def downloadWorkflowData():

    print(path.basename(__file__) + " - INFO: downloading data archive from S3 bucket '" + args.bucket + "'")
    s3 = boto3.client('s3')
    with open(args.dataobj, 'wb') as f:
        s3.download_fileobj(args.bucket, args.dataobj, f)
        f.close()

    print(path.basename(__file__) + " - INFO: extracting archive to '" + args.datadir + "'")
    shutil.unpack_archive(args.dataobj, args.datadir, 'zip')

    # Clean up
    remove(args.dataobj)


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

    downloadWorkflowData()

