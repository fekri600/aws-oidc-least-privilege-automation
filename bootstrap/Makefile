.ONESHELL:
.SHELLFLAGS = -e -o pipefail -c

deploy:
	@echo " Deploying bootstrap ..."
	terraform init && terraform apply -auto-approve
	
	@echo " Generating backend.tf..."
	bash backend_setup/generate_backend_file.sh "$$(terraform output -raw bucket_name)" "$$(terraform output -raw region)" "$$(terraform output -raw dynamodb_table_name)"


	@echo " Setting GitHub secrets..."
	gh secret set AWS_OIDC_ROLE_ARN --body "$$(terraform output -raw trust_role_github)"

	@echo "✅ Apply completed."

delete:
	@echo " Destroying GitHub bootstrap infrastructure..."
	
	terraform destroy -auto-approve

	@echo "✅ Delete completed."



