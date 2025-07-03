param(
    $PackageId = (Split-Path $PSScriptRoot -Leaf),

    $DownloadPage = "https://ui.com/download/app/wifiman-desktop"
)

# $Result = Invoke-WebRequest $DownloadPage -UseBasicParsing
# $URL64 = $Result.Links.Where{$_.href.EndsWith("amd64.exe")}

$RequestArgs = @{
    UseBasicParsing = $true
    Uri = "https://community.svc.ui.com/"
    Method = "POST"
    Headers = @{
        "Referer" = "https://community.ui.com"
        "Origin" = "https://community.ui.com"
    }
    ContentType = "application/json"
    Body = @{
        "operationName" = "GetReleases"
        "variables" = @{
            "limit" = 30
            "offset" = 0
            "statuses" = @("PUBLISHED")
            "tags" = @("wifiman")
            "sortBy" = "LATEST"
        }
        "query" = 'query GetReleases(
            $limit = Int,
            $offset =  Int,
            $searchTerm = String,
            $sortBy =  ReleasesSortBy,
            $sortDirection =  ReleasesSortDirection,
            $stage =  ReleaseStage,
            $statuses =  [ReleaseStatus!],
            $tagMatchType =  TagMatchType,
            $tags =  [String!],
            $type =  ReleaseType,
        ) {
            releases(
                limit =  $limit,
                offset =  $offset,
                searchTerm =  $searchTerm,
                sortBy =  $sortBy,
                sortDirection =  $sortDirection,
                stage =  $stage,
                statuses =  $statuses,
                tagMatchType =  $tagMatchType,
                tags =  $tags,
                betas =  $betas,
                alphas =  $alphas,
                filterTags =  $filterTags,
                filterEATags =  $filterEATags,
                filterAlphaTags =  $filterAlphaTags,
                type =  $type,
                featuredOnly =  $featuredOnly,
                nonFeaturedOnly =  $nonFeaturedOnly,
                userIsFollowing =  $userIsFollowing
            ) {
                items {
                    ...BasicRelease
                    __typename
                }
                pageInfo {
                    limit
                    offset
                    __typename
                }
                totalCount
                __typename
            }
        }
        fragment BasicRelease on Release {
            id
            slug
            type
            title
            version
            stage
            tags
            betas
            alphas
            isFeatured
            isLocked
            hasUiEngagement
            stats {
            comments
            views
            __typename
            }
            createdAt
            lastActivityAt
            updatedAt
            userStatus {
            ...UserStatus
            __typename
            }
            author {
            ...UserWithStats
            __typename
            }
            publishedAs {
            ...User
            __typename
            }
            __typename
        }
    
        fragment UserStatus on UserStatus {
            isFollowing
            lastViewedAt
            reported
            vote
            __typename
        }
    
        fragment UserWithStats on User {
            ...User
            stats {
            questions
            answers
            solutions
            comments
            stories
            score
            __typename
            }
            __typename
        }
    
        fragment User on User {
            id
            username
            title
            slug
            avatar {
            color
            content
            image
            __typename
            }
            isEmployee
            registeredAt
            lastOnlineAt
            groups
            showOfficialBadge
            canBeMentioned
            canViewProfile
            canStartConversationWith
            __typename
        }
    }'
    } | ConvertTo-Json
}
$Result = Invoke-WebRequest @RequestArgs

$Headers @{
    "Accept" = "*/*"
    "Accept-Language" = "en-GB,en;q=0.5"
    "Accept-Encoding" = "gzip, deflate, br, zstd"
    "Referer" = "https://community.ui.com/"
    "x-frontend-version" = "2025-03-25T12:45:39Z"
    "Origin" = "https://community.ui.com"
    "DNT" = "1"
    "Sec-GPC" = "1"
    "Sec-Fetch-Dest" = "empty"
    "Sec-Fetch-Mode" = "cors"
    "Sec-Fetch-Site" = "same-site"
    "Priority" = "u=0"
}

$LatestVersion = if ($URL64 -and $URL64 -match "wifiman-desktop-(?<Version>[\d\.]+)-amd64\.exe$") {
    $Matches.Version
} else {
    Write-Error "Could not find version from url '$($URL64)' on '$($DownloadPage)'" -ErrorAction Stop
}

# Update the install script
$InstallPs1 = Get-Content $PSScriptRoot\tools\chocolateyInstall.ps1
$Replacements = @{
    "Url64bit" = $URL64
}

$ProgressPreference = "SilentlyContinue"

$Replacements.Checksum64 = (Get-FileHash -Algorithm SHA256 -InputStream (
        [System.IO.MemoryStream]::New(
        (Invoke-WebRequest $Replacements.Url64bit).Content
        )
    )).Hash

$Replacements.GetEnumerator().ForEach{
    if ($InstallPs1 -match "^(\s*[$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']") {
        $InstallPs1 = $InstallPs1 -replace "(\s*[$`"']?$($_.Key)[`"']?\s*=\s*)[`"'].*[`"']", "$1'$($_.Value)'"
    } else {
        Write-Error -Message "$PackageId`: Could not find replacement for '$($_.Key)' in chocolateyInstall.ps1" -ErrorAction Stop
    }
}
$InstallPs1 | Set-Content $PSScriptRoot\tools\chocolateyInstall.ps1

# Package the updated files
choco pack "$($PSScriptRoot)\$($PackageId).nuspec" --version $LatestVersion