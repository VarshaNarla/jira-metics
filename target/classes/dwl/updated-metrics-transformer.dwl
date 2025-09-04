%dw 2.0
import * from dw::core::Dates
import * from dw::util::Coercions
output application/json

var currentTime = now()
var sevenDaysAgo = currentTime - |P7D|
var thirtyDaysAgo = currentTime - |P30D|

// Safe date parsing function to handle JIRA date strings with various timezone formats
fun safeDateParse(dateStr) = 
    if (dateStr != null and dateStr != "") 
        toDateTimeOrNull(dateStr, [
            {format: "uuuu-MM-dd'T'HH:mm:ss.SSSZ"},      // 2025-08-10T13:59:26.433+0530
            {format: "uuuu-MM-dd'T'HH:mm:ssZ"},          // 2025-08-10T13:59:26+0530
            {format: "uuuu-MM-dd'T'HH:mm:ss.SSS'Z'"},    // 2025-08-10T13:59:26.433Z
            {format: "uuuu-MM-dd'T'HH:mm:ss'Z'"},        // 2025-08-10T13:59:26Z
            {format: "uuuu-MM-dd'T'HH:mm:ss.SSSX"},      // 2025-08-10T13:59:26.433+05:30
            {format: "uuuu-MM-dd'T'HH:mm:ssX"}           // 2025-08-10T13:59:26+05:30
        ])
    else 
        null

fun calculateCycleTime(issue) = 
    do {
        var resolutionDate = safeDateParse(issue.fields.resolutiondate)
        var statusChangeDate = safeDateParse(issue.fields.statuscategorychangedate)
        ---
        if (resolutionDate != null and statusChangeDate != null) 
            (resolutionDate - statusChangeDate) as Number { unit: "days" }
        else
            null
    }

fun calculateLeadTime(issue) = 
    do {
        var resolutionDate = safeDateParse(issue.fields.resolutiondate)
        var createdDate = safeDateParse(issue.fields.created)
        ---
        if (resolutionDate != null and createdDate != null) 
            (resolutionDate - createdDate) as Number { unit: "days" }
        else
            null
    }

fun isResolvedInLastDays(issue, days) = 
    do {
        var resolutionDate = safeDateParse(issue.fields.resolutiondate)
        ---
        resolutionDate != null and resolutionDate > (currentTime - days)
    }

fun isCreatedInLastDays(issue, days) = 
    do {
        var createdDate = safeDateParse(issue.fields.created)
        ---
        createdDate != null and createdDate > (currentTime - days)
    }

fun isReopened(issue) = 
    issue.fields.resolution != null and 
    issue.fields.resolution.name != null and
    issue.fields.resolution.name == "Done" and 
    issue.fields.status != null and
    issue.fields.status.name != null and
    issue.fields.status.name != "Done"

fun safeAvg(values) = 
    if (isEmpty(values)) 0 else avg(values)

// Function to extract issue details for the updated format
fun extractIssueDetails(issues) = 
    issues map {
        "id": $.id,
        "key": $.key,
        "issuetype": $.fields.issuetype.name default "task/subtask",
        "created": safeDateParse($.fields.created),
        "priority": $.fields.priority.name default "Medium",
        "status": $.fields.status.name default "To Do"
    }

---
{
    "jiraMetrics": {
        "projectDetails": vars.projects map {
            "projectId": $.id,
            "projectKey": $.key,
            "projectName": $.name,
            "projectType": $.projectTypeKey,
            "lead": $.lead.displayName default "N/A",
            "description": $.description default ""
        },
        "boardDetails": vars.boards map {
            "boardId": $.id,
            "boardName": $.name,
            "boardType": $.'type',
            "projectKey": $.location.projectKey default "N/A",
            "projectName": $.location.projectName default "N/A",
            "performanceMetrics": do {
                var currentBoardId = $.id
                var boardIssues = (vars.boardIssues filter ($.boardId == currentBoardId))[0].issues default []
                var cycleTimeValues = boardIssues map calculateCycleTime($) filter ($ != null)
                var leadTimeValues = boardIssues map calculateLeadTime($) filter ($ != null)
                ---
                {
                    "CycleTime": safeAvg(cycleTimeValues),
                    "averageLeadTime": safeAvg(leadTimeValues),
                    "issuesResolvedLast7Days": sizeOf(boardIssues filter isResolvedInLastDays($, |P7D|)),
                    "issuesResolvedLast30Days": sizeOf(boardIssues filter isResolvedInLastDays($, |P30D|)),
                    "issuesCreatedLast7Days": sizeOf(boardIssues filter isCreatedInLastDays($, |P7D|)),
                    "issuesCreatedLast30Days": sizeOf(boardIssues filter isCreatedInLastDays($, |P30D|)),
                    "reopenedIssues": sizeOf(boardIssues filter isReopened($)),
                    "workInProgress": sizeOf(boardIssues filter ($.fields.status != null and $.fields.status.name == "In Progress"))
                }
            },
            "issueMetrics": do {
                var currentBoardId = $.id
                var boardIssues = (vars.boardIssues filter ($.boardId == currentBoardId))[0].issues default []
                ---
                {
                    "totalIssues": sizeOf(boardIssues),
                    "issues": extractIssueDetails(boardIssues),
                    "issuesByStatus": (boardIssues filter ($.fields.status != null and $.fields.status.name != null) groupBy $.fields.status.name) mapObject {
                        ($$): sizeOf($)
                    },
                    "issuesByType": (boardIssues filter ($.fields.issuetype != null and $.fields.issuetype.name != null) groupBy $.fields.issuetype.name) mapObject {
                        ($$): sizeOf($)
                    },
                    "issuesByPriority": (boardIssues filter ($.fields.priority != null and $.fields.priority.name != null) groupBy $.fields.priority.name) mapObject {
                        ($$): sizeOf($)
                    }
                }
            },
            "sprintDetails": do {
                var currentBoardId = $.id
                ---
                 (vars.allSprints filter ($.originBoardId == currentBoardId) distinctBy $.id) map {
                    "sprintId": $.id,
                    "sprintName": $.name,
                    "state": $.state,
                    "startDate": safeDateParse($.startDate),
                    "endDate": safeDateParse($.endDate),
                    "completeDate": safeDateParse($.completeDate),
                    "boardId": $.originBoardId
                }
            }
        }
    }
}