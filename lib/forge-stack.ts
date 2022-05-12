import * as cdk from '@aws-cdk/core';
import ec2 = require('@aws-cdk/aws-ec2');
import ecr = require('@aws-cdk/aws-ecr');
import eks = require('@aws-cdk/aws-eks');
import iam = require('@aws-cdk/aws-iam');
import s3  = require('@aws-cdk/aws-s3');
import { DockerImageAsset } from '@aws-cdk/aws-ecr-assets';
import path = require('path');

export class ForgeStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);


    // Allow all account users to assume this role in order to admin the cluster
    const clusterAdmin = new iam.Role(this, 'ForgeAdminRole', {
      roleName: 'ForgeAdmin',
      assumedBy: new iam.AccountRootPrincipal()
    });

    // Initialize cluster
    const cluster = new eks.FargateCluster(this, 'Forge', {
      clusterName: 'Forge',
      version: eks.KubernetesVersion.V1_20,
      mastersRole: clusterAdmin,
      outputClusterName: true,
      outputMastersRoleArn: true
    });

    // Create built-in 'source' and 'sink' ECR repositories
    // NOTE: not specifying "repostioryName" here allows CDK to apply
    //       a unique hash suffix to prevent collision, but makes it
    //       more difficult for external tools to interact with
    //       these repositories by name.
    const source_ecr_repo = new ecr.Repository(this, 'source', {
      repositoryName: 'forge-source'
    });
    const worker_ecr_repo = new ecr.Repository(this, 'worker', {
      repositoryName: 'forge-worker'
    });
    const sink_ecr_repo = new ecr.Repository(this, 'sink', {
      repositoryName: 'forge-sink'
    });

    // Create serviceAccount specs for AWS resources access from inside cluster
    const workflow_data_bucket = new s3.Bucket(this, 'forge-workflow-data-2', {
      bucketName: 'forge-workflow-data-2'
    });

    const s3_service_account = cluster.addServiceAccount('s3-workflow-data-access', {
      name: 'forge-s3-workflow-data-access',
      namespace: 'default'
    });
    workflow_data_bucket.grantReadWrite(s3_service_account);

    const ecr_service_account = cluster.addServiceAccount('ecr-container-access', {
      name: 'forge-ecr-container-access',
      namespace: 'kube-system'
    });
    const ecr_all_repos_arn = 'arn:aws:ecr:' + cdk.Stack.of(this).region + ':' + cdk.Stack.of(this).account + ':repository/*'
    ecr_service_account.role.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      resources: [ecr_all_repos_arn],
      actions: [
        'ecr:DescribeImages',
        'ecr:DescribeRepositories'
      ],
    }));

    new cdk.CfnOutput(this, 's3-workflow-data-access-role', { value: s3_service_account.role.roleArn });
    new cdk.CfnOutput(this, 'ecr-access-role', { value: ecr_service_account.role.roleArn });

  }
}
