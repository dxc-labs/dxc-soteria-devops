# devops

The Soteria devops component declares and manages the process of ContinuousDelivery (CD) based upon a set of variables.

This process is driven by a lambda WebHook and CloudFormations to copy the internal DXC github components for a project [Soteria] to a local directory structure and then into AWS Code Commit in the right region(s).

The variable definitions and rules are available in the "component".yaml file, in this case devops.yaml

The basic configurations are stored in the ./config directory, in our case all.ini

as examples:

```bash
ProjectName=soteria
TenantName=dxc
AllComponents=access,api,badges,certificates,checkpoints,dashboards,devops,distribution,domains,forms,handbook,helloworld,identity,incidents,infrastructure,notifications,privacy,risk,rules,surveys,tracing
Components=access,api,badges,certificates,checkpoints,dashboards,devops,distribution,domains,forms,handbook,helloworld,identity,incidents,infrastructure,notifications,privacy,risk,rules,surveys,tracing
Environments=sbx,dev,stg,prd
DefaultRegion=us-east-1
DeployedRegions=us-east-1,eu-central-1,ap-south-1,ap-southeast-1,ap-southeast-2
ProductionApproversEmail=99999c7d.CSCPortal.onmicrosoft.com@amer.teams.ms
ProductionApproversSms=+15551234567
```

New Project Components must be registered in order to support change tracking and the continuous delivery capabilities.

The Project itself is deployed in sandboxes for each target "Environment" to each of the "DeployedRegions" and for differential "Tenants", with the promotion to Production creating a notification to an email alias such as teams and can also support SMS based notification.

The default EnvironmentNames [stages] are sbx [sandbox], dev [development], stg [staging], dmo [demo] and prd [production]

![Promotion Summary](https://mermaid.ink/img/eyJjb2RlIjoiZ3JhcGggQlRcbkEoc2J4KSAtLT58d2ViaG9va3wgQ1tkZXZdXG5CKG9kdCkgLS4tPnx3ZWJob29rfCBDXG5DIC0tPiB8dGVzdHwgRFtzdGddXG5EIC0tPiB8YXBwcm92YWx8IEVbcHJkXVxuRCAtLi0-IEYoZG1vKVxuIiwibWVybWFpZCI6eyJ0aGVtZSI6ImRlZmF1bHQifX0)

The resulting AWS component name will take the form of:

"${ProjectName}-${TenantName}-${EnvironmentName}-${ComponentName}" or "soteria-dxc-prd-checkpoints"

This naming scheme is an important component of the CI/CD pipeline and producing a successful SaaS approach to the system creating consistent component naming for external named network services and for internal integration.

## References

1. [Install Instructions](./Install-Instructions.md)
