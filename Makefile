.ONESHELL:
.SHELLFLAGS = -e -o pipefail -c

# Default target
.DEFAULT_GOAL := help

help: ## Show available make commands
	@echo "Available commands:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

apply-bt: ## Deploy bootstrap and configure GitHub secrets
	@echo " Deploying bootstrap ..."
	terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply -auto-approve
	
	@echo " Generating storage backend.tf..."
	bash bootstrap/modules/backend-bucket/generate-backend-file.sh "$$(terraform -chdir=bootstrap output -raw bucket_name)"  "$$(terraform -chdir=bootstrap output -raw region)" "envs/terraform.tfstate" "backend.tf"

	@echo " Setting GitHub secrets..."
	gh secret set AWS_OIDC_ROLE_ARN --body "$$(terraform -chdir=bootstrap output -raw trust_role_github)"
	gh secret set CTS_LAKE_EDS_ARN --body "$$(terraform -chdir=bootstrap output -raw cloudtrail_event_data_store_arn)"
	gh secret set AWS_CLOUDTRAIL_ARN --body "$$(terraform -chdir=bootstrap output -raw cloudtrail_arn)"
	gh secret set AWS_ACCESS_ANALYZER_ROLE_ARN --body "$$(terraform -chdir=bootstrap output -raw access_analyzer_role_arn)"

	@echo "✓ Apply completed."

delete-bt: ## Destroy GitHub bootstrap infrastructure
	@echo " Destroying GitHub bootstrap infrastructure..."
	terraform -chdir=bootstrap destroy -auto-approve
	@echo "✓ Delete completed."
