# Forge - Kubernetes-based sequential Docker container workflow execution system
> Forge enables lanuage-agnostic, modular logic workflows using chains of
Docker containers executing sequentially in a Kubernetes environment against
shared data. This project is packaged with tooling to deploy locally to a
Minikube Kubernetes cluster, or to AWS EKS via the AWS CDK.

## Architecture Overview

### Concept
The core concept of the Forge architecture is to enable the execution of
chained logic workflows, each logic module entirely independent of any other, and
each logic module entirely abstracted from the underlying infrastructure. This allows
each logic module to be implemented and tested entirely independently, and developed
using arbitrary programming languages and tools.

Each logic module is packaged as a Docker container and published to AWS ECR
(or to a public Docker repository). Forge workflows are implemented as chains
of workflow module containers deployed to a Kubernetes cluster as a Kubernetes
Job.

Forge workflow modules share workflow data via a designated location on a local
filesystem within a Kubernetes Pod, and therefore can be easily tested locally
on a developer machine against local data. The entire workflow chain can be
deployed to a local Kubernetes cluster (using Minikube), or to a Kubernetes
cluster hosted in the cloud on AWS EKS. Forge provides the necessary
configuration and tooling to deploy to both Minikube and EKS environments.

When Forge is deployed to EKS and a workflow job is dispatched, each
workflow modules executes on AWS Fargate, which provides automatic compute
scaling for the workflow module containers as they execute.

Forge workflow data begins as a zip archive in an AWS S3 Bucket. The data is
downloaded by the first workflow module (Source), extracted to the local
filesystem within the Kubernetes Job pod, processed successively by each module
in the workflow chain, and then the results are zipped and uploaded back to the
S3 Bucket by the last workflow module (Sink) and the workflow job is complete.
All workflow containers terminate upon completion.

<br>

### Workflow Modules
Modules are dockerized logic modules which read input from the workflow data
directory, process it, write the results back out to the workflow data
directory, and then exit. Each workflow module must be self-contained and built
as a Docker container using a Dockerfile alongside the module source in the
`modules/<module-name>` subfolder. See `modules/worker` for an example workflow
module and its source files structure and build scripts.

### Source and Sink Modules
Workflow data download/upload is accomplished by two workflow modules included
in the Forge project: Source and Sink.

* The Source module is the first module to execute in the workflow chain, and it
downloads the workflow data archive from S3, extracts it, and copies it to the
local filesystem for processing by the workflow modules.

* The Sink module is the last module to execute in the workflow chain, and it
zips and uploads the processed workflow data from the local filesystem back to
S3 before the workflow job terminates.

<br>

## Requirements
* [Python 3][python3] -- To run built-in workflow modules locally (Source and Sink)
* [NodeJS][node] -- To install AWS CDK build and deploy dependencies via npm
* [Typescript][ts] -- To run AWS CDK build and deploy scripts implemented in Typescript
* [Docker][docker] -- To containerize workflow logic modules
* [AWS CLI][awscli] -- To interact with AWS account for deploying to EKS and ECR
* [AWS IAM Authenticator for kubectl][iam-authenticator] -- To allow kubectl to authenticate with an EKS cluster via AWS CLI credentials and an IAM role
* [AWS CDK][cdk] -- To build and deploy Forge to AWS via infratructure-as-code
* [Minikube][minikube] -- To create a local Kubernetes cluster for local testing
* [kubectl][kubectl] -- To interact with local and cloud-based Kubernetes clusters
* [direnv][direnv] -- To share configuration variables with all scripts and deployment specs

<br>

## Usage
Clone this repo, and follow the usage instructions below

<br>

### Makefile
The included Makefile contains all commands to build, deploy, and use Forge

```sh
cd <project dir>
make help
```

<br>

### Install required tools
1. Install Docker [(via Homebrew on macOS)][docker install]
2. Install AWS CLI [(via Homebrew on macOS)][awscli install]
2. Install AWS IAM Authenticator [(via Homebrew on macOS)][iam-authenticator install]
2. Install AWS CDK [(via npm)][cdk install]
2. Install kubectl [(via Homebrew on macOS)][kubectl install]
3. Install Minikube [(via Homebrew on macOS)][minikube install]
4. Install direnv [(via Homebrew on macOS)][direnv install]

<br>

### Set up local environment variables with direnv
1. `cd` into the project root directory
2. Open .envrc in a text editor
3. Set proper values for `AWS_PROFILE`, `AWS_ACCOUNTID`, and `AWS_REGION`
4. Save .envrc, and in project root directory run `direnv allow` to allow local environment to be loaded (any subsequent changes to .envrc will require a re-run of `direnv allow`)

<br>

### Develop and test workflow modules locally
A workflow module can be developed in any lanugage, so long as it meets the following requirements:
- Can be packaged as a self-contained Docker image
- Communicates with other workflow modules (if applicable) exclusively via files on the local filsystem
- Terminates upon completion and exits gracefully (all errors handled internally)

In addition to the Source and Sink modules, a sample workflow module is
included in `modules/worker` and sample workflow data is included in the
`modules/sharedfs/data` directory. All three built-in workflow modules are
implemented in Python. Test the sample workflow module locally with Python 3:
1. `cd` into the project root directory
2. Create a Python 3 virtual environment with `python3 -m venv myenv`
3. Activate virtual environment with `source myenv/bin/activate`
4. Run sample workflow module with `python modules/worker/src/worker.py --datadir modules/sharedfs/data`
5. List workflow data directory to see new timestamped file added by the sample workflow module: `ls modules/sharedfs/data`

<br>

### Deploy Forge to AWS with the AWS CDK
1. `cd` into the project root directory
2. Install Forge dependencies with `npm install`
3. Ensure that Typescript is installed, and build project with `npm run build`
4. Ensure that `.envrc` has been properly updated with valid AWS CLI variables
5. If this is your first time using the AWS CDK with the target AWS account, run `cdk bootstrap` to bootstrap your AWS account with required CDK deploy tooling
6. Deploy Forge with `make forge-deploy`, which will synthesize the Forge cloudformation templates, display the changeset, and request confirmation
7. Confirm deploy changeset, and wait for Forge infrastructure and resources to be built in your AWS account (approximately 25 minutes)

<br>

### Build workflow module Docker images and push to AWS ECR
1. `cd` into the project root directory
2. Ensure the Docker CLI is installed and Docker is running on your system
3. Build workflow module Docker images with `make build-all`
4. Authorize the Docker CLI to push to AWS ECR with `make docker-ecr-login`
5. Push Workflow Docker images the container repositories created by the Forge deployment with `make push-all` (NOTE: this is an approximately 1GB upload)
6. NOTE: for additional workflow container images, ECR repositories for each must be created either manually from the AWS console or via additional lines in `lib/forge-stack.ts`

<br>

### Test workflow locally with Minikube cluster
1. `cd` into the project root directory
2. Start Minikube cluster with `minikube start --vm-driver=hyperkit` (NOTE: on systems other than macOS, use appropriate alternate VM driver option)
3. Verify that kubectl was updated with Minikube context by running `kubectl get nodes` and confirming a local Minikube node is reported in the output
4. Ensure that workflow module Docker images are built and pushed to AWS ECR
5. Create an ECR image pull access secret in local minikube cluster with `make minikube-ecr-secret`
	1. *NOTE:* This operation assumes that the Docker CLI is logged in with `make docker-ecr-login`, and that Docker is configured to keep login tokens in `~/.docker/config` rather than using "credStore" integrations introduced in recent versions of Docker (e.g., Keychain integration on macOS)
	2. To ensure the Docker login token is accessible for use by the `make docker-ecr-login` target, disable the "Securely store Docker logins in macOS keychain" in the Docker application preferences (or disable the equivalent feature in the Docker preferences if you're using an OS other than macOS)
6. Create an AWS CLI/API access secret in the local minikube cluster with `make minikube-awscli-secret`
7. To test against local workflow data (and bypass S3 upload/download via Source and Sink modules), place workflow data into the `modules/sharedfs` directory, and in a separate terminal window/tab, run `make minikube-mount` to mount the `modules/sharedfs` directory to the Minikube host node (which is then mountable to workflow job pods). The `mount` target will start a process which must be kept alive during testing
8. Edit the `modules/job.yml` workflow job spec for local testing, following the guidance of the inline comments
9. Deploy workflow job onto the Minikube cluster with `make job`
10. Use `make command-reference` to output list of helpful commands for interacting with Kubernetes cluster and deployed workflow jobs
11. When the local Minikube cluster is no longer needed, stop the cluster with `minikube stop` to shut down the cluster nodes (preserves node VM and configuration), or use `minikube delete` to delete all Minikube cluster resources and kubectl config

<br>

### Upload workflow data to S3
The Sink module can be used directly to easily zip and upload workflow data to the forge-workflow-data S3 bucket
1. Activate your Python 3 virtual environment with `source myenv/bin/activate`
2. Run `python modules/source/src/source.py --bucket forge-workflow-data --dataobj data.zip --datadir <path/to/data/dir>` to zip and upload your workflow data directory to S3

<br>

### Test workflow locally but with workflow data hosted in S3
1. Follow the workflow data upload procedure above
2. Follow the local testing procedure above, but skip the local `modules/sharedfs` mounting step, since S3 workflow data will be used
3. Edit the `modules/job.yml` workflow job spec for local testing with S3 workflow data, following the guidance of the inline comments
4. Deploy workflow job onto the Minikube cluster with `make job`
5. Use `make command-reference` to output list of helpful commands for interacting with Kubernetes cluster and deployed workflow jobs

<br>

### Test workflow deployed to Forge cluster on AWS EKS
1. Switch kubectl context from Minikube cluster to Forge EKS cluster by running `kubectl config get-contexts` and then `kubectl config use-context <context-name>` with the name of the EKS Forge cluster context
2. Verify that kubectl was updated with Forge EKS context by running `kubectl get nodes` and confirming Fargate Kubernetes nodes are reported in the output
3. Ensure that workflow module Docker images are built and pushed to AWS ECR
4. Edit the `modules/job.yml` workflow job spec for EKS deployment, following the guidance of the inline comments
5. Deploy workflow job onto the Minikube cluster with `make job`
6. Use `make command-reference` to output list of helpful commands for interacting with Kubernetes cluster and deployed workflow jobs

<br>

### Undeploy Forge cluster and delete all resources
1. To undeploy Forge from AWS and delete all associated resources, run `make forge-destroy`
2. Confirm CDK destroy operation, and wait for CloudFormation stacks to delete (approximately 5 minutes)

<br>

## WIP: Lambda interface for Forge cluster
The following snippets are from a proof of concept for interacting with the
deployed Forge cluster via Lambda, so that APIs via API Gateway can be built to
expose Forge functionality (beyond direct CLI control via kubectl). This is
only a POC at the moment, and incomplete. No lambda resources are included in
the current Forge CDK stack.

### Configure Lambda Access
https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html

After deployment, a lambda function can be given access to interact with the EKS cluster
via `kubectl` by added a dedicated role to the aws-auth configmap within the cluster.

1. Create an IAM role for the lambda function, attach the BasicExecutionPolicy,
   and create and attach a new policy with the following body:
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "eks:DescribeCluster",
      "Resource": "arn:aws:eks:<region>:<account-id>:cluster/forge",
      "Effect": "Allow"
    }
  ]
}
```

2. From a machine with `kubectl` access to your cluster, run the following
   command to edit the configmap:
```
k edit configmap -n kube-system aws-auth
```

3. Add the IAM role created in step (1) to the config map under the "mapRoles"
   section:
```
- groups:
  - system:masters
  rolearn: arn:aws:iam::<account_id>:role/<role_name>
  username: arn:aws:iam::<account_id>:role/<role_name>
```

4. Attach the IAM role created in step (1) to your lambda function, after which
   it will be able to interact with the EKS cluster via `kubectl`

5. Use lambda layer TODO




[awscli]: https://aws.amazon.com/cli/
[awscli install]: https://formulae.brew.sh/formula/awscli

[cdk]: https://docs.aws.amazon.com/cdk/latest/guide/home.html
[cdk install]: https://docs.aws.amazon.com/cdk/latest/guide/getting_started.html

[docker]: https://docs.docker.com
[docker install]: https://docs.docker.com/install/

[kubectl]: https://kubernetes.io/docs/reference/kubectl/overview/
[kubectl install]: https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-with-homebrew-on-macos

[minikube]: https://minikube.sigs.k8s.io/docs/
[minikube install]: https://minikube.sigs.k8s.io/docs/start/#

[direnv]: https://direnv.net
[direnv install]: https://direnv.net/docs/installation.html

[iam-authenticator]: https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
[iam-authenticator install]: https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html

[python3]: https://www.python.org
[node]: https://nodejs.org
[ts]: https://www.typescriptlang.org

