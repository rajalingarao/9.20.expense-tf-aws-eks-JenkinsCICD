
# Project consists of below componets:
    9.20.expense-tf-aws-eks-JenkinsCICD
    9.21.tf-aws-eks-tools-jenkins
    9.22.Jenkins-backend-eks
    9.23.Jenkins-frontend-eks


# Infrastructure creation and deletion

```
for i in 00-vpc/ 10-sg/ 20-db/ 30-bastion/ 40-eks/ 50-acm/ 60-ingress-alb/ 70-ecr/ ; do cd $i; terraform init -reconfigure; cd .. ; done 
```
```
for i in 00-vpc/ 10-sg/ 20-db/ 30-bastion/ 40-eks/ 50-acm/ 60-ingress-alb/ 70-ecr/  ; do cd $i; terraform plan; cd .. ; done 
```
```
for i in 00-vpc/ 10-sg/ 20-db/ 30-bastion/ 40-eks/ 50-acm/ 60-ingress-alb/ 70-ecr/ ; do cd $i; terraform apply -auto-approve; cd .. ; done 
```
```
for i in  70-ecr/ 60-ingress-alb/ 50-acm/ 40-eks/ 30-bastion/ 20-db/ 10-sg/ 00-vpc/; do cd $i; terraform destroy -auto-approve; cd .. ; done 
```

# Infrastructure

![alt text](eks-infra.svg)

Creating above infrastructure involves lot of steps, as maintained sequence we need to create
* VPC
* All security groups and rules
* Bastion Host, VPN
* EKS
* RDS
* ACM for ingress
* ALB as ingress controller
* ECR repo to host images
* CDN

## Sequence

* (Required). create VPC first
* (Required). create SG after VPC
* (Required). create bastion host. It is used to connect RDS and EKS cluster.
* (Optional). VPN, same as bastion but a windows laptop can directly connect to VPN and get access of RDS and EKS.
* (Required). RDS. Create RDS because we don't create databases in Kubernetes.
* (Required). ACM. It is required to get SSL certificates for our ALB ingress controller.
* (Required). ingress ALB is required to expose our applications to outside world.
* (Required). ECR. We need to create ECR repo to host the application images.
* (Optional). CDN is optional. but good to have.

### Admin activities

**Bastion**
* SSH to bastion host
* run below command and configure the credentials.
```
aws configure
```
* get the kubernetes config using below command
```
aws eks update-kubeconfig --region us-east-1 --name expense-dev
```
* Now you should be able to connect K8 cluster
```
kubectl get nodes
```
Create a namespace
```
kubectl create namespace expense
```
**RDS**:
* Connect to RDS using bastion:
```
mysql -h db-dev.lithesh.shop -u root -pExpenseApp1
```

We are creating schema while creating RDS. But table should be created.
Refer backend.sql to create
Table
User
flush privileges

* CREATE DATABASE IF NOT EXISTS transactions;   
* Created already transactions database through terraform code
* db_name  = "transactions" #default schema for expense project

```
USE transactions;
```
```
CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    amount INT,
    description VARCHAR(255)
);
```

* Create the User:
```
CREATE USER IF NOT EXISTS 'expense'@'%' IDENTIFIED BY 'ExpenseApp1';
```
* Creates a MySQL user named expense that can connect from any host ('%').

```
GRANT ALL ON transactions.* TO 'expense'@'%';
```
```
FLUSH PRIVILEGES;
```

**Ingress Controller**

Ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.8/
* Connect to K8 cluster from bastion host.
* Create an IAM OIDC provider. You can skip this step if you already have one for your cluster.
```
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster expense-dev --approve
```
* Download an IAM policy for the LBC using one of the following commands:
```
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.2/docs/install/iam_policy.json
```

* Create an IAM policy named AWSLoadBalancerControllerIAMPolicy. If you downloaded a different policy, replace iam-policy with the name of the policy that you downloaded.
```
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json
```

* (Optional) Use Existing Policy:
```
aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text

```

* Create a IAM role and ServiceAccount for the AWS Load Balancer controller, use the ARN from the step above

```
eksctl create iamserviceaccount \
--cluster=expense-dev \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::805778285734:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region us-east-1 \
--approve
```

* Add the EKS chart repo to Helm
```
helm repo add eks https://aws.github.io/eks-charts
```

* Delete the Existing ServiceAccount (Safe if not in Use Yet)
* If the controller isn’t in active use (or you’re setting it up for the first time), delete the ServiceAccount and reinstall:
```
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system
```

* Helm install command for clusters with IRSA:

```
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=expense-dev
```

* check aws-load-balancer-controller is running in kube-system namespace.
```
kubectl get pods -n kube-system
```

```
kubectl get nodes
```
```
kubens expense
```
```
kubectl get pods
```

* Please run the 'aws configure' on jenkins-agent on ec2-user.
    * aws configure
    * Access Key
    * Secret Access Key
    * Default Region name
    * Default output format


* Trouble shooting the Mysql Database:

* Connect to RDS using bastion host.
```
mysql -h db-dev.lithesh.shop -u root -pExpenseApp1
```

```
USE transactions;
```

```
Select * from transactions;
```

* Resource delete steps
    First Delete all applications frontend, backend, db.
    Second Delete all Tools Jenkins, all others
    Third Delete infra and its denpendencies.


* Important Points:
* Note:  Before deploy is the process of calling another pipeline cd-deploy. Now deploy is the creating manifest files.

* Note: We can templatize our application means replacing component values backend, frontend dynamically. For this, We use helm in Kubernetes for templatizing the entire project.

* Note: For EKS Cluster deployment, we use a Pipeline Project, not a multibranch pipeline — so BRANCH_NAME is not available.
For Shared Pipelines, we use Multibranch Pipelines, where BRANCH_NAME is available

* Note: For EKS Cluster deployment, We use Jenkins pipeline project, not the multi branch pipeline. for Shared Pipeline project, we use multi branch pipeline, the default variable available BRANCH_NAME available in multi-branch pipeline, not in pipeline project in Jenkins CICD
