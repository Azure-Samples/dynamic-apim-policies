# Dynamic Azure API Management Policies

In Azure API Management (APIM), you can apply **policies** to your API in order to define how requests and responses should be processed. As your API landscape grows, maintaining multiple policy files for each endpoint can become cumbersome.

This repository provides a solution through the use of **Terraform templates** to dynamically generate XML policies for use in Azure API Management (APIM). By using a *single template*, you can create tailored policies for each API endpoint, simplifying maintenance and reducing redundancy.

## Features

- **Dynamic Policy Generation**: Instead of managing multiple XML policy files, this approach allows you to define policies in a single template. 💫

- **Swagger and OpenAPI Integration**: Leverage tags from your Swagger or OpenAPI definitions to customize policies for each endpoint. 🏷️

- **Easy Deployment**: Follow the sample to deploy a basic APIM resource with customized policies. 🚀

## Getting Started

### Prerequisites

1. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
2. [Install and configure Terraform](https://learn.microsoft.com/en-us/azure/developer/terraform/quickstart-configure)
3. [Install the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

### Quickstart

1. **Clone the Repository**:

```cmd
git clone <repo-url-todo>
cd <repo-name-todo>
```

2. **Login to your Azure account**:

```cmd
az login
```

3. **Initialize Terraform**:
Run terraform init to initialize the Terraform deployment. This command downloads the Azure provider required to manage your Azure resources.

```cmd
terraform init -upgrade
```

4. **Create a Terraform execution plan**:
Run terraform plan to create an execution plan.

```cmd
terraform plan -out main.tfplan
```

5. **Apply a Terraform execution plan**:
Run terraform apply to apply the execution plan to your cloud infrastructure.

```cmd
terraform apply main.tfplan
```

## How it works

### Defining our API and tags

Within the `Api` folder you'll find a minimal C# example which creates an API, adds some basic routes, and assigns that route a tag.

```cs
app.MapGet("/example", () => Results.Ok())
    .WithName("GetExample")
    .WithOpenApi()
    .WithTags("RequiredRole=ExampleRole");
```

### Generating our Swagger file

In order to generate our Swagger file, we can take two approaches:

1. Manually create a Swagger file and maintain it as part of the repository. This can be done by using the `Swashbuckle.AspNetCore` cli tool, or by using the Swagger UI.

2. Automatically generate the Swagger file at runtime or as part of the build pipeline. An example of how this can be done is included in the `build-and-publish-swagger-file.yaml` file. This file is a Azure Devops pipeline, it uses the `Swashbuckle.AspNetCore` cli tool to generate the Swagger file, and then publishes it as an artifact. This artifact can then be used in the CD pipeline to deploy the APIM resource.

### Generating our policies

Our policy template is defined in the `operation_policy.tmpl` file. It includes a policy definition which is applied to **inbound** requests.

It includes the [validate-jwt](https://learn.microsoft.com/en-us/azure/api-management/validate-jwt-policy) policy which enforces the existence and validity of a supported JSON web token (JWT), which is used for authentication and authorization.

Lastly, it contains the portion of the Terraform template which is later rendered depending on the **tags** supplied. In this instance, if the operation has tags which include the string "RequiredRole", then for each of those tags, they will be added as a role in the required claims.

```xml
<policies>
    <inbound>
        <base />
        <validate-jwt header-name="Authorization" require-scheme="Bearer">
            %{~ if strcontains((join(";", tags)), "RequiredRole")~}
            <required-claims>
                <claim name="roles" match="all">
                %{~ for tag in tags ~}
                    %{~ if strcontains(tag, "RequiredRole=") ~}
                    <value>${substr(tag, 13, length(tag) - 1)}</value>
                    %{~ endif ~}
                %{~ endfor ~}
                </claim>
            </required-claims>
            %{~ endif ~}
        </validate-jwt>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

The following is an example of how this policy appears when rendered:

```xml
<policies>
    <inbound>
        <base />
        <validate-jwt header-name="Authorization" require-scheme="Bearer">
            <required-claims>
                <claim name="roles" match="all">
                    <value>ExampleRole</value>
                </claim>
            </required-claims>
        </validate-jwt>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

### Rendering the template

Within the `locals.tf` file is a function which takes each of the operations defined in the Swagger file, and supplies its tags as variables to the `templatefile` function, which is a built-in Terraform function used to render a template file.

Then, in the `main.tf` file - which is responsible for the deployment of the APIM resource - there is an `azurerm_api_management_api_operation_policy` resource. This takes each of the operations, and their respective rendered XML policy, and deploys each to APIM using Terraform:

```tf
resource "azurerm_api_management_api_operation_policy" "example" {
  for_each = {for op in local.operations : op.operationId => op}

  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_name            = azurerm_api_management_api.example.name

  operation_id = each.value.operationId
  xml_content  = each.value.policy
}
```

### Hints and tips

- In our policy, we used `validate-jwt`. To validate a JWT that was provided by the Microsoft Entra service, API Management also provides the [validate-azure-ad-token](https://learn.microsoft.com/en-us/azure/api-management/validate-azure-ad-token-policy) policy.

- For more details and examples on how you can customize your policy, see the [API Management policy reference](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies).

## Contributing

Contributions are welcome! If you encounter issues or have suggestions, please open an issue or submit a pull request. ✨

## License

This project is licensed under the MIT License. See the LICENSE file for details.