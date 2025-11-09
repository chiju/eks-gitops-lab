.PHONY: apply destroy clean

apply:
	cd terraform && terraform apply

destroy:
	@echo "🧹 Cleaning up Karpenter resources..."
	kubectl delete application karpenter -n argocd --ignore-not-found=true
	@echo "⏱️  Waiting 60s for nodes to terminate..."
	@sleep 60
	@echo "🗑️  Destroying infrastructure..."
	cd terraform && terraform destroy

clean:
	kubectl delete nodeclaim --all --ignore-not-found=true
	kubectl delete nodepool --all --ignore-not-found=true
	kubectl delete ec2nodeclass --all --ignore-not-found=true
