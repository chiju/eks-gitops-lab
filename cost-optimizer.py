#!/usr/bin/env python3

import boto3
import json
from datetime import datetime, timedelta

def get_comprehensive_metrics(cloudwatch, instance_id, days=7):
    """Get CPU, Memory, Disk, and Network metrics"""
    
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=days)
    
    metrics = {}
    
    # CPU Utilization
    try:
        cpu_data = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average', 'Maximum']
        )
        if cpu_data['Datapoints']:
            metrics['cpu_avg'] = sum(dp['Average'] for dp in cpu_data['Datapoints']) / len(cpu_data['Datapoints'])
            metrics['cpu_max'] = max(dp['Maximum'] for dp in cpu_data['Datapoints'])
    except:
        metrics['cpu_avg'] = metrics['cpu_max'] = 0
    
    # Memory Utilization (from CloudWatch Agent if available)
    try:
        mem_data = cloudwatch.get_metric_statistics(
            Namespace='CWAgent',
            MetricName='mem_used_percent',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average', 'Maximum']
        )
        if mem_data['Datapoints']:
            metrics['mem_avg'] = sum(dp['Average'] for dp in mem_data['Datapoints']) / len(mem_data['Datapoints'])
            metrics['mem_max'] = max(dp['Maximum'] for dp in mem_data['Datapoints'])
        else:
            # Fallback: estimate from CPU (rough approximation)
            metrics['mem_avg'] = metrics['cpu_avg'] * 1.2  # Memory often correlates with CPU
            metrics['mem_max'] = metrics['cpu_max'] * 1.2
    except:
        metrics['mem_avg'] = metrics['cpu_avg'] * 1.2
        metrics['mem_max'] = metrics['cpu_max'] * 1.2
    
    # Disk Read/Write IOPS
    try:
        disk_read = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='DiskReadOps',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average']
        )
        disk_write = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='DiskWriteOps',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average']
        )
        
        metrics['disk_read_iops'] = sum(dp['Average'] for dp in disk_read['Datapoints']) / len(disk_read['Datapoints']) if disk_read['Datapoints'] else 0
        metrics['disk_write_iops'] = sum(dp['Average'] for dp in disk_write['Datapoints']) / len(disk_write['Datapoints']) if disk_write['Datapoints'] else 0
        metrics['total_iops'] = metrics['disk_read_iops'] + metrics['disk_write_iops']
    except:
        metrics['disk_read_iops'] = metrics['disk_write_iops'] = metrics['total_iops'] = 0
    
    # Network In/Out
    try:
        net_in = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='NetworkIn',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average']
        )
        net_out = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='NetworkOut',
            Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average']
        )
        
        metrics['network_in_mbps'] = (sum(dp['Average'] for dp in net_in['Datapoints']) / len(net_in['Datapoints']) * 8 / 1024 / 1024) if net_in['Datapoints'] else 0
        metrics['network_out_mbps'] = (sum(dp['Average'] for dp in net_out['Datapoints']) / len(net_out['Datapoints']) * 8 / 1024 / 1024) if net_out['Datapoints'] else 0
        metrics['total_network_mbps'] = metrics['network_in_mbps'] + metrics['network_out_mbps']
    except:
        metrics['network_in_mbps'] = metrics['network_out_mbps'] = metrics['total_network_mbps'] = 0
    
    return metrics

def get_instance_specs():
    """Instance type specifications"""
    return {
        't3.micro': {'vcpu': 2, 'memory_gb': 1, 'network_mbps': 5000, 'cost_hourly': 0.0104},
        't3.small': {'vcpu': 2, 'memory_gb': 2, 'network_mbps': 5000, 'cost_hourly': 0.0208},
        't3.medium': {'vcpu': 2, 'memory_gb': 4, 'network_mbps': 5000, 'cost_hourly': 0.0416},
        't3.large': {'vcpu': 2, 'memory_gb': 8, 'network_mbps': 5000, 'cost_hourly': 0.0832},
        't3.xlarge': {'vcpu': 4, 'memory_gb': 16, 'network_mbps': 5000, 'cost_hourly': 0.1664},
        'm5.large': {'vcpu': 2, 'memory_gb': 8, 'network_mbps': 10000, 'cost_hourly': 0.096},
        'm5.xlarge': {'vcpu': 4, 'memory_gb': 16, 'network_mbps': 10000, 'cost_hourly': 0.192},
        'c5.large': {'vcpu': 2, 'memory_gb': 4, 'network_mbps': 10000, 'cost_hourly': 0.085}
    }

def analyze_rightsizing(metrics, current_type):
    """Comprehensive rightsizing analysis"""
    
    specs = get_instance_specs()
    current_spec = specs[current_type]
    current_monthly = current_spec['cost_hourly'] * 24 * 30
    
    # Calculate utilization percentages
    cpu_util = metrics['cpu_avg']
    mem_util = metrics['mem_avg']
    cpu_max_util = metrics['cpu_max']
    mem_max_util = metrics['mem_max']
    
    # Rightsizing logic
    recommendations = []
    
    # Check if underutilized (all resources < 30% avg, < 60% max)
    if cpu_util < 30 and mem_util < 30 and cpu_max_util < 60 and mem_max_util < 60:
        # Suggest smaller instances
        for instance_type, spec in specs.items():
            if (spec['vcpu'] <= current_spec['vcpu'] and 
                spec['memory_gb'] <= current_spec['memory_gb'] and
                spec['cost_hourly'] < current_spec['cost_hourly']):
                
                new_monthly = spec['cost_hourly'] * 24 * 30
                savings = current_monthly - new_monthly
                
                recommendations.append({
                    'type': instance_type,
                    'reason': 'Underutilized - downsize',
                    'savings': savings,
                    'new_cost': new_monthly,
                    'fit_score': calculate_fit_score(metrics, spec)
                })
    
    # Check if overutilized (CPU > 80% or Memory > 80% or max > 90%)
    elif cpu_util > 80 or mem_util > 80 or cpu_max_util > 90 or mem_max_util > 90:
        # Suggest larger instances
        for instance_type, spec in specs.items():
            if (spec['vcpu'] >= current_spec['vcpu'] and 
                spec['memory_gb'] >= current_spec['memory_gb'] and
                spec['cost_hourly'] > current_spec['cost_hourly']):
                
                new_monthly = spec['cost_hourly'] * 24 * 30
                additional_cost = new_monthly - current_monthly
                
                recommendations.append({
                    'type': instance_type,
                    'reason': 'Overutilized - upsize',
                    'savings': -additional_cost,
                    'new_cost': new_monthly,
                    'fit_score': calculate_fit_score(metrics, spec)
                })
    
    # Check for better instance family matches
    else:
        # CPU-optimized workload
        if cpu_util > mem_util * 1.5:
            for instance_type, spec in specs.items():
                if (instance_type.startswith('c5') and 
                    spec['cost_hourly'] <= current_spec['cost_hourly'] * 1.1):
                    
                    new_monthly = spec['cost_hourly'] * 24 * 30
                    savings = current_monthly - new_monthly
                    
                    recommendations.append({
                        'type': instance_type,
                        'reason': 'CPU-optimized workload',
                        'savings': savings,
                        'new_cost': new_monthly,
                        'fit_score': calculate_fit_score(metrics, spec)
                    })
        
        # Memory-optimized workload
        elif mem_util > cpu_util * 1.5:
            for instance_type, spec in specs.items():
                if (instance_type.startswith('m5') and 
                    spec['memory_gb'] >= current_spec['memory_gb'] and
                    spec['cost_hourly'] <= current_spec['cost_hourly'] * 1.1):
                    
                    new_monthly = spec['cost_hourly'] * 24 * 30
                    savings = current_monthly - new_monthly
                    
                    recommendations.append({
                        'type': instance_type,
                        'reason': 'Memory-optimized workload',
                        'savings': savings,
                        'new_cost': new_monthly,
                        'fit_score': calculate_fit_score(metrics, spec)
                    })
    
    # Sort by best fit score and return top recommendation
    if recommendations:
        recommendations.sort(key=lambda x: x['fit_score'], reverse=True)
        return recommendations[0]
    else:
        return {
            'type': current_type,
            'reason': 'Well-sized for current workload',
            'savings': 0,
            'new_cost': current_monthly,
            'fit_score': 100
        }

def calculate_fit_score(metrics, spec):
    """Calculate how well an instance type fits the workload"""
    
    # Avoid over-provisioning penalty
    cpu_fit = max(0, 100 - abs(metrics['cpu_avg'] - 50))  # Ideal ~50% utilization
    mem_fit = max(0, 100 - abs(metrics['mem_avg'] - 50))
    
    # Network fit (basic check)
    network_fit = 100 if metrics['total_network_mbps'] < spec['network_mbps'] * 0.8 else 50
    
    # Cost efficiency
    cost_fit = 100 if spec['cost_hourly'] < 0.1 else 80
    
    return (cpu_fit + mem_fit + network_fit + cost_fit) / 4

def generate_comprehensive_recommendations():
    """Generate comprehensive rightsizing recommendations"""
    
    session = boto3.Session(profile_name='oth_infra')
    ec2_client = session.client('ec2', region_name='eu-central-1')
    cloudwatch = session.client('cloudwatch', region_name='eu-central-1')
    
    instances = ec2_client.describe_instances(
        Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
    )
    
    recommendations = []
    
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            instance_type = instance['InstanceType']
            
            print(f"Analyzing {instance_id} ({instance_type})...")
            
            # Get comprehensive metrics
            metrics = get_comprehensive_metrics(cloudwatch, instance_id)
            
            # Analyze rightsizing
            recommendation = analyze_rightsizing(metrics, instance_type)
            
            recommendations.append({
                'instance_id': instance_id,
                'current_type': instance_type,
                'metrics': metrics,
                'recommendation': recommendation
            })
    
    return recommendations

if __name__ == "__main__":
    recommendations = generate_comprehensive_recommendations()
    
    print("\n🤖 COMPREHENSIVE RIGHTSIZING ANALYSIS")
    print("=" * 60)
    
    total_savings = 0
    
    for rec in recommendations:
        metrics = rec['metrics']
        recommendation = rec['recommendation']
        
        print(f"\n📊 Instance: {rec['instance_id']} ({rec['current_type']})")
        print(f"   CPU: {metrics['cpu_avg']:.1f}% avg, {metrics['cpu_max']:.1f}% max")
        print(f"   Memory: {metrics['mem_avg']:.1f}% avg, {metrics['mem_max']:.1f}% max")
        print(f"   Disk IOPS: {metrics['total_iops']:.1f} avg")
        print(f"   Network: {metrics['total_network_mbps']:.2f} Mbps avg")
        print(f"   💡 Recommendation: {recommendation['type']}")
        print(f"   📝 Reason: {recommendation['reason']}")
        print(f"   💰 Monthly Impact: ${recommendation['savings']:.2f}")
        print(f"   🎯 Fit Score: {recommendation['fit_score']:.1f}/100")
        
        total_savings += recommendation['savings']
    
    print(f"\n💰 TOTAL POTENTIAL MONTHLY SAVINGS: ${total_savings:.2f}")
    
    if total_savings > 0:
        print(f"💡 Annual Savings: ${total_savings * 12:.2f}")
        print(f"📈 Cost Reduction: {(total_savings / 135) * 100:.1f}%")  # Assuming ~$135 current cost
