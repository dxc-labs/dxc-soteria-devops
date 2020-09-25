# Install Instructions

Configure global environment one time for multiple tenants hosted in same AWS account.

## 1. Global Environment

To be run once for all tenants of a given project name and environment combination.

> This is already done for sandbox environment in dxc-techlabs account.  Therefore, you don't have to do this step for sandbox in this AWS account.  Jump to [2. Tenant](#2-tenant)

### 1.1. Get Source Code

```bash
GitHubOrgName='soteria'
TenantName='global'
# Standard environments are: sbx, dev, stg, prd
EnvironmentName='sbx' # For example

mkdir ${GitHubOrgName}/${TenantName}
cd ${GitHubOrgName}/${TenantName}

git clone git@github.dxc.com:${GitHubOrgName}/devops     # for deploy scripts
cd devops
```

### 1.2. Configure

1. Update [all.ini](config/all.ini) with Project Name and TenantName
2. Set parameters **UserDomainName** and **PublicDomainName** in **domains** config files
3. Set parameter **DomainHosting** to _hosted_ in **domains** and **certificates** config files

* For illustration, check soteria-global-sbx.json sample in **domains** and **certificates** repos.

### 1.3. Deploy

#### 1.3.1 Setup to Mirror GitHub with AWS CodeCommit

```bash
# Configure AWS Credentials
./setup.sh -e ${EnvironmentName} -f

./setup.sh -e ${EnvironmentName} -a devops
# Wait for deploy to complete

# Configure SSH keys for Code Commit repos to be relicated with DXC Enterprise GitHub repos
./secrets.sh -e ${EnvironmentName} -a # check the script for detailed documentation on how to use this
```

* Add webhook in GitHub Organization to mirror the repos with AWS Code Commit Repos. To do this, use endpoint of the API _ProjectName_-global-_EnvironmentName_-devops-CodeCommitWebhook deployed.

#### 1.3.2. Deploy Global Components

```bash
./setup.sh -e ${EnvironmentName} -dst domains certificates notifications devops
# Wait for deploy to complete

./setup.sh -e ${EnvironmentName} -p domains
# Wait for deploy to complete

./setup.sh -e ${EnvironmentName} -p certificates notifications
# Wait for deploy to complete
```

## 2. Tenant

* To be run once for each tenant
* Tenant is either for a client or developer environment
* Standard environments are sandbox (sbx), development (dev), stage (stg), and production (prod).  E.g., soteria-dxc-sbx
* Developer environments are named as DXC shortid.  E.g., soteria-jdoe-sbx

### 2.1 Get Source Code

```bash
GitHubOrgName='soteria'
TenantName='jdoe'  # e.g., dxc / acme for client tenant.  jdoe for dev env
EnvironmentName='sbx'

mkdir $OrgName/${TenantName}
cd ${OrgName}/${TenantName}

git clone git@github.dxc.com:${GitHubOrgName}/devops     # for deploy scripts
cd devops
```

```bash
chmod +x ./setup.sh
```

### 2.2. Configure

a) Update Project Name and Tenant Name in [config/all.ini](config/all.ini)

b) Configure AWS Credentials

```bash
./setup.sh -e ${EnviornmentName} -f
```

c) Make sure you have _ProjectName_-_TenantName_-_EnvironmentName_.json file in each of the repo that you deploy.

### 2.2.1. Configure Domains & Certificates

#### 2.2.1.1 Subdomains

The domain names for each tenant default to use tenant name as subdomains of global tenant's domain name.

The API domain names for each tenant defaults to **api-**&lt;tenantName&gt;.&lt;Global's Domain Name&gt;

E.g. If global tenant's domain name is ckin.in, set following parameters in config file domains/config/soteria-acme-prd.json for client acme's tenant:

```json
{
    "Parameters": {
        "UserDomainName": "acme.ckin.in",
        "PublicDomainName": "acme.safetysuite.org"
    }
}
```

E.g., set following parameters in config file domains/config/soteria-jdoe-sbx.json for developer environments tenant:

```json
{
    "Parameters": {
        "UserDomainName": "jdoe.ckin.in",
        "PublicDomainName": "jdoe.safetysuite.io"
    }
}
```

jdoe is short ID of the develper.

#### 2.2.1.2. Hosted Domains

Customers have the choice to use hosted domain name such as acmesafetysuite.org or safetysuite.acme.com.

* Set **domains** component config file parameters **DomainHosting** to _hosted_ for hosted domains.

* Set **domains** component config file parameters **UserDomainName** and **PublicDomainName** in config file to provide hosted domain names.

Here is an illustrative snippet of a configuration file domains/config/soteria-acme-prd.json:

```json
{
    "Parameters": {
        "UserDomainName": "safetysuite.acme.com",
        "PublicDomainName": "acme.acmesafetysuite.org",
        "DomainHosting": "hosted"
    }
}
```

##### Configure API Domain

In case of hosted domains, additionally, you have to configure parameters **DomainHosting** and **ApiNamePrefix** in api repo's config file.

* Set **DomainHosting** to _hosted_.
* Set parameter ApiNamePrefix to, say, "api." or "api-.".  Make sure the domain name doesn't exceed more than one level of subdomain.

##### Configure Certificates

In case of hosted domains, you have to set parameter **DomainHosting** in certificates repo config file to _hosted_.

### 2.2.2. Watch your own branch to trigger build

This is an option for developer enviornments only

By default, the build watches a branch corresponding to the standard environment.  E.g., the build watches 'sandbox' branch for sandbox environment.

For those components you expect to contribute / develop, you can have the pipeline watch your own branch named ${TenantName}.  To do this, for those components you expect to contribute / develop, you'll have to:

1. Set **WatchTenantBranch** to _true_ in [config/all.ini](config/all.ini) before you build pipeline for that component.
2. Make sure you have _ProjectName_-_TenantName_-_EnvironmentName_.json file in each of the repo that you deploy.
3. Create a branch ${TenantName} in the repo for which you want the pipeline to watch.

Steps (2) and (3) can be automated with below command:

```bash
./setup.sh -e ${EnvironmentName} -o <space separated component list>
```

Above command clones the component repos locally, creates a local branch ${TenantName}, copies default config files from [skeleton/config](skeleton/config) folder to the newly created branch, and sync locally created branch with remote.

### 2.3. Deploy

```bash
./setup.sh -e ${EnvironmentName} -a domains
# Wait for deploy to complete

./setup.sh -e ${EnvironmentName} -a certificates
# Wait for deploy to complete

./setup.sh -e ${EnvironmentName}  -a api distribution identity
# Wait for deploy to complete

./setup.sh -e ${EnvironmentName} -a risk rules forms badges surveys
# Wait for deploy to complete
```

### 2.4. Post Deployment Steps

#### **Risk**

```bash
pushd ../risk
    # update ./utilities/secrets.sh with keys
    chmod +x ./utilities/secrets.sh
    ./utilities/secrets.sh
popd
```

#### **Badges**

Install Instructions to configure settings of environments watching respective branches ([sandbox](https://github.dxc.com/soteria/badges/blob/sandbox/docs/Install-Instructions.md), [master](https://github.dxc.com/soteria/badges/blob/master/docs/Install-Instructions.md), [production](https://github.dxc.com/soteria/badges/blob/production/docs/Install-Instructions.md))


#### **Surveys**

Install Instructions to configure  settings of environments watching respective branches  ([sandbox](https://github.dxc.com/soteria/surveys/blob/sandbox/docs/Install-Instructions.md), [master](https://github.dxc.com/soteria/surveys/blob/master/docs/Install-Instructions.md), [production](https://github.dxc.com/soteria/surveys/blob/production/docs/Install-Instructions.md))


TODO: to include instructions for other components deployment
