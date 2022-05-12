import argparse
from datetime import datetime
from os import path
from os import listdir
from sys import exit


# Process arguments
parser = argparse.ArgumentParser()
parser.add_argument('--datadir',
                    help='Path to workflow data directory')
args = parser.parse_args()


# Zip workflow data directory, and upload archive to S3
def processData():

    filename = datetime.now().strftime('%Y-%m-%d_%I:%M%p') + ".txt"
    print(path.basename(__file__) + " - INFO: creating a new file and writing it to workflow data directory '" + path.join(args.datadir, filename) + "'")

    f = open(path.join(args.datadir, filename), "a")
    f.write("Worker module created a new file and wrote it to the workflow data directory!\n")
    f.close()

    print(path.basename(__file__) + " - INFO: listing files contained in workflow data directory '" + args.datadir + "'")
    for f in listdir(args.datadir):
        print(path.basename(__file__) + " - INFO: " + f)


if __name__ == '__main__':
    
    # Check for S3 Bucket in args or envrionment
    if (not args.datadir):
        print(path.basename(__file__) + " - ERROR: Missing required --datadir flag. Run with --help for usage info. Aborting.")
        exit(1)

    processData()

