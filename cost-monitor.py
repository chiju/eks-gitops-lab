#!/usr/bin/env python3

import boto3
import json
from datetime import datetime, timedelta
from decimal import Decimal

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def get_eks_costs():
    """Get comprehensive EKS cost breakdown"""
    
    # Initialize clients
    session = boto3.Session(profile_name='oth_infra')
    ce_client = session.client('ce', region_name='us-east-1')  # Cost Explorer is only in us-east-1
    ec2_client = session.client('ec2', region_name='eu-central-1')
    eks_client = session.client('eks', region_name='eu-central-1')
    logs_client = session.client('logs', region_name='eu-central-1')
    
    # Date range for cost analysis
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=30)
    
    print("🎯 EKS Cost Analysis")
    print(f"📅 Period: {start_date} to {end_date}")
    print("=" * 50)
    
    # 1. Get EKS cluster info
    try:
        cluster = eks_client.describe_cluster(name='eks-lab-argocd')
        print(f"🏗️  EKS Cluster: {cluster['cluster']['name']}")
        print(f"   Version: {cluster['cluster']['version']}")
        print(f"   Status: {cluster['cluster']['status']}")
        print(f"   Created: {cluster['cluster']['createdAt'].strftime('%Y-%m-%d')}")
        
        # EKS Control Plane cost (fixed)
        control_plane_hourly = 0.10
        control_plane_monthly = control_plane_hourly * 24 * 30
        print(f"   Control Plane Cost: ${control_plane_monthly:.2f}/month")
        
    except Exception as e:
        print(f"❌ Error getting EKS info: {e}")
    
    print()
    
    # 2. Get EC2 instances (EKS nodes)
    try:
        instances = ec2_client.describe_instances(
            Filters=[
                {'Name': 'instance-state-name', 'Values': ['running']},
                {'Name': 'tag:kubernetes.io/cluster/eks-lab-argocd', 'Values': ['owned']}
            ]
        )
        
        print("🖥️  EKS Worker Nodes:")
        total_node_cost = 0
        
        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                instance_type = instance['InstanceType']
                launch_time = instance['LaunchTime']
                
                # Rough cost estimation for common instance types
                cost_per_hour = {
                    't3.micro': 0.0104,
                    't3.small': 0.0208,
                    't3.medium': 0.0416,
                    't3.large': 0.0832,
                    'm5.large': 0.096,
                    'm5.xlarge': 0.192
                }.get(instance_type, 0.05)  # Default estimate
                
                monthly_cost = cost_per_hour * 24 * 30
                total_node_cost += monthly_cost
                
                print(f"   {instance['InstanceId']} ({instance_type})")
                print(f"   └─ Cost: ${monthly_cost:.2f}/month")
        
        print(f"   Total Node Cost: ${total_node_cost:.2f}/month")
        
    except Exception as e:
        print(f"❌ Error getting EC2 info: {e}")
    
    print()
    
    # 3. Get EBS volumes
    total_storage_cost = 0
    try:
        volumes = ec2_client.describe_volumes(
            Filters=[{'Name': 'status', 'Values': ['in-use']}]
        )
        
        print("💾 EBS Volumes:")
        total_storage_cost = 0
        
        for volume in volumes['Volumes']:
            size_gb = volume['Size']
            volume_type = volume['VolumeType']
            
            # EBS pricing (rough estimates for eu-central-1)
            cost_per_gb = {
                'gp2': 0.10,
                'gp3': 0.08,
                'io1': 0.125,
                'io2': 0.125
            }.get(volume_type, 0.10)
            
            monthly_cost = size_gb * cost_per_gb
            total_storage_cost += monthly_cost
            
            print(f"   {volume['VolumeId']} ({volume_type}, {size_gb}GB)")
            print(f"   └─ Cost: ${monthly_cost:.2f}/month")
        
        print(f"   Total Storage Cost: ${total_storage_cost:.2f}/month")
        
    except Exception as e:
        print(f"❌ Error getting EBS info: {e}")
        total_storage_cost = 0
    
    print()
    
    # 4. Get CloudWatch Log Groups
    try:
        log_groups = logs_client.describe_log_groups()
        
        print("📊 CloudWatch Log Groups:")
        total_log_cost = 0
        
        for log_group in log_groups['logGroups']:
            if '/aws/eks' in log_group['logGroupName'] or '/aws/vpc' in log_group['logGroupName']:
                stored_bytes = log_group.get('storedBytes', 0)
                stored_gb = stored_bytes / (1024**3)
                
                # CloudWatch Logs pricing: $0.50 per GB ingested, $0.03 per GB stored
                monthly_storage_cost = stored_gb * 0.03
                total_log_cost += monthly_storage_cost
                
                print(f"   {log_group['logGroupName']}")
                print(f"   └─ Size: {stored_gb:.2f}GB, Cost: ${monthly_storage_cost:.2f}/month")
        
        print(f"   Total Log Cost: ${total_log_cost:.2f}/month")
        
    except Exception as e:
        print(f"❌ Error getting CloudWatch info: {e}")
    
    print()
    
    # 5. Try to get actual cost data (if Cost Explorer is enabled)
    try:
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ]
        )
        
        print("💰 Actual AWS Costs (Last 30 days):")
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                service = group['Keys'][0]
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                if cost > 0.01:  # Only show costs > $0.01
                    print(f"   {service}: ${cost:.2f}")
        
    except Exception as e:
        print(f"⚠️  Cost Explorer not available: {e}")
        print("   (Enable Cost Explorer in AWS Console for actual cost data)")
    
    print()
    
    # 6. Cost Summary and Recommendations
    estimated_total = control_plane_monthly + total_node_cost + total_storage_cost + total_log_cost
    
    print("📈 COST SUMMARY:")
    print(f"   EKS Control Plane: ${control_plane_monthly:.2f}/month")
    print(f"   Worker Nodes: ${total_node_cost:.2f}/month")
    print(f"   EBS Storage: ${total_storage_cost:.2f}/month")
    print(f"   CloudWatch Logs: ${total_log_cost:.2f}/month")
    print(f"   Data Transfer (est): $10-20/month")
    print("   " + "="*30)
    print(f"   ESTIMATED TOTAL: ${estimated_total + 15:.2f}/month")
    
    print()
    print("💡 COST OPTIMIZATION TIPS:")
    print("   • Use Spot instances for dev/test workloads")
    print("   • Enable EBS GP3 volumes (20% cheaper than GP2)")
    print("   • Set CloudWatch log retention policies")
    print("   • Use EKS Fargate for variable workloads")
    print("   • Enable Container Insights selectively")
    print("   • Use Reserved Instances for production")

if __name__ == "__main__":
    get_eks_costs()
