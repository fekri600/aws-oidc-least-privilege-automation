.ONESHELL:
.SHELLFLAGS = -e -o pipefail -c

apply-bt:
	@echo " Deploying bootstrap ..."
	terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply -auto-approve
	
	@echo " Generating root backend.tf..."
	bash bootstrap/modules/backend-bucket/generate-backend-file.sh "$$(terraform -chdir=bootstrap output -raw bucket_name)"  "$$(terraform -chdir=bootstrap output -raw region)" "terraform.tfstate" "backend.tf"
    
	@echo " Generating storage backend.tf..."
	bash bootstrap/modules/backend-bucket/generate-backend-file.sh "$$(terraform -chdir=bootstrap output -raw bucket_name)"  "$$(terraform -chdir=bootstrap output -raw region)" "envs/storage/terraform.tfstate" "env/shared/global/storage/backend.tf"


	@echo " Setting GitHub secrets..."
	gh secret set AWS_OIDC_ROLE_ARN --body "$$(terraform -chdir=bootstrap output -raw trust_role_github)"

	@echo " Setting CTS_LAKE_EDS_ARN..."
	gh secret set CTS_LAKE_EDS_ARN --body "$$(terraform -chdir=bootstrap output -raw cloudtrail_event_data_store_arn)"

	@echo " Saving CI role ARN to SSM parameter..."
	aws ssm put-parameter \
		--name "/tf-rds-cross-region-dr/ci-role-arn" \
		--value "$$(terraform -chdir=bootstrap output -raw trust_role_github)" \
		--type "String" \
		--overwrite

	@echo "✓ Apply completed."

delete-bt:
	@echo " Destroying GitHub bootstrap infrastructure..."
	
	terraform -chdir=bootstrap destroy -auto-approve

	@echo "✓ Delete completed."



