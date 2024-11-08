# GitHub Actions Workflow for Deploying to AWS ECS

This GitHub Actions workflow automates the deployment of your application to Amazon Elastic Container Service (ECS). It builds a Docker image, pushes it to Amazon Elastic Container Registry (ECR), updates the ECS task definition with the new image, and deploys the updated task to your ECS cluster.

## Prerequisites

- **AWS Resources**: Ensure that you have the following AWS resources set up:
  - An ECS Cluster named `df1-cluster`.
  - An ECS Service named `static-www-service`.
  - An ECS Task Definition named `static-www-task`.
  - An ECR Repository named `df1/static-www`.

- **GitHub Secrets**: Store the following secrets in your GitHub repository settings:
  - `AWS_ACCESS_KEY_ID`: Your AWS access key ID.
  - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key.
  - `AWS_ACCOUNT_ID`: Your 12-digit AWS account ID.

- **Dockerfile**: Include a `Dockerfile` at the root of your repository to build the Docker image.


## Workflow Overview

```yaml
name: Deploy to ECS

on:
  push:
    branches:
      - main
```

- **Name**: The workflow is named **"Deploy to ECS"**.
- **Trigger**: It runs whenever there is a push to the `main` branch.

## Steps Breakdown

### 1. Checkout Code

```yaml
- name: Checkout code
  uses: actions/checkout@v2
```

- **Purpose**: Checks out the repository code so that the workflow can access it.
- **Action Used**: `actions/checkout@v2` clones your repository onto the runner.

### 2. Configure AWS Credentials

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v1
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: eu-central-1
```

- **Purpose**: Sets up AWS credentials and configures the AWS CLI for subsequent AWS commands.
- **Inputs**:
  - **aws-access-key-id**: Your AWS Access Key ID, stored in GitHub Secrets.
  - **aws-secret-access-key**: Your AWS Secret Access Key, stored in GitHub Secrets.
  - **aws-region**: The AWS region where your resources are located (e.g., `eu-central-1`).

### 3. Log in to Amazon ECR

```yaml
- name: Log in to Amazon ECR
  id: ecr-login
  uses: aws-actions/amazon-ecr-login@v1
```

- **Purpose**: Authenticates Docker to your Amazon ECR registry so you can push images.
- **ID**: Assigns an ID `ecr-login` to reference outputs from this step later if needed.

### 4. Build, Tag, and Push Docker Image to ECR

```yaml
- name: Build, tag, and push Docker image to ECR
  id: build-image
  env:
    AWS_ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
    ECR_REGISTRY: ${{ env.AWS_ACCOUNT_ID }}.dkr.ecr.eu-central-1.amazonaws.com
    ECR_REPOSITORY: df1/static-www
    IMAGE_TAG: ${{ github.sha }}
  run: |
    docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
```

- **Purpose**: Builds your Docker image, tags it with the GitHub commit SHA, and pushes it to Amazon ECR.
- **Commands**:
  - `docker build`: Builds the Docker image using the `Dockerfile` in the current directory.
  - `docker push`: Pushes the built image to the specified ECR repository.
  - `echo "image=..." >> $GITHUB_OUTPUT`: Sets an output variable `image` for use in subsequent steps.

### 5. Download Task Definition

```yaml
- name: Download task definition 
  run: |
    aws ecs describe-task-definition --task-definition static-www-task --query taskDefinition > task-definition.json
```

- **Purpose**: Downloads the current ECS task definition and saves it to a JSON file.
- **Command Breakdown**:
  - `aws ecs describe-task-definition`: Retrieves details about the specified task definition.
  - `--task-definition static-www-task`: Specifies the task definition to describe.
  - `--query taskDefinition`: Filters the output to include only the `taskDefinition` part.
  - `> task-definition.json`: Redirects the output to a file named `task-definition.json`.

### 6. Update Task Definition with New Image

```yaml
- name: Fill in new image ID in task definition
  id: task-def
  uses: aws-actions/amazon-ecs-render-task-definition@v1
  with:
    task-definition: task-definition.json 
    container-name: static-www 
    image: ${{ steps.build-image.outputs.image }}
```

- **Purpose**: Updates the downloaded task definition with the new Docker image URI.
- **Inputs**:
  - **task-definition**: Path to the task definition file (`task-definition.json`).
  - **container-name**: The name of the container in the task definition to update (`static-www`).
  - **image**: The new image URI obtained from the previous step's output.
- **ID**: Assigns an ID `task-def` to reference outputs from this step later.

### 7. Deploy Updated Task Definition to ECS

```yaml
- name: Deploy Amazon ECS task definition
  uses: aws-actions/amazon-ecs-deploy-task-definition@v1 
  with:
    task-definition: ${{ steps.task-def.outputs.task-definition }}
    service: static-www-service
    cluster: df1-cluster
```

- **Purpose**: Deploys the updated task definition to your ECS cluster and service.
- **Inputs**:
  - **task-definition**: The updated task definition file from the previous step.
  - **service**: The name of your ECS service (`static-www-service`).
  - **cluster**: The name of your ECS cluster (`df1-cluster`).

