.SILENT:
.DEFAULT_GOAL := help

COLOR_RESET = \033[0m
COLOR_COMMAND = \033[36m
COLOR_YELLOW = \033[33m
COLOR_GREEN = \033[32m
COLOR_RED = \033[31m

PROJECT := Forge


## Deploy Forge stack to AWS via the AWS CDK, and update ~/.kube/config with EKS context and authorization role
forge-deploy:
	echo "Deploying ${PROJECT} to AWS with CDK..."
	cdk deploy --profile ${AWS_PROFILE}
	echo "Updating kubeconfig with ${PROJECT} EKS context..."
	aws eks update-kubeconfig --name ${PROJECT} --region ${AWS_REGION} --role-arn arn:aws:iam::${AWS_ACCOUNTID}:role/ForgeAdmin
	echo "Forge is deployed and ~/.kube/config has been updated with ${PROJECT} EKS context"
	echo "Check that kubectl is properly configured by listing cluster nodes (should report active Fargate nodes):"
	echo "${COLOR_GREEN}kubectl get nodes${COLOR_RESET}"

forge-destroy:
	echo "Undeploying ${PROJECT} to from AWS with CDK and deleting all associated resources..."
	cdk destroy --profile ${AWS_PROFILE}

## NOTE: This is run automatically as part of forge-deploy, so only necessary to run if interacting with cluster from a different machine
## Update ~/.kube/config with EKS cluster context and authorization role 
update-kubeconfig:
	echo "Updating kubeconfig with ${PROJECT} EKS context..."
	aws eks update-kubeconfig --name ${PROJECT} --region ${AWS_REGION} --role-arn arn:aws:iam::${AWS_ACCOUNTID}:role/ForgeAdmin


## Build Source workflow module Docker image
build-source:
	echo "Building Source module Docker image..."
	docker build --tag ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com/forge-source:latest modules/source
## Build Worker workflow module Docker image
build-worker:
	echo "Building Worker module Docker image..."
	docker build --tag ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com/forge-worker:latest modules/worker
## Build Sink workflow module Docker image
build-sink:
	echo "Building Sink module Docker image..."
	docker build --tag ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com/forge-sink:latest modules/sink
## Build all workflow module Docker images
build-all: build-source build-worker build-sink


## Get ECR token and perform Docker Login to push to ECR
docker-ecr-login:
	echo "Getting ECR login token and authorizing docker CLI..."
	aws ecr get-login-password \
            --profile ${AWS_PROFILE} | \
        docker login \
            --username AWS \
            --password-stdin ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com


## Push Source module Docker image to ECR for use by Kubernetes cluster
push-source:
	echo "Pushing Source module Docker image to ECR..."
	docker push ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com/forge-source:latest
## Push Worker module Docker image to ECR for use by Kubernetes cluster
push-worker:
	echo "Pushing Worker module Docker image to ECR..."
	docker push ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com/forge-worker:latest
## Push Sink module Docker image to ECR for use by Kubernetes cluster
push-sink:
	echo "Pushing Sink module Docker image to ECR..."
	docker push ${AWS_ACCOUNTID}.dkr.ecr.${AWS_REGION}.amazonaws.com/forge-sink:latest
## Push all workflow module Docker images to ECR for use by Kubernetes cluster
push-all: push-source push-worker push-sink


## Create/start Minikube cluster on local machine and adds necessary auth to ~/.kube/config for kubectl
minikube-start:
	minikube start --vm-driver=hyperkit
## Stop minikube cluster (but leaves cluster nodes and cluster configuration, e.g., secrets and logs, intact)
minikube-stop:
	minikube stop
## Delete minikube cluster and all associated resources
minikube-delete:
	minikube delete
## Mount local workflow data directory as shared filesystem in minikube cluster
minikube-mount:
	minikube mount modules/sharedfs:/shared
## Create an ECR login secret in your Minikube cluster which is used to pull workflow module images from ECR
minikube-ecr-secret: docker-ecr-login
	kubectl delete secret ecr-creds
	kubectl create secret generic ecr-creds \
		--from-file=.dockerconfigjson=${HOME}/.docker/config.json \
		--type=kubernetes.io/dockerconfigjson
## Create a secret with AWS CLI credentials file to allow pods in Minikube cluster to access AWS resources for easy local testing
minikube-awscli-secret:
	# Copy AWS credentials for target profile into local file
	sed -n '/\[${AWS_PROFILE}\]/,/^ *$$/p' ~/.aws/credentials > aws-cli-credentials
	# Change the profile name to default (since it will be the only profile inside the cluster)
	sed -i'.original' -e 's/${AWS_PROFILE}/default/g' aws-cli-credentials
	# Remove the backup file which sed creates
	rm aws-cli-credentials.original
	# Create the secret in the cluster
	kubectl delete secret minikube-aws-creds
	kubectl create secret generic minikube-aws-creds \
	        --from-file=credentials=aws-cli-credentials


## Subsitutes environment variables into job.yml spec and deploys job into cluster
job:
	cat modules/job.yml | envsubst | kubectl apply -f -
## Deletes forge job from cluster
delete-job:
	kubectl delete job forge



## Prints useful commands for interacting with Forge
commands-reference:
	echo
	echo "View and change kubectl context (to switch between EKS cluster and local Minikube cluster):"
	echo "${COLOR_GREEN}kubectl config get-contexts${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl config use-context <context-name>${COLOR_RESET}"
	echo
	echo "List provisioned Kubernetes nodes upon which workloads will execute:"
	echo "${COLOR_GREEN}kubectl get nodes${COLOR_RESET}"
	echo
	echo "Interact with pods currently deployed in cluster:"
	echo "${COLOR_GREEN}kubectl get pods${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl describe pod <pod-ID>${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl delete pod <pod-ID>${COLOR_RESET}"
	echo
	echo "Interact with jobs currently deployed in cluster:"
	echo "${COLOR_GREEN}kubectl get jobs${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl describe job <job-ID>${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl delete job <job-ID>${COLOR_RESET}"
	echo
	echo "Get logs (dump or live tail) from containers running inside pod:"
	echo "${COLOR_GREEN}kubectl logs <pod-ID> <container-ID>${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl logs -f <pod-ID> <container-ID>${COLOR_RESET}"
	echo
	echo "Interact with secrets current configured in cluster:"
	echo "${COLOR_GREEN}kubectl get secrets${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl describe secret <secret-ID>${COLOR_RESET}"
	echo "${COLOR_GREEN}kubectl delete secret <secret-ID>${COLOR_RESET}"
	echo


## Prints help message
help:
	printf "\n${COLOR_YELLOW}${PROJECT}\n------\n${COLOR_RESET}"
	awk '/^[a-zA-Z\-_0-9\.%]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "${COLOR_COMMAND}$$ make %s${COLOR_RESET} %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' ${MAKEFILE_LIST} | sort
	printf "\n"


