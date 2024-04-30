locals {
  open_api_specification = jsondecode(file("${path.module}/swagger.json"))

  operations = flatten([
    for endpoint in local.open_api_specification.paths : [
      for endpointType in endpoint : {
        operationId = endpointType.operationId
        policy = templatefile("${path.module}/policies/operation_policy.tmpl", {
          tags = endpointType.tags
        })
      }
    ]
  ])
}