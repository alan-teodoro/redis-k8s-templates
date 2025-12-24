# Redis Enterprise on Amazon EKS

Redis Enterprise deployment guides and configurations for Amazon Elastic Kubernetes Service (EKS).

## Overview

This directory contains EKS-specific configurations for deploying Redis Enterprise, including:
- Storage configurations (EBS CSI driver, storage classes)
- Networking (VPC, security groups, NLB/ALB)
- IAM roles and policies (IRSA)
- Complete deployment examples

## Directory Structure

```
eks/
├── storage/            # EBS CSI driver, storage classes, PVC examples
├── networking/         # VPC, security groups, load balancers
├── iam/                # IAM roles, policies, IRSA configuration
└── examples/           # Complete end-to-end deployment examples
```

## Prerequisites

- EKS cluster (1.23+)
- kubectl configured for your cluster
- AWS CLI configured
- Cluster admin access
- EBS CSI driver installed (for persistent storage)

## EKS-Specific Considerations

### Storage
- **EBS CSI Driver**: Required for persistent volumes
- **Storage Classes**: gp3 (recommended), io2 for high performance
- **Volume Types**: gp3 for general use, io2 for production workloads
- **Encryption**: Enable EBS encryption at rest

### Networking
- **Load Balancer**: Use NLB (Network Load Balancer) for Redis services
- **Security Groups**: Configure for Redis ports (8443, 9443, database ports)
- **VPC**: Ensure proper subnet configuration
- **Private vs Public**: Recommend private subnets for Redis

### IAM & Security
- **IRSA**: Use IAM Roles for Service Accounts for secrets access
- **KMS**: Use AWS KMS for encryption keys
- **Secrets Manager**: Optional integration for database credentials

### Sizing
- **Node Types**: m5.xlarge minimum (4 vCPU, 16GB RAM)
- **Recommended**: m5.2xlarge or r5.2xlarge for production
- **Storage**: 100GB minimum per node, 500GB+ for production

## Quick Start

### 1. Install EBS CSI Driver

```bash
# Add the EBS CSI driver Helm repository
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

# Install the driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system
```

### 2. Create Storage Class

```bash
kubectl apply -f storage/gp3-storageclass.yaml
```

### 3. Install Redis Enterprise Operator

```bash
helm repo add redis https://helm.redis.io/
helm install redis-operator redis/redis-enterprise-operator \
  -n redis-system --create-namespace
```

### 4. Deploy Redis Enterprise Cluster

See `../../examples/basic-deployment/` directory for complete deployment examples.

## Storage Configuration

**Location:** `storage/`

- **gp3-storageclass.yaml** - General purpose SSD (recommended, set as default)
- **io2-storageclass.yaml** - High performance SSD (production)

**Recommended Storage Class:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: redis-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

## Networking Configuration

**Location:** `networking/`

### Load Balancer Service

Use NLB for external access:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8443
```

### Security Groups

Configure security groups to allow:
- **8443**: Redis Enterprise API
- **9443**: Redis Enterprise cluster communication
- **10000-19999**: Database ports

## IAM Configuration

**Location:** `iam/`

### IRSA for External Secrets

Example IAM policy for accessing AWS Secrets Manager:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:redis/*"
    }
  ]
}
```

## Examples

**Location:** `../../examples/`

Complete deployment examples:
- **basic-deployment/** - Simple single-cluster deployment (cloud-agnostic)

For EKS-specific configurations, see the storage and networking sections in this directory.

## Cost Optimization

- Use gp3 instead of gp2 for storage (better performance, lower cost)
- Use Spot instances for non-production workloads
- Enable cluster autoscaler
- Right-size node types based on workload

## Monitoring

Integrate with:
- **CloudWatch**: Container Insights for EKS
- **Prometheus**: See `../../monitoring/prometheus/`
- **Grafana**: See `../../monitoring/grafana/`

## Troubleshooting

### EBS Volume Not Attaching

**Check:**
```bash
kubectl describe pvc <pvc-name>
kubectl get events --sort-by='.lastTimestamp'
```

**Common causes:**
- EBS CSI driver not installed
- IAM permissions missing
- Availability zone mismatch

### LoadBalancer Service Stuck in Pending

**Check:**
```bash
kubectl describe svc <service-name>
```

**Common causes:**
- AWS Load Balancer Controller not installed
- Subnet tags missing
- Security group issues

## Next Steps

1. Review storage configuration in `storage/`
2. Create gp3 StorageClass as default: `kubectl apply -f storage/gp3-storageclass.yaml`
3. Deploy Redis Enterprise using generic examples: `../../examples/basic-deployment/`
4. Configure monitoring: `../../monitoring/prometheus/`
5. Review EKS-specific troubleshooting: `TROUBLESHOOTING.md`

## Resources

- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

