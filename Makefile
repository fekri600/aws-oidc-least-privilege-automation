.ONESHELL:
.SHELLFLAGS = -e -o pipefail -c

apply-bootstrap:
	@echo " Deploying bootstrap ..."
	terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply -auto-approve
	
	@echo " Generating root backend.tf..."
	bash bootstrap/modules/backend-bucket/generate-backend-file.sh "$$(terraform -chdir=bootstrap output -raw bucket_name)"  "$$(terraform -chdir=bootstrap output -raw region)" "backend.tf"
    
	@echo " Generating storage backend.tf..."
	bash bootstrap/modules/backend-bucket/generate-backend-file.sh "$$(terraform -chdir=bootstrap output -raw bucket_name)"  "$$(terraform -chdir=bootstrap output -raw region)" "env/shared/global/storage/backend.tf"


	@echo " Setting GitHub secrets..."
	gh secret set AWS_OIDC_ROLE_ARN --body "$$(terraform -chdir=bootstrap output -raw trust_role_github)"

	@echo "✓ Apply completed."

delete-bootstrap:
	@echo " Destroying GitHub bootstrap infrastructure..."
	
	terraform -chdir=bootstrap destroy -auto-approve

	@echo "✓ Delete completed."



