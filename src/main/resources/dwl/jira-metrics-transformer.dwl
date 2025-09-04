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
        "summary": {
            "totalProjects": sizeOf(vars.projects),
            "totalBoards": sizeOf(vars.boards),
            "totalActiveBoards": sizeOf(vars.boards filter ($.'type' == "scrum" or $.'type' == "kanban")),
            "totalSprints": sizeOf(vars.allSprints),
            "totalActiveSprints": sizeOf(vars.allSprints filter ($.state == "active")),
            "totalIssues": sum(vars.boardIssues map sizeOf($.issues)),
            "timestamp": currentTime
        },
        "performanceMetrics": {
            "averageCycleTime": {
                "overall": safeAvg(flatten(vars.boardIssues map ($.issues map calculateCycleTime($))) filter ($ != null)),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "averageDays": safeAvg($.issues map calculateCycleTime($) filter ($ != null))
                }
            },
            "averageLeadTime": {
                "overall": safeAvg(flatten(vars.boardIssues map ($.issues map calculateLeadTime($))) filter ($ != null)),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "averageDays": safeAvg($.issues map calculateLeadTime($) filter ($ != null))
                }
            },
            "issuesResolvedLast7Days": {
                "count": sizeOf(flatten(vars.boardIssues map ($.issues filter isResolvedInLastDays($, |P7D|)))),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "count": sizeOf($.issues filter isResolvedInLastDays($, |P7D|))
                }
            },
            "issuesResolvedLast30Days": {
                "count": sizeOf(flatten(vars.boardIssues map ($.issues filter isResolvedInLastDays($, |P30D|)))),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "count": sizeOf($.issues filter isResolvedInLastDays($, |P30D|))
                }
            },
            "issuesCreatedLast7Days": {
                "count": sizeOf(flatten(vars.boardIssues map ($.issues filter isCreatedInLastDays($, |P7D|)))),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "count": sizeOf($.issues filter isCreatedInLastDays($, |P7D|))
                }
            },
            "issuesCreatedLast30Days": {
                "count": sizeOf(flatten(vars.boardIssues map ($.issues filter isCreatedInLastDays($, |P30D|)))),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "count": sizeOf($.issues filter isCreatedInLastDays($, |P30D|))
                }
            },
            "reopenedIssues": {
                "count": sizeOf(flatten(vars.boardIssues map ($.issues filter isReopened($)))),
                "percentage": do {
                    var totalIssues = sum(vars.boardIssues map sizeOf($.issues))
                    var reopenedCount = sizeOf(flatten(vars.boardIssues map ($.issues filter isReopened($))))
                    ---
                    if (totalIssues > 0) (reopenedCount / totalIssues) * 100 else 0
                },
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "count": sizeOf($.issues filter isReopened($)),
                    "percentage": do {
                        var boardIssueCount = sizeOf($.issues)
                        var boardReopenedCount = sizeOf($.issues filter isReopened($))
                        ---
                        if (boardIssueCount > 0) (boardReopenedCount / boardIssueCount) * 100 else 0
                    }
                }
            },
            "workInProgress": {
                "count": sizeOf(flatten(vars.boardIssues map ($.issues filter ($.fields.status != null and $.fields.status.name == "In Progress")))),
                "byBoard": vars.boardIssues map {
                    "boardId": $.boardId,
                    "count": sizeOf($.issues filter ($.fields.status != null and $.fields.status.name == "In Progress"))
                }
            }
        },
        "projectDetails": vars.projects map {
            "projectId": $.id,
            "projectKey": $.key,
            "projectName": $.name,
            "projectType": $.projectTypeKey,
            "lead": $.lead.displayName default "N/A",
            "description": $.description default "No description"
        },
        "boardDetails": vars.boards map {
            "boardId": $.id,
            "boardName": $.name,
            "boardType": $.'type',
            "projectKey": $.location.projectKey default "N/A",
            "projectName": $.location.projectName default "N/A"
        },
        "sprintDetails": vars.allSprints map {
            "sprintId": $.id,
            "sprintName": $.name,
            "state": $.state,
            "startDate": safeDateParse($.startDate),
            "endDate": safeDateParse($.endDate),
            "completeDate": safeDateParse($.completeDate),
            "boardId": $.originBoardId
        },
        "issueMetrics": vars.boardIssues map {
            "boardId": $.boardId,
            "totalIssues": sizeOf($.issues),
            "issues": extractIssueDetails($.issues),
            "issuesByStatus": ($.issues filter ($.fields.status != null and $.fields.status.name != null) groupBy $.fields.status.name) mapObject {
                ($$): sizeOf($)
            },
            "issuesByType": ($.issues filter ($.fields.issuetype != null and $.fields.issuetype.name != null) groupBy $.fields.issuetype.name) mapObject {
                ($$): sizeOf($)
            },
            "issuesByPriority": ($.issues filter ($.fields.priority != null and $.fields.priority.name != null) groupBy $.fields.priority.name) mapObject {
                ($$): sizeOf($)
            }
        }
    }
}