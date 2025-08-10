.ONESHELL:
.SHELLFLAGS = -e -o pipefail -c

deploy:
	@echo " Deploying bootstrap ..."
	terraform init && terraform apply -auto-approve
	
	@echo " Generating backend.tf..."
	bucket_name=$(terraform output -raw bucket_name) && \
	region=$(terraform output -raw region) && \
	dynamodb_table_name=$(terraform output -raw dynamodb_table_name) && \
	echo  $bucket_name 
	
	
	bash backend_setup/generate_backend_file.sh "${bucket_name}" "${region}" "${dynamodb_table_name}"
	


	bash backend_setup/generate_backend_file.sh

	@echo " Setting GitHub secrets..."
	gh secret set AWS_OIDC_ROLE_ARN --body "$$(terraform output -raw trust_role_github)"

	@echo "✅ Apply completed."


delete:
	@echo " Destroying GitHub bootstrap infrastructure..."
	
	terraform destroy -auto-approve

	@echo "✅ Delete completed."



