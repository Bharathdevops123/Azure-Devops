   #This script attaches workitem to the PR if not attached.
   # Checks for merge conflicts. If there are merge conflicts, it will send an email to the email list. 
   # If there are no merge conflicts, then it will approve the pull request.
   # Sends email as the PR is approved with number of files changed in the PR, with build URL and PR URL.
   # Waits till all the build validations are complete. It will wait up to 2 hours.
   # Then completes the PR and sends email to us with number of files changed after the PR, with build URL and PR URL.
   # Pass parameters like this from arguments section -organization "$(organization)"
   param (
    [string]$organization, # Replace ADO organization name 
    [string]$project,     # Replace Azure DevOps project name
    [string]$repository,   # Replace repository name
    [string]$workItemId,    # Replace  Work Item ID
    [string]$personalAccessToken,   # Replace with your Azure DevOps PAT. This PAT created using tfsbuild ID and the PAT name AutoApprovePullRequest.
    [string]$EmailList,   #Multiple Emailid are comma separated Eg 'MedojuB2@mswift.com','Sali@mswift.com' testing locally we can give this way
                          #When you are giving multiple emails from ADO variables then you can give like this MedojuB2@mswift.com,Sali@mswift.com no need of double quotes if it still not works then give double quotes.
	[string]$SourceBranch,
    [string]$TargetBranch,
    [string]$EmailSubjectFirstPart,
    [string]$prId
    )
   # Variables
   #$(pullRequestId) # This value we will get from Create Pull Request task
   $apiVersion = "?api-version=7.1-preview"
   # Azure DevOps REST API URL of a  PR
   $PullRequestapiurl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests/$prId$apiVersion"
   $WorkitemapiUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests/$prId/workitems$apiVersion"
   $tfsbuildReviewerId = "27130f33-fa25-4231-a9c5-15d04ab4463a" # this is the tfsbuild id which we collected it from one of the PR url. We use this for approving PR.
   
   # We just need to change above variables thats it. if we are using this as a template then you can pass the above variables thats it.
   
   #Send Email Function
   function SendEmail($Message, $body)
   {
   #$EmailList = 'MedojuB2@mswift.com'
   
   
   $secpasswd = ConvertTo-SecureString "BPAElzLCY6yLeD2kb8pB8a+05mp8xx9VKHJzK+Zxkwdi" -AsPlainText -Force
   $cred = New-Object System.Management.Automation.PSCredential ("AKIA5L3RCFSMYF7YA5AB", $secpasswd)
   
    $arr1 = $EmailList -split ','
    foreach($Email in $arr1)
    {
   #Send email
   Import-Module Microsoft.PowerShell.Utility
   Send-MailMessage -From 'tfs@mswift.com' -To $Email -Subject $Message -Body "Hi,
   
   $body.
   
   Thanks,
   AzureDevOps" -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer 'email-smtp.us-east-1.amazonaws.com' -Port 587 -Credential $cred -UseSsl
     }
   }
   
   $artifactPath = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
   $sourcesDir = $env:BUILD_SOURCESDIRECTORY
   $buildId = $env:BUILD_BUILDID
   $definitionName = $env:BUILD_DEFINITIONNAME

   #How many files changed we are sending it in the email
   function gitchanges
   {
                   # Send email How many files changed in the completed PR commit.
                   # Get the most recent merge commit (common for completed PRs)
                   #Getting the latest code to Artifact staging directory and check the latest commit has the same number of files or not
                    Write-Host "Artifact Staging Directory : $artifactPath"
                    Write-Host "Build Sources Directory    : $sourcesDir"
                    Write-Host "Build ID                  : $buildId"
                    Write-Host "Build Definition Name     : $definitionName"

                    Start-Sleep -Seconds 60 #Waiting for the PR to complete
                    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$personalAccessToken"))
                    if (-not [string]::IsNullOrWhiteSpace($artifactPath)) {
                    D:
                    Write-Host "Artifact staging directory: $artifactPath"
                    cd $artifactPath
                    git -c http.extraHeader="Authorization: Basic $base64AuthInfo" clone "https://dev.azure.com/$organization/$project/_git/$repository" $artifactPath
                    Write-Host We are on branch
                    git branch
                    Write-Host Switching to $TargetBranch
                    git checkout $TargetBranch
                    Write-Host ***We are on branch***
                    git branch
                    git pull $TargetBranch
                    #We are getting Last commit instead of merge commit is because the merge commit will be having parent commits 
                    #and in sql optimization project we are getting old one and in the latest commit as we are using squash commit there is no parent for this new commit so new merge commit is not available                    
                    $LastCommit = git log -n 1 --pretty=format:"%H" # This line will get  full commit id
                    Write-Output merge commit is: $LastCommit
                    # Get number of files changed in that merge commit                    
                    $statLine1 = git show --stat --oneline $LastCommit | Select-String -Pattern "file[s]? changed"
                    echo $statLine1
                    if ($statLine1) {
                        $numFilesChanged = ($statLine1 -split " ")[1]
                        #Write-Output $numFilesChanged
                        Write-host "no of files changed: $numFilesChanged"

                        }

                    $statLine2 = git show --stat --oneline $LastCommit | Select-String -Pattern "Merged?"

                    if ($statLine2) {
    
                        #Write-Output $statLine2
                       Write-host "Changeset Details: $statLine2"

                       }


                   Write-Host "Pull Request #$prId has been Completed!."
                       #Send Email
                              $message10 = "$EmailSubjectFirstPart-Completed : PR : $prId-Completed"
                              $body10 = "$EmailSubjectFirstPart merge from: $SourceBranch to $TargetBranch
                                  `nThe pull request $prId is Completed!.
                                  `nNumber of files changed in the Completed PR commit: $numFilesChanged
                                  `nChangeset Details: $statLine2
                                  `nBuild Pipeline Name: $definitionName 
                                  `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results 
                                  `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
                              SendEmail $message10 $body10
                    } else {
                    Write-Error "BUILD_ARTIFACTSTAGINGDIRECTORY is null or empty!"
                    }

   }#end gitstatuschange function
      
   # Headers with the PAT for authentication
   $headers = @{
       "Content-Type" = "application/json"
       "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$personalAccessToken"))
   }
   
   
   Write-Host PullRequestapiurl $PullRequestapiurl
   Write-Host WorkitemApiUrl $WorkitemapiUrl
   
   
   #Below script Assigns WorkItem to the PR if does not exist
   
   if ($prId)
   {
   
   #***Checks for Workitems to the PR if there are no attached Workitems to the PR then it will assign workitem to it.
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
   
           
           $message1 = "$EmailSubjectFirstPart-WorkItem Already Exist to PR: $prId "
           $body1 = "merge from: $SourceBranch to $TargetBranch
           `nWorkItem Already Exist to PR: $prId             
           `nBuild Pipeline Name: $definitionName 
           `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results 
           `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
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
       
   
   $requestUri = "https://dev.azure.com/$organization/_apis/wit/workitems/${workitemid}$apiVersion"
   
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
   
   $message2 = "$EmailSubjectFirstPart-WorkItem $workItemId ATTACHED to PR: $prId"
   $body2 = "merge from: $SourceBranch to $TargetBranch 
           `nWorkItem $workItemId ATTACHED to PR: $prId           
           `nBuild Pipeline Name: $definitionName 
           `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results 
           `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
   SendEmail $message2 $body2
   
            }
           } #End Try Block
           catch {
             Write-Error "Catch block is executing : $($_.Exception.Message)"
                 }
      
   
   #***Powershell code to check status of the pull request, merge conflicts and sends email if there are any conflicts
   #If there are no conflicts it approves the PR and waits for 2 hours PR to complete its validation checks like PR Builds etc..
   #We are waiting because if PR is complete then only the code will be merged to the target branch.
   #till it is merged we will wait here because next pipeline or the stage will be merging from next branch to other branch.
     
   
   
   try {
       # Invoke the REST API
      # Make the GET request to get PR details
   #sleep for some seconds because response3 is not getting as the merge is completing faster
   $response3 = Invoke-RestMethod -Uri $PullRequestapiurl -Method Get -Headers $headers -ContentType "application/json"
   Write-Host "response3 echo is below"
   echo $response3
   
       # Check if the request was successful
       if ($response3) {
           Write-Host "Pull Request Status:" $response3.status
           Write-Host "Pull Request Title:" $response3.title
           Write-Host "Pull Request MergeStatus:"$response3.mergeStatus
           #Write-Host "Pull Request URL:" $response3.url
   
           # Additional details
           Write-Host "Created By:" $response3.createdBy.displayName
           Write-Host "Creation Date:" $response3.creationDate
           if (($response3.status -eq "active") -and ($response3.mergeStatus -eq "queued"))
           {
           $queuecounter = 0
                while ((($response3.status -eq "active") -and ($response3.mergeStatus -eq "queued")) -and ($queuecounter -le 3)) 
                   {
                $response3 = Invoke-RestMethod -Uri $PullRequestapiurl -Method Get -Headers $headers -ContentType "application/json"
                   #Check for PR merge status to move from queued state to other states (Completed or Succeeded or conflicts).
                   Write-Host "Waiting for PR merge status to move from queued state to other state."
                   Start-Sleep -Seconds 120
   
                   Write-Host "Waiting for 2 minutes....."
   
                   Write-Host "queueCounter: $queuecounter"
                   $queuecounter++
                   }
                   if($queuecounter -eq 4 )
                   {
                   Write-Host "Waited for 6 minutes PR is not moved from queued state to other state. Please check is there any issue in the PR $prid."
   
                   $message9 = "Waited for 6 minutes PR is not moved from queued state to other state.$prid."
                   $body9 = "merge from: $SourceBranch to $TargetBranch 
                   `nWaited for 6 minutes PR is not moved from queued state to other state. Please check is there any issue in the PR $prid.         
                   `nBuild Pipeline Name: $definitionName 
                   `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results
                   `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
                   SendEmail $message9 $body9
                   }
            }

           elseif (($response3.status -eq "active") -and ($response3.mergeStatus -eq "Conflicts"))
           {
   
            Write-Host "PR is in Active state and there are merge Conflicts We can trigger next pipeline and email will be sent to the team regarding merge conflicts."
            Write-Host "The pull request $prId has merge conflicts and cannot be approved."

            # Define the REST API URL to check no of iterations(No of files changed in the PR). 
            #eg :https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests/17667/iterations/1/changes?api-version=7.1
            #Iteration one is the head of the source branch at the time the pull request is created and subsequent iterations are created when there are pushes to the source branch.
            #Allowed values are between 1 and the maximum iteration on this pull request.
            $Fileschangeduri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests/$prId/iterations/1/changes$apiVersion"
            write-host "Fileschangeduri: $Fileschangeduri"

            # Make the GET request to get PR details
            $FileschangedUriResponse = Invoke-RestMethod -Uri $Fileschangeduri -Method Get -Headers $headers -ContentType "application/json"
            write-host "Files Changed Count: $FileschangedUriResponse.changeEntries.Count"

            $FileschangedinPR=$FileschangedUriResponse.changeEntries.Count

                                   
           $message3 = "$EmailSubjectFirstPart-NOT Approved: PR: $prId has merge conflicts"
           $body3 = "merge from: $SourceBranch to $TargetBranch           
                                   `nThe pull request $prId has merge conflicts and cannot be approved. Please Resolve MERGE Conflicts and COMMENTS.
                                   `nNumber of files changed in the PR: $FileschangedinPR
                                   `nBuild Pipeline Name: $definitionName 
                                   `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results 
                                   `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
           SendEmail $message3 $body3   
   
           }
           elseif (($response3.status -eq "active") -and ($response3.mergeStatus -eq "succeeded"))
           {
           Write-Host "The pull request $prId has NO merge conflicts and can be approved."                   
           
           # ***Approve the PR if there are no merge conflicts and merge status is Succeeeded***
           
                       #$approvalUri = "https://dev.azure.com/$organization/mswift .NET/_apis/git/repositories/$repository/pullrequests/$prId/reviewers/{reviewerId}?api-version=7.2-preview.1"
                       $approvalUri = "https://dev.azure.com/$organization/mswift .NET/_apis/git/repositories/$repository/pullrequests/$prId/reviewers/$tfsbuildReviewerId$apiVersion"
                       echo $approvalUri
                       # Create the approval request body (can include reviewer identity or other details)
                       $approvalBody = @{
             #                      reviewer = @{
                      #                                 id = $tfsbuildReviewerId  # Replace with the Azure DevOps user ID of the reviewer
                        #           }
                                   vote = 10 # 10 means approve
                       } | ConvertTo-Json -Depth 3
           
                       # Make the POST request to approve the PR
                       $approvalResponse = Invoke-RestMethod -Uri $approvalUri -Method PUT -Headers $headers -Body $approvalBody -ContentType "application/json"
                       
                       # Define the REST API URL to check no of iterations(No of files changed in the PR). 
                       #eg :https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests/17667/iterations/1/changes?api-version=7.1
                       #Iteration one is the head of the source branch at the time the pull request is created and subsequent iterations are created when there are pushes to the source branch.
                       #Allowed values are between 1 and the maximum iteration on this pull request.
                       $Fileschangeduri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests/$prId/iterations/1/changes$apiVersion"
                       write-host "Fileschangeduri: $Fileschangeduri"

                       # Make the GET request to get PR details
                       $FileschangedUriResponse = Invoke-RestMethod -Uri $Fileschangeduri -Method Get -Headers $headers -ContentType "application/json"
                       write-host "Files Changed Count: $FileschangedUriResponse.changeEntries.Count"

                       $FileschangedinPR=$FileschangedUriResponse.changeEntries.Count



                       Write-Host "Pull Request #$prId has been approved."
                       #Send Email
           $message4 = "$EmailSubjectFirstPart-Approved : PR : $prId-NO merge conflicts"
           $body4 = "merge from: $SourceBranch to $TargetBranch
                                   `nThe pull request $prId has NO merge conflicts and is approved by tfsbuild.
                                    `nNumber of files changed in the PR: $FileschangedinPR
                                   `nBuild Pipeline Name: $definitionName 
                                   `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results 
                                   `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
           SendEmail $message4 $body4
           
           #Waiting for the PR to complete all its validation checks like PR builds, and other checks

           $counter = 0
                while ((($response3.status -eq "active") -and ($response3.mergeStatus -eq "succeeded")) -and ($counter -le 40)) 
                   {
                $response3 = Invoke-RestMethod -Uri $PullRequestapiurl -Method Get -Headers $headers -ContentType "application/json"
                   #Check for PR complete or it waits till 1 hour and then skips.
                   Write-Host "Waiting for PR to complete."
                   Start-Sleep -Seconds 180
   
                   Write-Host "Waiting for 3 minutes....."
   
                   Write-Host "Counter: $counter"
                   $counter++
                   }
                   if($counter -eq 41)
                   {
                   Write-Host "Waited for 2 hours PR is not completed Yet. Please check is there any issue in the PR $prid."
   
                   $message6 = "Waited for 2 hours PR is not completed Yet.$prid."
                   $body6 = "merge from: $SourceBranch to $TargetBranch 
                   `nWaited for 2 hours PR is not completed Yet. Please check is there any issue in the PR $prid.         
                   `nBuild Pipeline Name: $definitionName 
                   `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results
                   `nPullRequest Url https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$prId"
                   SendEmail $message6 $body6
                   }
                   elseif (($response3.status -eq "Abandoned") -or ($response3.mergeStatus -eq "Draft"))
                  {
                    #If some one rejects or Abondoned PR then we will get email from here
                     Write-Host "We received below status for PR"
                     Write-Host "Pull Request Status:" $response3.status
                     Write-Host "Pull Request Title:" $response3.title
                     Write-Host "Pull Request MergeStatus:"$response3.mergeStatus

                     [string] $status = $response3.status
                     [string] $title = $response3.title
                     [string] $mergeStatus = $response3.mergeStatus
           
                   $message8 = "$EmailSubjectFirstPart-different status for the PR $prid."
                   $body8 = "merge from: $SourceBranch to $TargetBranch 
                           `nWe have received different status for the PR $prid   
                           `nPull Request Status: $status
                           `nPull Request Title: $title
                           `nPull Request MergeStatus: $mergeStatus    
                   `nBuild Pipeline Name: $definitionName 
                   `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results"
                   SendEmail $message8 $body8
                  }
                   else{
                   Write-Host "PR is completed!"
                   # Send email How many files changed in the completed PR commit.
                   # Get the most recent merge commit (common for completed PRs)
                   #Getting the latest code to Artifact staging directory and check the latest commit has the same number of files or not
                   #Calling gitchanges function
                   gitchanges
                  }
   
            }
           elseif (($response3.status -eq "completed") -and ($response3.mergeStatus -eq "succeeded"))
           {
              Write-Host "PR is completed We can trigger next pipeline or Stage "
              #If there is no Approval validation then in that case the PR will be completed without approving.
              #Calling gitchanges function
              gitchanges
           }
           else
           {
           Write-Host "We have received below status for PR"
           Write-Host "Pull Request Status:" $response3.status
           Write-Host "Pull Request Title:" $response3.title
           Write-Host "Pull Request MergeStatus:"$response3.mergeStatus
           
                [string] $status = $response3.status
                [string] $title = $response3.title
                [string] $mergeStatus = $response3.mergeStatus
        
                $message7 = "$EmailSubjectFirstPart-different status for the PR $prid."
                $body7 = "merge from: $SourceBranch to $TargetBranch   
                        `nWe have received different status for the PR $prid 
                        `nPull Request Status: $status
                        `nPull Request Title: $title
                        `nPull Request MergeStatus: $mergeStatus     
                `nBuild Pipeline Name: $definitionName 
                `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=Build&view=results"
                SendEmail $message7 $body7
           
           }
   
       }
   }
   catch {
       Write-Error "Failed to retrieve pull request status: $($_.Exception.Message)"
   }
   
   
   }
   
   else
   {
   Write-Host "Pull RequestID $prId is not created so skipping Workitem Assignment"
   
   
   Write-Host "Pull RequestID  $prId is not created "
   $message5 = "$EmailSubjectFirstPart-No changes to Merge - $SourceBranch to $TargetBranch"
   $body5 = "$EmailSubjectFirstPart-No Changes to merge from $SourceBranch to $TargetBranch 
           `nPR: $prId is NOT created.         
           `nBuild Pipeline Name: $definitionName 
           `nBuild Url: https://dev.azure.com/$organization/$project/_build/results?buildId=$buildId&view=results"
   SendEmail $message5 $body5
   
   
   }
