#ADO-API-AttachWorkitemidifnotexistToPullRequest Through API in Azure Devops
#$(pullRequestId) # This value we will get from Create Pull Request task
# Variables
$organization = "ProjectAdev"    # Replace with your Azure DevOps organization name
$project = "ProjectA .NET"              # Replace with your Azure DevOps project name
$repository = "ProjectA-core"        # Replace with your repository name
$prId = "$(pullRequestId)"                     # This we will get from the Task Create Pull Request
$workItemId = $(pr-mergeworkitemID)                          # Replace with your Work Item ID
$personalAccessToken = "oebwosvgor7ez5mcr4v2woxox"  # Replace with your Azure DevOps PAT. This PAT created using Mfsbuild ID and the PAT name : AutoApprovePullRequest.
$EmailList = $(pr-EmailList) #Multiple Emailid are comma separated Eg: 'MedojuB2@ProjectA.com','Sali@ProjectA.com'
$apiVersion = "?api-version=7.1-preview"
# Azure DevOps REST API URL to add a comment to a PR
$PullRequestapiurl = "https://ado.ProjectA.com:8080/tfs/$organization/$project/_apis/git/repositories/$repository/pullrequests/$prId$apiVersion"
$WorkitemapiUrl = "https://ado.ProjectA.com:8080/tfs/$organization/$project/_apis/git/repositories/$repository/pullrequests/$prId/workitems$apiVersion"

#Send Email Function
function SendEmail($Message, $body)
{
#$EmailList = 'MedojuB2@ProjectA.com'

$secpasswd = ConvertTo-SecureString "BPAElzLCY6yLeD2kb8pB8a+8238xx9VKHJzK+Zxkwdi" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("AKIA5L3RC3457YA5AB", $secpasswd)

#Send email
Import-Module Microsoft.PowerShell.Utility
Send-MailMessage -From 'tfs@ProjectA.com' -To $EmailList -Subject $Message -Body "Hi,

$body.

Thanks,
AzureDevOps" -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer 'email-smtp.us-east-1.amazonaws.com' -Port 587 -Credential $cred -UseSsl
}


#Creating BuildUrl We can use this to send in email
$Buildurl = '$(System.CollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)'

# Headers with the PAT for authentication
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$personalAccessToken"))
}


Write-Host PullRequestapiurl $PullRequestapiurl
Write-Host WorkitemApiUrl $WorkitemapiUrl




if ($prId)
{


    try {
    # Get the Numer of Workitems linked to Pull request
        $Workitemresponse = Invoke-RestMethod -Uri $WorkitemapiUrl -Headers $headers -Method Get
    
        if ($Workitemresponse.count -gt 0) 
         {
        #If  Workitems are linked then we are Not linking Workitem Just displaying how many number of workitems are linked.
        Write-Host "Number of Workitems linked to this PullRequest : $Workitemresponse.count "
        Write-Host "Work Items linked to Pull Request $prId :"
            foreach ($workItem in $Workitemresponse.value) 
             {
             Write-Host "  - $($workItem.id) $($workItem.url)"
             }
        Write-Host "*** No Need of linking our Workitemid: $workItemId ***"

        
        $message1 = "WorkItem Already Exist to PR: $prId "
        $body1 = "WorkItem Already Exist to PR: $prId 
        `nBuild Pipeline Name: $(Build.DefinitionName) 
        `nBuild Url: https://ado.ProjectA.com:8080/tfs/ProjectAdev/ProjectA%20.NET/_build/results?buildId=$(Build.BuildId)&view=results 
        `nPullRequest Url https://ado.ProjectA.com:8080/tfs/ProjectAdev/ProjectA%20.NET/_git/ProjectA-core/pullrequest/$prId"
        SendEmail $message1 $body1

         } 
    else {
    #If no Workitems are linked then we are linking Workitem
        Write-Host "Number of Workitems linked to this PullRequest : $Workitemresponse.count "
        Write-Host "No work items found linked to Pull Request $prId."
        Write-Host "Attaching Work Item ID: $workItemId $prId."

        
# Get the pull request details
$response = Invoke-RestMethod -Uri $PullRequestapiurl -Method Get -Headers $headers -ContentType "application/json-patch+json"

# Output response for debugging
#$response

$url= $response.artifactId
#Write-Host ArtifactID is $url
    

$requestUri = "https://ado.ProjectA.com:8080/tfs/$organization/_apis/wit/workitems/${workitemid}?api-version=7.1-preview.3"

$json = @"
[ {
  "op": "add",
  "path": "/relations/-",
  "value": {
    "rel": "ArtifactLink",
    "url": "$url",
    "attributes": { "name": "pull request" }
  }
} ]
"@


$response1 = Invoke-RestMethod -Uri $requestUri -Headers $headers -ContentType "application/json-patch+json" -Method Patch -Body $json
Write-Host "*** Work Item ID: $workItemId is ATTACHED to the PR: $prId ***"

$message2 = "WorkItem $workItemId ATTACHED to PR: $prId"
$body2 = "WorkItem $workItemId ATTACHED to PR: $prId 
        `nBuild Pipeline Name: $(Build.DefinitionName) 
        `nBuild Url: https://ado.ProjectA.com:8080/tfs/ProjectAdev/ProjectA%20.NET/_build/results?buildId=$(Build.BuildId)&view=results 
        `nPullRequest Url https://ado.ProjectA.com:8080/tfs/ProjectAdev/ProjectA%20.NET/_git/ProjectA-core/pullrequest/$prId"
SendEmail $message2 $body2

         }
        } #End Try Block
        catch {
          Write-Error "Catch block is executing : $($_.Exception.Message)"
              }
}

else
{
Write-Host "Pull RequestID $prId is not created so skipping Workitem Assignment"


}
